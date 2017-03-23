#!/usr/bin/env bash

main() {
    get_options $@
    load_library_functions
    load_config
    init_sudo
    docker_login_and_push
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
        push docker image to registry
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
