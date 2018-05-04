#!/bin/bash

# This script must reside in the root of the docker project (same place as conf.sh)

main() {
    _load_library_functions
    init_sudo
    _inspect_docker_build_env
    _inspect_container
}


_load_library_functions() {
    SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
    source $PROJ_HOME/dscripts/conf_lib.sh
}


_echo_repo_version() {
    git remote -v | head -1 | \
        perl -ne 'm{(git\@github.com:|https://github.com/)(\S+) }; print "REPO::$2/"' | \
        perl -pe 's/\.git//'
    git symbolic-ref --short -q HEAD | tr -d '\n'
    printf '==#'
    git rev-parse --short HEAD
}


_inspect_git_repos() {
    find . -name '.git' | while read file; do
        repodir=$(dirname $file)
        cd $repodir
        _echo_repo_version
        cd $OLDPWD
    done
}

_inspect_from_image() {
    dockerfile_path="${DOCKERFILE_DIR}${DSCRIPTS_DOCKERFILE:-Dockerfile}"
    from_image=$(egrep "^FROM" ${dockerfile_path} | awk '{ print $2}')
    image_id=$(docker image ls --filter "reference=${from_image}" -q)
    printf "FROM::${from_image}==${image_id}\n"
}


_inspect_docker_build_env() {
    _inspect_git_repos
    _inspect_from_image
}


_inspect_container() {
    cmd="$sudo docker run -i --rm -u 0 --name=${CONTAINERNAME}_manifest ${IMAGENAME} /opt/bin/manifest2.sh"
}


main