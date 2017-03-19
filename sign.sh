#!/usr/bin/env bash

main() {
    load_library_functions
    load_config
    init_sudo
    cd $PROJ_HOME
    generate_didi
    sign_didi
    cd $OLDPWD
}


load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


generate_didi() {
    DIDI_FILENAME=$($sudo dscripts/create_didi.py $IMAGENAME)
}



sign_didi() {
    gpg2 --detach-sig $GPG_SIGN_OPTIONS --local-user $DIDI_SIGNER --output "didi/${DIDI_FILENAME}.sig" "didi/${DIDI_FILENAME}"
    echo "publish the didi file signature, e.g.:"
    echo "git add didi/${DIDI_FILENAME}* && git commit -m 'add' && git push"
}


main $@