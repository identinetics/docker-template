#!/usr/bin/env bash

set -e

main() {
    get_options $@
    load_lib_and_config
    init_sudo
    docker_login_and_push
}


get_options() {
    while getopts ":p" opt; do
      case $opt in
        p) print="True";;
        *) echo "usage: $0 [-h] [-p]
           push docker image to registry
            -p  print docker commands on stdout
       "; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


load_lib_and_config() {
    # determine config script
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


exec_docker_cmd() {
    [ "$print" = "True" ] && echo $1
    ${sudo} $1
}


docker_login_and_push() {
    if [ "$travis" == "true" ]; then
        # inject uid/pw into CI via env vars; otherwise do docker login manually once
        exec_docker_cmd "docker login -u=\"$DOCKER_USERNAME\" -p=\"$DOCKER_PASSWORD\" $DOCKER_REGISTRY"
    fi
    exec_docker_cmd "docker push $DOCKER_REGISTRY/$IMAGENAME"
}


main $@
