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

# pull resources required for docker build
# ----------------------------------------

# get git repo yz/project1
#repodir='install/opt/project1'
#repourl='https://github.com/xyz/project1'
#get_or_update_repo

# get some other resource
#[ -e $workdir/install/scripts/get-pip.py ] || \
#    cd $workdir/install/scripts && wget https://bootstrap.pypa.io/get-pip.py
