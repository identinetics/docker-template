#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    load_library_functions
    load_config
    prepare_command
    init_sudo
    perform_command
}


get_commandline_opts() {
    execcmd='/bin/bash'
    interactive_opt='-i'
    while getopts ":hbiIn:pru:" opt; do
      case $opt in
        b) interactive_opt='';;
        i) interactive_opt='-i';;
        I) interactive_opt='-i';;
        n) config_nr=$OPTARG
           re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]]; then
             echo "error: -n argument is not a number in the range frmom 02 .. 99" >&2; exit 1
           fi;;
        p) print='True';;
        r) useropt='-u 0';;
        u) useropt="-u $OPTARG";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    if [[ "$1" ]]; then
        execcmd=$@
    fi
}


usage() {
    echo "usage: $0 [-h] [-i] [-I] [-n <containernr>] [-p] [-r] [cmd]
       -b  non-interactive (no '-i' for docker exec)
       -h  print this help text
       -i  start in interactive mode
       -I  start in interactive mode (deprecated, same as -i)
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -p  print docker exec command on stdout
       -r  execute as root user
       -u  start command as user with specified uid
       cmd shell command to be executed (default is $execcmd)
       "
}


load_library_functions() {
    exec_scriptdir=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    exec_proj_home=$(cd $(dirname $exec_scriptdir) && pwd)
    source $exec_proj_home/dscripts/conf_lib.sh
}


get_run_status() {
    if [[ $config_nr ]]; then
        config_opt="-n $config_nr"
    fi
    ./dscripts/manage.sh $config_opt statcode
    is_running=$?
}


prepare_command() {
    if [[ -z "$1" ]]; then
        cmd=$execcmd
    else
        cmd=$@
    fi
    tty=''
    [[ -t 0 ]] && tty='-t'
    docker_exec="docker exec $interactive_opt $tty $useropt $CONTAINERNAME $cmd"
}


perform_command() {
    if [[ "$print" == 'True' ]]; then
        echo $docker_exec
    fi
    ${sudo} $docker_exec
}


main $@
