#!/usr/bin/env bash

# data shared between containers goes via these definitions:
dockervol_root='/docker_volumes'
shareddata_root="${dockervol_root}/1shared_data"

# configure container
export IMGID='99'  # range from 2 .. 99; must be unique
export IMAGENAME="r2h2/template${IMGID}"
export CONTAINERNAME="${IMGID}template"
export CONTAINERUSER="user${IMGID}"   # group and user to run container
export CONTAINERUID="800${IMGID}"     # gid and uid for CONTAINERUSER
export BUILDARGS="
    --build-arg "USERNAME=$CONTAINERUSER" \
    --build-arg "UID=$CONTAINERUID" \
"
export ENVSETTINGS="
    -e LOGDIR=/var/log
    -e LOGLEVEL=INFO
"
export NETWORKSETTINGS="
    --net http_proxy
    --ip 10.1.1.${IMGID}mo
"
export VOLROOT="${dockervol_root}/$CONTAINERNAME"  # container volumes on docker host
export VOLMAPPING="
    -v $VOLROOT/etc/pki:/etc/pki:Z
    -v $VOLROOT/var/log:/var/log:Z
    -v $shareddata_root/www:/var/www:Z
"
export STARTCMD='/start.sh'

# first start: create user/group/host directories
if [ $(id -u) -ne 0 ]; then
    sudo="sudo"
fi
if ! id -u $CONTAINERUSER &>/dev/null; then
    $sudo groupadd -g $CONTAINERUID $CONTAINERUSER
    $sudo adduser -M -g $CONTAINERUID -u $CONTAINERUID $CONTAINERUSER
fi

# create dir with given user if not existing, relative to $HOSTVOLROOT
function chkdir {
    dir=$1
    user=$2
    $sudo mkdir -p "$VOLROOT/$dir"
    $sudo chown -R $user:$user "$VOLROOT/$dir"
}
chkdir etc/pki $CONTAINERUSER
chkdir var/log $CONTAINERUSER

mkdir -p $shareddata_root/www
chown -R $CONTAINERUSER:$CONTAINERUSER $shareddata_root/www
