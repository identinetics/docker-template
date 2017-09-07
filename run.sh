#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    load_library_functions
    init_sudo
    load_config
    verify_signature
    remove_existing_container
    create_intercontainer_network
    setup_vol_mapping 'create'
    get_capabilities
    prepare_run_command
    run_command
}


get_commandline_opts() {
    interactive_opt='False'
    remove_opt='True'
    while getopts ":CdhiIn:prRu:V" opt; do
      case $opt in
        C) ignore_capabilties='True';;
        d) dryrun='True';;
        i) interactive_opt='True'; tty='-t';;
        I) interactive_opt='True'; tty='';;
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        p) print_opt='True';;
        r) user_opt='-u 0';;
        R) remove_opt='False';;
        u) user_opt='-u '$OPTARG;;
        V) no_verify='True';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd="$@"
}


usage() {
    echo "usage: $0 [-h] [-C] [-i] [-n container-nr ] [-p] [-r] -[R] [cmd]
       -C  ignore capabilties configured in Dockerfile LABEL
       -d  dry run - do not execute
       -h  print this help text
       -i  start in interactive mode and assign terminal
       -I  start in interactive mode and do not assign terminal
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -p  print docker run command on stdout
       -r  start command as root user (default is $CONTAINERUSER)
       -R  do not remove existing container before start (default: do remove)
       -u  start command as user with specified uid
       -V  skip image verification
       cmd shell command to be executed (default is $STARTCMD)"
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


verify_signature() {
    if [[ ! -z "$DIDI_SIGNER" && "$no_verify" != 'True' ]]; then
        if [[ ! -z "$config_nr" ]]; then
            verifyconf="-n $config_nr"
        fi
        [[ "$PRINT" == 'True' ]] || VERIFY_VERBOSE='-V'
        dscripts/verify.sh $VERIFY_VERBOSE $verifyconf
        if (( $? > 0)); then
            echo "Image verfication failed, container not started."
            exit 1
        fi
    fi
}


remove_existing_container() {
    if [[ "$remove_opt" == 'True' ]]; then
        $sudo docker ps -a | grep $CONTAINERNAME > /dev/null && $sudo docker rm -f $CONTAINERNAME
    fi
}


prepare_run_command() {
    if [[ "$interactive_opt" == 'False' ]]; then
        runmode='-d --restart=unless-stopped'
    else
        runmode="-i $tty --rm"
    fi
    if [[ -z "$user_opt" ]] && [[ ! -z $CONTAINERUID ]]; then
        user_opt="-u $CONTAINERUID"
    fi
    if [[ -n "$START_AS_ROOT" ]]; then
        user_opt='-u 0'
    fi
    if [[ -z "$cmd" ]]; then
        cmd=$STARTCMD
    fi
    if [[ ! -z "$SERVICEDESCRIPTION" ]]; then
        label="--label x.service=$SERVICEDESCRIPTION"
    fi
    if [[ $ignore_capabilties ]]; then
        CAPABILITIES=''
    fi
    # shells do not expand variables with quotes and spaces as needed, use array instead (http://mywiki.wooledge.org/BashFAQ/050)
    run_args=($runmode $remove $user_opt --hostname=$CONTAINERNAME --name=$CONTAINERNAME
        $label $CAPABILITIES $ENVSETTINGS $NETWORKSETTINGS $VOLMAPPING $IMAGENAME $cmd)
}


run_command() {
    if [[ "$print_opt" == "True" ]]; then
        echo docker run "${run_args[@]}"
    fi
    if [[ "$dryrun" != "True" ]]; then
        $sudo docker run "${run_args[@]}"
    fi
}


main "$@"