#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    load_library_functions
    load_config
    prepare_command
    init_sudo
    run_command
}


get_commandline_opts() {
    EXECCMD='/bin/bash'
    runopt='-it'
    while getopts ":hiIln:pr" opt; do
      case $opt in
        I) runopt='';;
        l) logpurge='True';;
        n) config_nr=$OPTARG
           re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument is not a number in the range frmom 02 .. 99" >&2; exit 1
           fi;;
        p) print='True';;
        r) useropt='-u 0';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    if [[ "$logpurge" = 'True' ]]; then
        if [[ -z "$1"  ]]; then
            EXECCMD='/logpurge.sh'
        else
            echo "-l and cmd are mutually exclusive"
        fi
    fi
    if [[ $1 ]]; then
        EXECCMD=$@
    fi
}


usage() {
    echo "usage: $0 [-h] [-i] [-I] [-n <containernr>] [-p] [-r] [cmd]
       -h  print this help text
       -i  interactive (default; results in options -it for docker exec)
       -I  non-interactive (no -it for docker exec)
       -l  logpurge (execute /logpurge.sh in container) - mutual exclusive with cmd
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -p  print docker exec command on stdout
       -r  execute as root user
       cmd shell command to be executed (default is $EXECCMD)
       "
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


prepare_command() {
    if [ -z "$1" ]; then
        cmd=$EXECCMD
    else
        cmd=$@
    fi
    docker_exec="docker exec $runopt $useropt $CONTAINERNAME $cmd"
}


run_command() {
    if [ "$print" = 'True' ]; then
        echo $docker_exec
    fi
    ${sudo} $docker_exec
}


main $@
