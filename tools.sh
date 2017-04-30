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
    while getopts ":dn:p" opt; do
      case $opt in
        d) dryrun='True';;
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        p) print="True";;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd=$1
}


usage() {
    echo "usage: $0 [-h] [-p] listlog|pull|push|rm|rmvol
        more dscripts docker utilities
        -d  dry run - do not execute
        -n  configuration number ('<NN>' in conf<NN>.sh) if using multiple configurations
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
