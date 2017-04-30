#!/usr/bin/env bash



main() {
    get_options $@
    load_library_functions
    load_config
    init_sudo
    case $cmd in
        listlog) echo "$LOGFILES";;
        pull)    exec_docker_cmd "docker pull $DOCKER_REGISTRY/$IMAGENAME";;
        push)    exec_docker_cmd "docker push $DOCKER_REGISTRY/$IMAGENAME";;
        rm)      exec_docker_cmd "docker rm -f $CONTAINERNAME";;
        rmvol)   exec_docker_cmd "docker volume rm $VOLLIST";;
        *) echo "missing command"; usage; exit 1;;
    esac
}


get_options() {
    while getopts ":dp" opt; do
      case $opt in
        d) dryrun='True';;
        p) print="True";;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd=$1
}


usage() {
    echo "usage: $0 [-h] [-p] pull | push | rm
        more dscripts docker utilities
        -p  print docker command on stdout
        listlog list container logfiles
        pull    push to docker registry
        push    pull from docker registry
        rm      remove docker image (--force)
        rmvol   remove docker volumes defined in conf.sh
    "
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


exec_docker_cmd() {
    [ "$print" = "True" ] && echo $1
    if [[ "$dryrun" != "True" ]]; then
        ${sudo} $1
    fi
}


main $@
