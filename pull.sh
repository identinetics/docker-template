#!/usr/bin/env bash

main() {
    get_options $@
    load_library_functions
    load_config
    init_sudo
    exec_docker_cmd "docker pull $DOCKER_REGISTRY/$IMAGENAME"
}


get_options() {
    while getopts ":p" opt; do
      case $opt in
        p) print="True";;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
}


usage() {
    echo "usage: $0 [-h] [-p]
        pull docker image from registry
        -p  print docker command on stdout
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


main $@
