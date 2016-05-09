#!/usr/bin/env bash

# optional script to initialize and update the docker build environment


cd $(cd $(dirname $BASH_SOURCE[0]) && pwd)
source conf${config_nr}.sh

get_or_update_repo() {
    if [ -e $repodir ] ; then
        cd $repodir && git pull && cd -    # already cloned
    else
        mkdir -p $repodir
        git clone $repourl $repodir        # first time
    fi
}

# add commands to pull resources required for docker build here:
