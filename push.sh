#!/usr/bin/env bash

main() {
    get_options $@
    load_library_functions
    load_config
    init_sudo
    docker_login_and_push
}


get_options() {
    while getopts ":n:p" opt; do
      case $opt in
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        p) print="True";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
}


usage() {
    echo "usage: $0 [-h] [-p]
        push docker image to registry
        -n  configuration number ('<NN>' in conf<NN>.sh)
        -p  print docker commands on stdout
    "
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
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
