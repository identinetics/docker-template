#!/usr/bin/env bash



main() {
    _get_options $@
    _load_library_functions
    load_config
    init_sudo
    [[ $sudo ]] && sudoopt='--sudo'
    case $cmd in
        follow_logs) _exec_docker_cmd "docker logs -f ${CONTAINERNAME}";;
        fl)        _exec_docker_cmd "docker logs -f ${CONTAINERNAME}";;
        logfiles)  _get_logfiles && echo "$LOGFILES";;
        logrotate) _call_logrotate;;
        logs)      _exec_docker_cmd "docker logs ${CONTAINERNAME}";;
        lsmount)   $PROJ_HOME/dscripts/docker_list_mounts.py $sudoopt -bov $CONTAINERNAME;;
        lsvol)     $PROJ_HOME/dscripts/docker_list_mounts.py $sudoopt -v $CONTAINERNAME;;
        multitail) _do_multitail;;
        mt)        _do_multitail;;
        pull)      _exec_docker_cmd "docker pull ${DOCKER_REGISTRY_PREFIX}${IMAGENAME}";;
        push)      _do_push;;
        rm)        _exec_docker_cmd "docker rm -f ${CONTAINERNAME}";;
        rmvol)     _do_rmvol;;
        status)    _call_container_status;;
        statcode)  get_container_status;;
        *) echo "missing command"; _usage; exit 1;;
    esac
}


_get_options() {
    while getopts ":dn:p" opt; do
      case $opt in
        d) dryrun='True';;
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        p) print="True";;
        *) _usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd=$1
}


_usage() {
    echo "usage: $0 [-h] [-p] <command>
        more docker utilities.

        -d  dry run - do not execute (except logrotate, status)
        -n  configuration number ('<NN>' in conf<NN>.sh) if using multiple configurations
        -p  print docker command on stdout

        Commands:
        fl, follow_logs docker logs -f <container>
        logfiles    list container logfiles
        logrotate   rotate, archive and purge logs
        logs        docker logs -f
        lsmount     list mounts (type: bind, volume and others)
        lsvol       list mounted volumes (type: docker volume)
        mt, multitail multitail on all logfiles in \$LOGFILES
        pull        push to docker registry
        push        pull from docker registry
        rm          remove docker container (--force)
        rmvol       remove docker volumes defined in conf.sh
        status      report container status (verbose)
        statcode    return: 0=running, 1=stopped, 2=not found
    "
}


_call_container_status() {
    if [[ $(declare -F container_status) ]]; then
        container_status  # in conf*.sh
    else
        $sudo docker ps | head -1
        $sudo docker ps --all | egrep $CONTAINERNAME\$
        echo "no specific status reporting configured for ${CONTAINERNAME} in conf.sh"
    fi
}


_call_logrotate() {
    if [[ $(declare -F logrotate) ]]; then
        logrotate    # in conf*.sh
    else
        echo "no logrotation configured for ${CONTAINERNAME} in conf.sh"
    fi
}


_load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


_do_multitail() {
    _get_logfiles
    [[ -z "$LOGFILES" ]] && echo 'No LOGFILES set on conf.sh' && exit 1
    cmd='multitail'
    for logfile in $LOGFILES; do
        cmd="${cmd} -i ${logfile}"
    done
    $cmd
}



_get_logfiles() {
    LOGFILES=''
    if [[ -n "$(type -t set_logfiles)" ]] && [[ "$(type -t set_logfiles)" == function ]]; then
        set_logfiles
    fi
    for lf in $KNOWN_LOGFILES; do
        if [[ -e $lf ]]; then
            export LOGFILES="$LOGFILES $lf"
        fi
    done
}


_do_push() {
    # requires docker login --username=<username> [non-default registry host]
    # (on a REHL instance docker.io is not default)
    if [[ ${DOCKER_REGISTRY_PREFIX} ]]; then
        _exec_docker_cmd "docker tag ${IMAGENAME} ${DOCKER_REGISTRY_PREFIX}${IMAGENAME}"
        _exec_docker_cmd "docker push ${DOCKER_REGISTRY_PREFIX}${IMAGENAME}"

    else
        _exec_docker_cmd "docker push ${DOCKER_REGISTRY_PREFIX}${IMAGENAME}"
    fi
}


_do_rmvol() {
    setup_vol_mapping 'list'
    if [[ $VOLLIST ]]; then
        echo "removing docker volumes $VOLLIST"
        _exec_docker_cmd "docker volume rm ${VOLLIST}"
    else
        echo "No volumes to be removed"
    fi
}


_exec_docker_cmd() {
    [ "$print" = "True" ] && echo $1
    if [[ "$dryrun" != "True" ]]; then
        ${sudo} $1
    fi
}


main $@
