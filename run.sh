#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    load_library_functions
    load_config
    init_sudo
    remove_existing_container
    verify_signature $@
    prepare_run_command
    run_command
}


get_commandline_opts() {
    while getopts ":dhin:prRV" opt; do
      case $opt in
        d) dryrun='True';;
        i) runopt='-it --rm';;
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        p) print="True";;
        r) useropt='-u 0';;
        R) remove='True';;
        V) no_verify='True';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd=$@
}


usage() {
    echo "usage: $0 [-h] [-i] [-n container-nr ] [-p] [-r] -[R] [cmd]
       -d  dry run - do not execute
       -h  print this help text
       -i  start in interactive mode and remove container afterwards
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -p  print docker run command on stdout
       -r  start command as root user (default is $CONTAINERUSER)
       -R  remove dangling container before start
       -V  skip image verification
       cmd shell command to be executed (default is $STARTCMD)"
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}

remove_existing_container() {
    if [ -e $remove ]; then
        $sudo docker ps -a | grep $CONTAINERNAME > /dev/null && docker rm -f $CONTAINERNAME
    fi
}


verify_signature() {
    if [[ ! -z "$DIDI_SIGNER" && "$no_verify" != 'True' ]]; then
        if [ ! -z "$config_nr" ]; then
            verifyconf="-n $config_nr"
        fi
        [ "$PRINT" == 'True' ] || VERIFY_VERBOSE='-V'
        dscripts/verify.sh $VERIFY_VERBOSE $verifyconf
        if (( $? > 0)); then
            echo "Image verfication failed, container not started."
            exit 1
        fi
    fi
}


prepare_run_command() {
    if [ -z "$runopt" ]; then
        runopt='-d --restart=unless-stopped'
    fi
    if [ -z "$useropt" ] && [ ! -z $CONTAINERUID ]; then
        useropt="-u $CONTAINERUID"
    fi
    if [ -n "$START_AS_ROOT" ]; then
        useropt='-u 0'
    fi
    if [ -z "$cmd" ]; then
        cmd=$STARTCMD
    fi
    docker_run="docker run $runopt $useropt --hostname=$CONTAINERNAME --name=$CONTAINERNAME
        $CAPABILITIES $ENVSETTINGS $NETWORKSETTINGS $VOLMAPPING $IMAGENAME $cmd"
}


run_command() {
    $sudo docker rm -f $CONTAINERNAME 2>/dev/null || true
    if [ "$print" == "True" ]; then
        echo $docker_run
    fi
    if [ "$dryrun" != "True" ]; then
        $sudo $docker_run
    fi
}


main $@