#!/bin/bash

# Generate the yaml argument files for tempalte processing from conf.sh


main() {
    _get_options "$@"
    _load_library_functions
    load_config
    init_sudo
    create_intercontainer_network
    #setup_vol_mapping 'create'
    _create_args_file
    _create_compose_yaml
}


_get_options() {
    while getopts ":n:t:T" opt; do
      case $opt in
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        t) imgtag=$OPTARG;;
        T) use_imgtag_prodenv='True';;
        *) _usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd=$1
    if [[ "$use_imgtag_prodenv" && "$imgtag" ]]; then
        echo 'conflicting args -t and -T: do not specify both'
        exit 1
    fi
    if [[ "$use_imgtag_prodenv" && -z "$IMAGE_TAG_PRODENV" ]]; then
        echo 'option -T: reuqires IMAGE_TAG_PRODENV to be set in conf.sh'
        exit 1
    fi
}


_usage() {
    echo "usage: $0 [-h] [-n <NN>] [-t <tag> ] [-T] <command>

        -n  configuration number ('<NN>' in conf<NN>.sh) if using multiple configurations
        -t  specify docker image tag
        -T  use image tag defined in IMAGE_TAG_PRODENV (conf.sh)

        create docker-compose.yaml from conf.sh
    "
}


_load_library_functions() {
    local scriptdir=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    proj_home=$(cd $(dirname $scriptdir) && pwd)
    source $proj_home/dscripts/conf_lib.sh
}


_create_args_file() {
    local tag_suffix=''
    [[ $imgtag ]] && tag_suffix=":$IMAGE_TAG_PRODENV"
    [[ "$IMAGE_TAG_PRODENV" ]] && tag_suffix=":$IMAGE_TAG_PRODENV"
    conf_yaml="work/conf${config_nr}.yaml"
    mkdir -p work

    cat > $conf_yaml << EOT
DockerCompose:
    imagename: $IMAGENAME$tag_suffix
    containername: $CONTAINERNAME
    servicename: $SERVICEDESCRIPTION
    ipv4_address: $IPV4_ADDRESS
    shibduser: $SHIBDUSER
    httpduser: $HTTPDUSER
EOT
}


_create_compose_yaml() {
    compose_yaml="work/docker-compose${config_nr}.yaml"
    # require python3 with yaml & jinja2 (-> `pip3 install PyYaml jinja2`)
    python3 dscripts/render_template.py $conf_yaml docker-compose.template DockerCompose \
        > $compose_yaml
    echo "created $compose_yaml"
}

main "$@"
