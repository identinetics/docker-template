#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    load_library_functions
    load_config
    prepare_docker_build_env
    init_sudo
    remove_previous_image
    prepare_build_command
    exec_build_command
    list_repo_branches
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
    BUILDSCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $BUILDSCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


prepare_docker_build_env() {
    if [ -e $PROJROOT/build_prepare.sh ]; then
       $PROJROOT/build_prepare.sh $update_pkg
    fi
}


remove_previous_image() {
    if [ "remove_img" == "True" ]; then
        ${sudo} docker rmi -f $IMAGENAME 2> /dev/null || true
    fi
}


prepare_build_command() {
    docker_build="docker build $BUILDARGS $CACHEOPT -t=$IMAGENAME ."
    if [ "$print" == "True" ]; then
        echo $docker_build
    fi
}


exec_build_command() {
    ${sudo} $docker_build
    if (( $? == 0 )); then
        echo "image: $IMAGENAME built."
        if [ "$push" == "True" ]; then
            ${sudo} $SCRIPTDIR/push.sh
        fi
    else
        echo -e '\E[33;31m'"\033[1mError\033[0m Docker build failed"
    fi
}


list_repo_branches() {
    echo "List git repositories and their current branch"
    $BUILDSCRIPTDIR/show_repo_branches.sh
    echo
}


main $@