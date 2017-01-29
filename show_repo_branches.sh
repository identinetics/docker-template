#!/bin/bash

# Show branches of al git repos in path, including a VERSION (if exists inrepo root) and commit status

SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
source $SCRIPTDIR/conf_lib.sh  # load library functions
show_git_branches