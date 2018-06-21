#!/bin/bash

main() {
    get_options "$@"
    init_sudo
    test_if_already_running
    remove_container
    run_command "$@"
}




get_options() {
    runmode='-d --restart=unless-stopped'
    tty=''
    while getopts ":ir" opt; do
      case $opt in
        i) runmode='--rm -i' && [[ -t 0 ]] && runmode="$runmode -t";;
        r) useropt='-u 0';;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd="$@"
}


usage() {
    echo "usage: $0 [-i] [<command>]
        run image
        -i      interactive mode (including --rm)
        -r      start as root
    "
}


init_sudo() {
    if (( $(id -u) != 0 )); then
        sudo='sudo -n'
    fi
}


get_container_status() {
    if [[ "$(${sudo} docker ps -f name=$CONTAINERNAME  |egrep -v ^CONTAINER)" ]]; then
        return 0   # running
    elif [[ "$(${sudo} docker ps -a -f name=$CONTAINERNAME |egrep -v ^CONTAINER)" ]]; then
        return 1   # stopped
    else
        return 2   # not found
    fi
}


test_if_already_running() {
    if [[ "$($sudo docker ps -f name=$CONTAINERNAME |egrep -v ^CONTAINER)" ]]; then
        is_running='True'
    elif [[ "$($sudo docker ps -a -f name=$CONTAINERNAME|egrep -v ^CONTAINER)" ]]; then
        is_stopped='True'
    fi
}


remove_container() {
    if [[ "$is_stopped" ]]; then
        $sudo docker rm $CONTAINERNAME
        echo "docker rm $CONTAINERNAME"
    elif [[ "$is_running" ]]; then
        $sudo docker rm -f $CONTAINERNAME
        echo "docker rm -f $CONTAINERNAME"
    fi
}


run_command() {
    echo "starting $CONTAINERNAME"
