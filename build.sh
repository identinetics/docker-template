#!/usr/bin/env bash

main() {
    _get_commandline_opts $@
    _load_library_functions
    load_config '--build'
    image_name_tagged="${IMAGENAME}${image_tag}"
    _cd_to_Dockerfile_dir
    _prepare_docker_build_env
    init_sudo
    _remove_previous_image
    _prepare_build_command
    _list_repo_branches
    _exec_build_command
    _do_cleanup
    if [[ "$manifest" ]]; then
        _generate_manifest_and_image_build_number
        _tag_with_build_number
    fi
    _push_image
}


_get_commandline_opts() {
    manifest='True'
    unset image_tag
    while getopts ":bchmMn:pPrt:u" opt; do
      case $opt in
        b) SET_BUILDINFO='True';;
        c) CACHEOPT="--no-cache";;
        m) manifest='True';;
        M) unset manifest;;
        n) config_nr=$OPTARG
           re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
              echo "error: -n argument is not a number in the range frmom 02 .. 99" >&2; exit 1
           fi
           config_opt="-n ${config_nr}";;
        p) print='True';;
        P) push='True';;
        r) remove_img='True';;
        t) image_tag=":${OPTARG}";;
        u) update_pkg="-u";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) echo "usage: $0 [-b] [-c] [-h] [-m] [-M] [-n <NN>] [-p] [-P] [-r] [-t tag] [-u] [cmd]
             -b  include label BUILDINFO
             -c  do not use cache (build --no-cache)
             -h  print this help text
             -m  generate manifest for build number generation (default)
             -M  do not generate manifest for build number generation
             -n  configuration number ('<NN>' in conf<NN>.sh)
             -p  print docker build command on stdout
             -P  push after build
             -r  remove existing image (-f)
             -t  add this tag to the build target name
             -u  run build_prepare.sh (update packages in docker build context)
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
    if [[ -e $proj_home/build_prepare.sh ]]; then
       $proj_home/build_prepare.sh $update_pkg
    fi
}


_remove_previous_image() {
    if [[ "$remove_img" ]]; then
        cmd="${sudo} docker rmi -f ${image_name_tagged}"
        [[ "$print" ]] && "echo $cmd 2> /dev/null"
        $cmd 2> /dev/null || true
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
    if [[ $SET_BUILDINFO ]]; then
        buildinfo=$(printf "$image_name_tagged build on node $HOSTNAME on $(date --iso-8601=seconds) by $LOGNAME" | sed -e "s/'//g")
        buildinfo_opt="--label 'BUILDINFO=${buildinfo}'"
    fi
    docker_build="docker build $BUILDARGS $CACHEOPT $buildinfo_opt -t $image_name_tagged $DSCRIPTS_DOCKERFILE_OPT ."
    [[ "$print" ]] && echo $docker_build
    if [[ $REPO_STATUS ]]; then
        $buildscriptsdir/show_repo_branches.sh >> REPO_STATUS
    fi
}


_exec_build_command() {
    ${sudo} $docker_build
    rc=$?
    if (( $rc == 0 )); then
        echo "image: $image_name_tagged built."
    else
        echo -e '\E[33;31m'"\033[1mError\033[0m Docker build failed"
        exit $rc
    fi
}


_list_repo_branches() {
    echo "=== git repositories/branches and their last commit ===" > REPO_STATUS
    $buildscriptsdir/show_repo_branches.sh >> REPO_STATUS
    cat REPO_STATUS
    echo
}


_do_cleanup() {
    if [[ -e $proj_home/cleanup.sh ]]; then
       $proj_home/cleanup.sh $update_pkg
    fi
}


_generate_manifest_and_image_build_number() {
    get_container_status
    is_running=$?
    if (( $is_running == 0 )); then
        echo "Container already running. Cannot generate manifest, image not tagged"
        exit 1
    elif [[ ! -e "$buildscriptsdir/manifest.sh"  ]]; then
        echo "cannot run '$buildscriptsdir/manifest.sh'; image not tagged"
        exit 2
    fi
    mkdir -p $proj_home/manifest
    manifest_temp="$proj_home/manifest/manifest.tmp"
    $buildscriptsdir/manifest.sh > $manifest_temp
    $buildscriptsdir/run.sh -i /opt/bin/manifest2.sh | sed -e 's/\r$//' >> $manifest_temp
    build_number_file=$(mktemp)
    python3 $buildscriptsdir/buildnbr.py $manifest_temp $MANIFEST_SCOPE $build_number_file
    build_number=$(cat $build_number_file)
    rm $build_number_file
}


_tag_with_build_number() {
    cmd="${sudo} docker tag ${IMAGENAME} ${IMAGENAME}:B${build_number}"
    [[ "$print" ]] && echo $cmd
    $cmd && echo "Successfully tagged ${IMAGENAME}:B${build_number}"
}


_push_image() {
    # push both build image name with :latest or -t tag and (optionally) with build_number tag
    if [[ "$push" ]]; then
        cmd="${sudo} docker push ${DOCKER_REGISTRY_PREFIX}$image_name_tagged"
        [[ "$print" ]] && echo $cmd
        $cmd
        if [[ "$manifest" ]]; then
            cmd="${sudo} docker push ${DOCKER_REGISTRY_PREFIX}${IMAGENAME}:${build_number}"
            [[ "$print" ]] && echo $cmd
            $cmd
        fi
    fi

}


main $@

