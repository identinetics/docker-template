#!/usr/bin/env bash
set -e -o pipefail

main() {
    get_commandline_opts $@
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


load_config() {
    # determine config script (there may be more than one to run multiple containers)
    # if config_nr not given and there is only one file matching conf*.sh take this one
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJROOT=$(cd $(dirname $SCRIPTDIR) && pwd)
    cd $PROJROOT; confs=(conf*.sh); cd $OLDPWD
    source $SCRIPTDIR/conf_lib.sh  # load library functions

    if [ ! -z ${config_nr} ]; then
        conf_script=conf${config_nr}.sh
        if [ ! -e "$PROJROOT/$conf_script" ]; then
            echo "$PROJROOT/$conf_script not found"
            exit 1
        fi
    elif [ ${#confs[@]} -eq 1 ]; then
        conf_script=${confs[0]}
    else
        echo "No or more than one (${#confs[@]}) conf*.sh: need to provide -n argument:"
        printf "%s\n" "${confs[@]}"
        exit 1
    fi
    source $PROJROOT/$conf_script
}


prepare_docker_build_env() {
    if [ -e $PROJROOT/build_prepare.sh ]; then
       $PROJROOT/build_prepare.sh $update_pkg
    fi
}


init_sudo() {
    if [ $(id -u) -ne 0 ]; then
        sudo="sudo"
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
    $SCRIPTDIR/show_repo_branches.sh
}


main $@