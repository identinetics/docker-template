#!/usr/bin/env bash

main() {
    _get_commandline_opts $@
    _load_library_functions
    load_config '--build'
    _cd_to_Dockerfile_dir
    _prepare_docker_build_env
    init_sudo
    _remove_previous_image
    _prepare_build_command
    _exec_build_command
    _list_repo_branches
    _do_cleanup
}


_get_commandline_opts() {
    while getopts ":chn:pPrt:u" opt; do
      case $opt in
        c) CACHEOPT="--no-cache";;
        n) config_nr=$OPTARG
           re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
              echo "error: -n argument is not a number in the range frmom 02 .. 99" >&2; exit 1
           fi
           config_opt="-n ${config_nr}";;
        p) print="True";;
        P) push="True";;
        r) remove_img="True";;
        t) image_tag=":$OPTARG";;
        u) update_pkg="-u";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) echo "usage: $0 [-h] [-i] [-n <NN>] [-p] [-P] [-r] [cmd]
             -c  do not use cache (build --no-cache)
             -h  print this help text
             -n  configuration number ('<NN>' in conf<NN>.sh)
             -p  print docker build command on stdout
             -P  push after build
             -r  remove existing image (-f)
             -t  tag image name
             -u  update packages in docker build context
           "; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


_load_library_functions() {
    buildscriptsdir=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    proj_home=$(cd $(dirname $buildscriptsdir) && pwd)
    source $proj_home/dscripts/conf_lib.sh
}


_prepare_docker_build_env() {
    if [ -e $proj_home/build_prepare.sh ]; then
       $proj_home/build_prepare.sh $update_pkg
    fi
}


_remove_previous_image() {
    if [ "remove_img" == "True" ]; then
        ${sudo} docker rmi -f $IMAGENAME 2> /dev/null || true
    fi
}


_cd_to_Dockerfile_dir() {
    if [[ $DOCKERFILE_DIR ]]; then
        cd $DOCKERFILE_DIR
    fi
}


_prepare_proxy_args() {
    if [[ "${http_proxy}${https_proxy}" ]]; then
        no_proxy_noblanks=$(printf "${BUILD_IP},${no_proxy}" | tr -d '[:space:]')
        # Docker will import following env-variables without explicit ARG statement in Dockerfile
        BUILDARGS="$BUILDARGS --build-arg http_proxy=$http_proxy"
        BUILDARGS="$BUILDARGS --build-arg https_proxy=$https_proxy"
        BUILDARGS="$BUILDARGS --build-arg ftp_proxy=$ftp_proxy"
        BUILDARGS="$BUILDARGS --build-arg no_proxy=$no_proxy_noblanks"
        BUILDARGS="$BUILDARGS --build-arg HTTP_PROXY=$http_proxy"
        BUILDARGS="$BUILDARGS --build-arg HTTPS_PROXY=$https_proxy"
        BUILDARGS="$BUILDARGS --build-arg FTP_PROXY=$ftp_proxy"
        BUILDARGS="$BUILDARGS --build-arg NO_PROXY=$no_proxy_noblanks"
    fi
}


_prepare_build_command() {
    _prepare_proxy_args
    [[ $SET_BUILDINFO ]] && buildinfo=$(printf "$IMAGENAME build on node $HOSTNAME on $(date --iso-8601=seconds) by $LOGNAME" | sed -e "s/'//g")
    docker_build="docker build $BUILDARGS $CACHEOPT --label 'BUILDINFO=$buildinfo' -t $IMAGENAME$image_tag $DSCRIPTS_DOCKERFILE_OPT ."
    if [ "$print" == "True" ]; then
        echo $docker_build
    fi
    if [[ $REPO_STATUS ]]; then
        $buildscriptsdir/show_repo_branches.sh >> REPO_STATUS
    fi
}


_exec_build_command() {
    ${sudo} $docker_build
    rc=$?
    if (( $rc == 0 )); then
        echo "image: $IMAGENAME built."
        if [ "$push" == "True" ]; then
            ${sudo} docker push $DOCKER_REGISTRY/$IMAGENAME
        fi
    else
        echo -e '\E[33;31m'"\033[1mError\033[0m Docker build failed"
        exit $rc
    fi
}


_list_repo_branches() {
    echo "=== git repositories/branches and their last commit ==="
    $buildscriptsdir/show_repo_branches.sh
    echo
}


_do_cleanup() {
    if [ -e $proj_home/cleanup.sh ]; then
       $proj_home/cleanup.sh $update_pkg
    fi
}


main $@
