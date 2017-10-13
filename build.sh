#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    load_library_functions
    load_config '--build'
    cd_to_Dockerfile_dir
    prepare_docker_build_env
    init_sudo
    remove_previous_image
    prepare_build_command
    exec_build_command
    list_repo_branches
    do_cleanup

}

get_commandline_opts() {
    while getopts ":chn:pPru" opt; do
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
        u) update_pkg="-u";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) echo "usage: $0 [-h] [-i] [-n <NN>] [-p] [-P] [-r] [cmd]
             -c  do not use cache (build --no-cache)
             -h  print this help text
             -n  configuration number ('<NN>' in conf<NN>.sh)
             -p  print docker build command on stdout
             -P  push after build
             -r  remove existing image (-f)
             -u  update packages in docker build context
           "; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


load_library_functions() {
    buildscriptsdir=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    proj_home=$(cd $(dirname $buildscriptsdir) && pwd)
    source $proj_home/dscripts/conf_lib.sh
}


prepare_docker_build_env() {
    if [ -e $proj_home/build_prepare.sh ]; then
       $proj_home/build_prepare.sh $update_pkg
    fi
}


remove_previous_image() {
    if [ "remove_img" == "True" ]; then
        ${sudo} docker rmi -f $IMAGENAME 2> /dev/null || true
    fi
}


cd_to_Dockerfile_dir() {
    if [[ $DOCKERFILE_DIR ]]; then
        cd $DOCKERFILE_DIR
    fi
}


prepare_proxy_args() {
    if [[ "${http_proxy}${https_proxy}" ]]; then
        no_proxy_noblanks=$(printf "${BUILD_IP},${no_proxy}" | tr -d '[:space:]')
        # Docker will import following env-variables without explicit ARG statement in Dockerfile
        BUILDARGS="$BUILDARGS --build-arg http_proxy=$http_proxy"
        BUILDARGS="$BUILDARGS --build-arg https_proxy=$https_proxy"
        BUILDARGS="$BUILDARGS --build-arg ftp_proxy=$ftp_proxy"
        BUILDARGS="$BUILDARGS --build-arg no_proxy=$no_proxy_noblanks"
    fi
}


prepare_build_command() {
    prepare_proxy_args
    docker_build="docker build $BUILDARGS $CACHEOPT -t=$IMAGENAME $DSCRIPTS_DOCKERFILE_OPT ."
    if [ "$print" == "True" ]; then
        echo $docker_build
    fi
    # Adding LASTBUILD to the image metadata is not feasible until docker provides a method
    # to do this after building it;
    #printf "$IMAGENAME build on node $HOSTNAME on $(date --iso-8601=seconds) by $LOGNAME from:\n" > LASTBUILD
    if [[ $REPO_STATUS ]]; then
        $buildscriptsdir/show_repo_branches.sh >> REPO_STATUS
    fi
}


exec_build_command() {
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


list_repo_branches() {
    echo "=== git repositories/branches and their last commit ==="
    $buildscriptsdir/show_repo_branches.sh
    echo
}

do_cleanup() {
    if [ -e $proj_home/cleanup.sh ]; then
       $proj_home/cleanup.sh $update_pkg
    fi
}


main $@
