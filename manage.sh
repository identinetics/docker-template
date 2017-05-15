#!/usr/bin/env bash



main() {
    get_options $@
    load_library_functions
    load_config
    init_sudo
    case $cmd in
        logfiles)  echo "$LOGFILES";;
        logrotate) call_logrotate;;
        logs)      exec_docker_cmd "docker logs -f $CONTAINERNAME";;
        multitail) call_multitail;;
        pull)      exec_docker_cmd "docker pull $$DOCKER_REGISTRY_PREFIX$IMAGENAME";;
        push)      exec_docker_cmd "docker push $DOCKER_REGISTRY_PREFIX$IMAGENAME";;
        rm)        exec_docker_cmd "docker rm -f $CONTAINERNAME";;
        rmvol)     exec_docker_cmd "docker volume rm $VOLLIST";;
        status)    call_container_status;;
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
    echo "usage: $0 [-h] [-p] listlog|logrotate|pull|push|rm|rmvol|status
        more dscripts docker utilities
        -d  dry run - do not execute (except logrotate, status)
        -n  configuration number ('<NN>' in conf<NN>.sh) if using multiple configurations
        -p  print docker command on stdout
        logfiles   list container logfiles
        logrotate  rotate, archive and purge logs
        logs       docker logs -f
        multitail  multitail on all logfiles in \$VOLLIST
        pull       push to docker registry
        push       pull from docker registry
        rm         remove docker image (--force)
        rmvol      remove docker volumes defined in conf.sh
        status     report container status
    "
}


call_container_status() {
    if [[ $(declare -F container_status) ]]; then
        container_status
    else
        $sudo docker ps | head -1
        $sudo docker ps --all | egrep $CONTAINERNAME\$
        echo "no specific status reporting configured for ${CONTAINERNAME} in conf.sh"
    fi
}


call_logrotate() {
    if [[ $(declare -F logrotate) ]]; then
        logrotate
    else
        echo "no logrotation configured for ${CONTAINERNAME} in conf.sh"
    fi
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


call_multitail(){
    [[ -z "$VOLLIST" ]] && echo 'No LOGFILES set on conf.sh' && exit 1
    cmd='multitail'
    for logile in $VOLLIST; do
        cmd="${cmd} -i ${logfile}"
    done
    $cmd
}


exec_docker_cmd() {
    [ "$print" = "True" ] && echo $1
    if [[ "$dryrun" != "True" ]]; then
        ${sudo} $1
    fi
}


main $@
