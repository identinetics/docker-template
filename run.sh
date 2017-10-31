#!/usr/bin/env bash

main() {
    _get_commandline_opts $@
    _load_library_functions
    init_sudo
    load_config
    _verify_signature
    _test_if_already_running
    _remove_existing_container
    create_intercontainer_network
    setup_vol_mapping 'create'
    get_capabilities
    _prepare_run_command
    _run_command
}


_get_commandline_opts() {
    interactive_opt='False'
    while getopts ":CdhiIn:pPrRu:V" opt; do
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
        P) pwd_opt='True';;
        r) user_opt='-u 0';;
        R) runonly_if_notrunning='True';;
        u) user_opt='-u '$OPTARG;;
        V) no_verify='True';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) _usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd="$@"
}


_usage() {
    echo "usage: $0 [-h] [-C] [-d] [-i] [-I] [-n container-nr ] [-p] [-P] [-r] -[R] [-u] [-V] [cmd]
       -C  ignore capabilties configured in Dockerfile LABEL
       -d  dry run - do not execute
       -h  print this help text
       -i  start in interactive mode and assign terminal
       -I  start in interactive mode and do not assign terminal
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -p  print docker run command on stdout
       -P  add volume mapping $PWD:/pwd:Z
       -r  run as root
       -R  do nothing if already running (i.e. keep existing container)
       -u  run as user with specified uid
       -V  skip image verification
       cmd shell command to be executed (default is $STARTCMD)

    Note: by default an exisitng container will be removed before a new one is started"
}


_load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


_verify_signature() {
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

_test_if_already_running() {
    cont_stat=get_container_status
    if (( $cont_stat == 0 )); then
        is_running='True'
    elif (( $cont_stat == 1 )); then
        is_stopped='True'
    fi
}


_remove_existing_container() {
    if [[ "$dryrun" == "True" ]]; then
        echo 'dryrun: not executing `docker rm`'
    elif [[ "$is_stopped" == 'True' ]]; then
        $sudo docker rm $CONTAINERNAME
    elif [[ "$is_running" == 'True' && "$runonly_if_notrunning" != 'True' ]]; then
        $sudo docker rm -f $CONTAINERNAME
    fi
}


_prepare_run_command() {
    if [[ "$interactive_opt" == 'False' ]]; then
        runmode='-d --restart=unless-stopped'
        background_msg='started in background with containerid '
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
    if [[ $pwd_opt ]]; then
        VOLMAPPING="$VOLMAPPING -v $PWD:/pwd:Z"
    fi
    # shells do not expand variables with quotes and spaces as needed, use array instead (http://mywiki.wooledge.org/BashFAQ/050)
    run_args=($runmode $remove $user_opt --hostname=$CONTAINERNAME --name=$CONTAINERNAME
        $label $CAPABILITIES $ENVSETTINGS $NETWORKSETTINGS $VOLMAPPING $USBMAPPING $IMAGENAME $cmd)
}


_run_command() {
    if [[ "$print_opt" == "True" ]]; then
        echo "$sudo docker run ${run_args[@]}"
    fi
    if [[ "$dryrun" == "True" ]]; then
        echo 'dryrun: not executing `docker run`'
    elif [[ "$is_running" == 'True' && "$runonly_if_notrunning" == 'True' ]]; then
        echo "already running"
    else
        printf '%s' "$background_msg"
        $sudo docker run "${run_args[@]}"
    fi
}


main "$@"
