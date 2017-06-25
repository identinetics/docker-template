#!/usr/bin/env bash

main() {
    get_commandline_opts  $@
    load_library_functions
    load_config
    init_sudo
    verify_image
    exit $gpg2_rc
}


get_commandline_opts() {
    verbose='True'
    while getopts ":hin:prRvV" opt; do   # same args as run.sh - ignore unused ones
      case $opt in
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" 1>&2; exit 1
           fi
           config_nr=$OPTARG;;
        v) verbose='True';;
        V) verbose='False';;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
}


usage() {
    echo "Verify a Docker image using a trusted PGP signature
    usage: $0 [-h] [-n container-nr ] [-v] [-V]
       -h  print this help text
       -n  configuration number ('<NN>' in conf<NN>.sh)
       -v  verbose
       -V  not verbose"
}


load_library_functions() {
    DSCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $DSCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


verify_image() {
    make_tempdirs
    generate_image_digest
    compare_generated_with_local_didi  # to detect errors before the signature check
    if [[ "$digest_found" != 'True' ]]; then
        compare_generated_with_remote_didi
    fi
    verify_signature
    cleanup_tempdir
}


make_tempdirs() {
    TEMPDIR_IMAGE_DIGEST=$(mktemp -d 2>/dev/null || mktemp -d -t 'dscripts_digest')
    TEMPDIR_DIDI_REMOTE=$(mktemp -d 2>/dev/null || mktemp -d -t 'dscripts_remote')  # works for Linux + OSX
}


generate_image_digest() {
    DIDI_FILENAME=$($sudo $DSCRIPTDIR/create_didi.py $IMAGENAME $TEMPDIR_IMAGE_DIGEST)
    log "generated $TEMPDIR_IMAGE_DIGEST/$DIDI_FILENAME"
}


compare_generated_with_local_didi() {
    diff -q $PROJ_HOME/didi/$DIDI_FILENAME $TEMPDIR_IMAGE_DIGEST/$DIDI_FILENAME
    if (( $? > 0)); then
        echo "Generated and stored image digests are different."
        echo "Image verfication failed"
        digest_found='False'
    else
        digest_found='True'
        log "Generated and stored image digests are identical. ($DIDI_FILENAME)"
        DIDI_DIR=$PROJ_HOME/didi
    fi
}


compare_generated_with_remote_didi() {
    get_remote_didi
    diff -q $DIDI_FILENAME $TEMPDIR_DIDI_REMOTE/$DIDI_FILENAME
    if (( $? > 0)); then
        echo "Local ($DIDI_FILENAME) and remote ($DIDIFILE) DIDI files are different."
        echo "Image verfication failed"
        exit 1
    else
        log "Local ($DIDI_FILENAME) and remote ($DIDIFILE) DIDI files are identical."
        DIDI_DIR=$TEMPDIR_DIDI_REMOTE
    fi
}


get_remote_didi() {
    cd $TEMPDIR_DIDI_REMOTE
    get_didi_url
    DIDIFILE="${DIDIURL}/${DIDI_FILENAME}"
    [[ "$verbose" == 'True' ]] && echo "GET $DIDIFILE"
    wget -q $DIDIFILE
    (( $? > 0)) && echo "$DIDIFILE missing, image verfication failed" && exit 1
    [[ "$verbose" == 'True' ]] && echo "GET $DIDIFILE.sig"
    wget -q $DIDIFILE.sig
    (( $? > 0)) && echo "$DIDIFILE.sig missing, image verfication failed" && exit 1
    :  # remedy for strange bug where bash exited in the previous line without obvious reason
}


get_didi_url() {
    DIDIURL=$($sudo docker inspect --format='{{.Config.Labels.didi_dir}}' $IMAGENAME)
    if [[ $DIDIURL == '<no value>' ]]; then
        echo "Cannot verify signature - LABEL 'didi_dir' not set for image $IMAGENAME"
        echo "Image verfication failed"
        exit 1
    fi
}


verify_signature() {
    [[ "$verbose" == 'True' ]] || GPG_QUIET='--quiet'
    gpg2 --verify $GPG_QUIET $DIDI_DIR/$DIDI_FILENAME.sig \
        $DIDI_DIR/$DIDI_FILENAME > $DIDI_DIR/gpg2.log 2>&1
    gpg2_rc=$?
    if [[ "$verbose" == 'True' ]]; then
        cat $DIDI_DIR/gpg2.log
    fi
    if (($gpg2_rc > 0)); then
        echo "Signature of DIDI is broken. Image verfication failed."
        exit 1
    else
        log "Signature of DIDI is valid. Image verfication passed."
    fi
}


cleanup_tempdir() {
    rm -rf $TEMPDIR_DIDI_REMOTE $TEMPDIR_IMAGE_DIGEST
}


log() {
    if [[ "$verbose" == 'True' ]]; then
        echo $1
    fi
}


main $@