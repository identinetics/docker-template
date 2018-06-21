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
    tty=''
    while getopts ":CdhiIn:o:pPrRu:Vw" opt; do
      case $opt in
        C) ignore_capabilties='True';;
        d) dryrun='True';;
        i) interactive_opt='True'; [[ -t 0 ]] && tty='-t';;
        I) interactive_opt='True'; [[ -t 0 ]] && tty='-t';;
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        o) extra_run_opt=$OPTARG;;
        p) print_opt='True';;
        P) pwd_opt='True';;
        r) user_opt='-u 0';;
        R) runonly_if_notrunning='True';;
        u) user_opt='-u '$OPTARG;;
        V) no_verify='True';;
        w) write_script='True' && dryrun='True';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) _usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd="$@"
}


_usage() {
    echo "usage: $0 [-h] [-C] [-d] [-i] [-I] [-n container-nr ] [-p] [-P] [-R] [-r | -u] [-V] [-w] [cmd]
       -C  ignore capabilties configured in Dockerfile LABEL
       -d  dry run - do not execute
       -h  print this help text
       -i  start in interactive mode
       -I  start in interactive mode (samle as -i, deprecated)
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -o  add extra `docker run` options
       -p  print docker run command on stdout
       -P  add volume mapping $PWD:/pwd:Z
       -r  run as root
       -R  do nothing if already running (i.e. keep existing container)
       -u  run as user with specified uid
       -V  skip image verification
       -w  write Docker command to bash script (implies dry run)
       cmd shell command to be executed (default is $STARTCMD)

    Note: by default an exisitng container will be removed before a new one is started"
}


_load_library_functions() {
    runscriptdir=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $runscriptdir) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


_verify_signature() {
    if [[ ! -z "$DIDI_SIGNER" && "$no_verify" != 'True' ]]; then
        if [[ ! -z "$config_nr" ]]; then
            verifyconf="-n $config_nr"
        fi
        [[ "$print_opt" ]] || verify_verbose='-V'
        dscripts/verify.sh $verify_verbose $verifyconf
        if (( $? > 0)); then
            echo "Image verfication failed, container not started."
            exit 1
        fi
    fi
}

_test_if_already_running() {
    get_container_status
    cont_stat=$?
    if (( ""$cont_stat == 0 )); then
        is_running='True'
    elif (( $cont_stat == 1 )); then
        is_stopped='True'
    elif (( $cont_stat == 2 )); then
        not_found='True'
    fi
}


_remove_existing_container() {
    if [[ "$not_found" ]]; then
        return  # nothing to remove
    fi
    if [[ "$is_running" == 'True' && "$runonly_if_notrunning" != 'True' ]]; then
        forceopt='-f'
    fi
    docker_rm="$sudo docker rm ${forceopt} $CONTAINERNAME"
    if [[ "$print_opt" == "True" ]]; then
        echo ${docker_rm}
    fi
    if [[ "$dryrun" == "True" ]]; then
        echo 'dryrun: not executing `docker rm`'
    else
        $docker_rm
    fi
}


_write_standalone_run_script() {
    if [[ "$write_script" ]]; then
        if [[ "$IMAGE_TAG_PRODENV" ]]; then
            local img="${DOCKER_REGISTRY_PREFIX}${IMAGENAME}:${IMAGE_TAG_PRODENV}"
        else
            echo "missing IMAGE_TAG_PRODENV in conf.sh"
            exit 1
        fi
        outdir="$PROJ_HOME/out"
        mkdir -p $outdir
        envsubst '$CONTAINERNAME' < $runscriptdir/templates/standalone_run.sh \
                                                    > "${outdir}/${CONTAINERNAME}_run.sh"
        echo "    \$sudo docker run \$runmode ${run_args[@]} ${img} ${cmd} \$1" >> "${outdir}/${CONTAINERNAME}_run.sh"
        printf "}\n\n\n"                           >> "${outdir}/${CONTAINERNAME}_run.sh"
        printf "main\n"                            >> "${outdir}/${CONTAINERNAME}_run.sh"

        chmod +x ${outdir}/${CONTAINERNAME}_run.sh
        echo "created ${outdir}/${CONTAINERNAME}_run.sh"
    fi
}


_prepare_run_command() {
    if [[ "$interactive_opt" == 'False' ]]; then
        runmode='-d --restart=unless-stopped'
        background_msg='started in background with containerid '
    else
        runmode="-i $tty --rm"
    fi
    if [[ -n "$START_AS_ROOT" && ! $user_opt ]]; then   # options override conf.sh
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
    run_args=($user_opt --hostname=$CONTAINERNAME --name=$CONTAINERNAME
        $label $CAPABILITIES $ENVSETTINGS $NETWORKSETTINGS $VOLMAPPING $USBMAPPING $extra_run_opt)
    _write_standalone_run_script
    run_args="$runmode $run_args"
    echo "run_args: $run_args"
}


_run_command() {
    run_cmd="$sudo docker run ${run_args[@]} $IMAGENAME $cmd"
    if [[ "$print_opt" == "True" ]]; then
        echo $run_cmd
    fi
    if [[ "$dryrun" == "True" ]]; then
        echo 'dryrun: not executing `docker run`'
    elif [[ "$is_running" == 'True' && "$runonly_if_notrunning" == 'True' ]]; then
        echo "already running"
    else
        printf '%s' "$background_msg"
        $run_cmd $@
    fi
}


main "$@"
