#!/usr/bin/env bash
#set -e -o pipefail

main() {
    get_commandline_opts  $@
    load_library_functions
    load_config
    init_sudo
    verify_image
}


get_commandline_opts() {
    while getopts ":hin:prRv" opt; do   # same args as run.sh - ignore unused ones
      case $opt in
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" >&2; exit 1
           fi
           config_nr=$OPTARG;;
        v) verbose='True';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) echo "usage: $0 [-h] [-n container-nr ]
           -h  print this help text
           -n  configuration number ('<NN>' in conf<NN>.sh)"; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


verify_image() {
    generate_local_didi
    make_tempdir
    fetch_remote_didi
    compare_local_with_remote_didi  # to detect errors before the signature check
    verify_signature
    cleanup_tempdir
}


generate_local_didi() {
    DIDI_FILENAME=$(dscripts/create_didi.py $IMAGENAME)
    [ "$verbose" == 'True' ] && echo "generated didi/$DIDI_FILENAME"
}


make_tempdir() {
    TEMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'dscripts_tmp')  # works for Linux + OSX
}


fetch_remote_didi() {
    cd $TEMPDIR
    DIDIDIR=$(get_metadata 'didi_dir')
    DIDIFILE="${DIDIDIR}/${DIDI_FILENAME}"
    [ "$verbose" == 'True' ] && echo "GET $DIDIFILE"
    wget $DIDIFILE
    [ "$verbose" == 'True' ] && echo "GET $DIDIFILE.sig"
    wget $DIDIFILE.sig
}


compare_local_with_remote_didi() {
    diff -q $DIDI_FILENAME $TEMPDIR/$DIDI_FILENAME
    if ( $? > 0 ); then
        echo "Local ($DIDI_FILENAME) and remote ($DIDIFILE) DIDI files are different."
        echo "Image verfication failed"
        exit 1
    else
        [ "$verbose" == 'True' ] && echo "Local ($DIDI_FILENAME) and remote ($DIDIFILE) DIDI files are identical."
    fi
}


verify_signature() {
    gpg2 --verify $TEMPDIR/$DIDI_FILENAME.sig $TEMPDIR/$DIDI_FILENAME
    if ( $? > 0 ); then
        echo "Signature of DIDI broken. Image verfication failed."
        exit 1
    else
        echo "Signature of DIDI valid. Image verfication passed."
    fi
}


cleanup_tempdir() {
    rm -rf $TEMPDIR
}


main $@