#!/bin/bash

# Generate the yaml argument files for tempalte processing from conf.sh


main() {
    _get_options $@
    _load_library_functions
    load_config
    init_sudo
    _create_args_file
}


_get_options() {
    while getopts ":n:" opt; do
      case $opt in
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        *) _usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
    cmd=$1
}


_usage() {
    echo "usage: $0 [-h] [-n <NN>] <command>

        -n  configuration number ('<NN>' in conf<NN>.sh) if using multiple configurations

        create argument file from conf.sh for template processing
    "
}


_load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


_create_args_file() {
    cat << EOT
DockerCompose:
    imagename: $IMAGENAME:$IMAGE_TAG_PRODENV
    containername: $CONTAINERNAME
    servicename: $SERVICEDESCRIPTION
    ipv4_address: $IPV4_ADDRESS
    shibduser: $SHIBDUSER
    httpduser: $HTTPDUSER
EOT
}