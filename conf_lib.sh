#!/usr/bin/env bash

# Common functions for conf.sh

# In most cases there is no need to replace these functions. If needed then
# overwrite them in conf.sh

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

map_docker_volume() {
    # Map container directory to Docker volume
    # - Create volume if it does not exist
    # - Append to VOLMAPPING
    # - chgrp g+w and create symlink in PREFIX
    VOL_NAME=$1; CONTAINERPATH=$2; MOUNT_OPTION=$3; PREFIX=$4
    if [ -z ${PREFIX+x} ]; then
        echo "conf_lib.sh/map_docker_volume(): All 4 arguments need to be set; found: $@" && exit 1;
    fi
    $sudo docker volume create --name $VOL_NAME >/dev/null
    export VOLMAPPING="$VOLMAPPING -v $VOL_NAME:$CONTAINERPATH:$MOUNT_OPTION"
    mkdir -p $PREFIX
    $sudo $SCRIPTDIR/docker_vol_mount.py --prefix $PREFIX --symlink --groupwrite \
        --selinux-type svirt_sandbox_file_t --volume $VOL_NAME
}


map_host_directory() {
    # map a host to a container path
    HOSTPATH=$1; CONTAINERPATH=$2; MOUNT_OPTION=$3
    export VOLMAPPING="$VOLMAPPING -v $HOSTPATH:$CONTAINERPATH:$MOUNT_OPTION"
    if [[ $MOUNT_OPTION == "ro" ]]; then
        chkdir $HOSTPATH
    else
        createdir $HOSTPATH $CONTAINERUID
    fi
}


enable_x11_client() {
    # How to enable xclients in Docker containers: http://wiki.ros.org/docker/Tutorials/GUI
    export ENVSETTINGS="$ENVSETTINGS
        -e DISPLAY=$DISPLAY
    "
    export VOLMAPPING="$VOLMAPPING
        -v /tmp/.X11-unix/:/tmp/.X11-unix:Z
    "
}


enable_pkcs11() {
    #enable Smartcard Reader in Docker
    # --privileged mapping of usb devices allows a generic configreation without knowing the
    # USB device name. Alternatively, devices can be mapped using '--device'
    export VOLMAPPING="$VOLMAPPING
        --privileged -v /dev/bus/usb:/dev/bus/usb
    "
}


enable_sshd() {
    # add settings to start sshd (for remote debugging)
    export NETWORKSETTINGS="$NETWORKSETTINGS -p 2022:2022"
    export VOLMAPPING="$VOLMAPPING -v $VOLROOT/opt/ssh:/opt/ssh:Z"
    export STARTCMD='/start_sshd.sh'  # need to have this script installed in image
    export BUILDARGS="$BUILDARGS --build-arg SSHD_ROOTPW=$SSHD_ROOTPW"

}


create_user() {
    A_USERNAME=$1;A_UID=$2
    # first start: create user/group/host directories
    if ! id -u $A_USERNAME &>/dev/null; then
        if [[ ${OSTYPE//[0-9.]/} == 'darwin' ]]; then  # OSX
                $sudo sudo dseditgroup -o create -i $A_UID $A_USERNAME
                $sudo dscl . create /Users/$A_USERNAME UniqueID $A_UID
                $sudo dscl . create /Users/$A_USERNAME PrimaryGroupID $A_UID
        else  # Linux
          source /etc/os-release
          case $ID in
            centos|fedora|rhel)
                $sudo groupadd --non-unique -g $A_UID $A_USERNAME || true
                $sudo adduser --non-unique -M --gid $A_UID --comment "" --uid $A_UID $A_USERNAME
                ;;
            debian|ubuntu)
                $sudo groupadd -g $A_UID $A_USERNAME
                $sudo adduser --gid $A_UID --no-create-home --disabled-password --gecos "" --uid $A_UID $A_USERNAME
                ;;
            *)
                echo "do not know how to add user/group for OS ${OSTYPE} ${NAME}"
                ;;
          esac
        fi
    fi
}


init_sudo() {
    if [ $(id -u) -ne 0 ]; then
        sudo="sudo"
    fi
}

chkdir() {
    if [[ "${1:0:1}" == / ]]; then
        dir=$1  # absolute path
    else
        dir=$VOLROOT/$1
    fi
    if [ ! -e "$dir" ]; then
        echo "$0: Missing directory: $dir"
        exit 1
    fi
}


createdir() {
    if [[ "${1:0:1}" == / ]]; then
        dir=$1  # absolute path
    else
        dir=$VOLROOT/$1
    fi
    user=$2
    $sudo mkdir -p $dir
    $sudo chown -R $user:$user $dir
}

# --- functions for build_prepare.sh ---

get_or_update_repo() {
    if [ ! -e $repodir ]; then
        echo "cloning $repodir" \
        mkdir -p $repodir
        git clone $repourl $repodir
    elif [ "$update_pkg" == "True" ]; then
        echo "updating $repodir"
        cd $repodir && git pull && cd $OLDPWD
    fi
}

get_from_tarball() {
    if [ ! -e $pkgroot/$pkgdir ] || [ "$update_pkg" == "True" ]; then
        echo "downloading $pkgdir into $pkgroot"
        mkdir -p $pkgroot/$pkgdir && rm -rf $pkgroot/$pkgdir/*
        curl -L $pkgurl | tar -xz -C $pkgroot
    fi
}

get_from_ziparchive() {
    if [ ! -e $pkgroot/$pkgdir ] || [ "$update_pkg" == "True" ]; then
        echo "downloading $pkgdir into $pkgroot"
        mkdir -p $pkgroot && rm -rf $pkgroot/$pkgdir/*
        wget -O tmp.zip $pkgurl && unzip -d "$pkgroot" tmp.zip && rm tmp.zip
    fi
}


get_from_ziparchive_with_checksum() {
    # Download zip archive if a marker file for the version does not exist and link it to an unversioned directory
    # Steps:
    # - Download zip-file from URL (1) into tmp.zip,
    # - Verify it with SHA2-Hash (2);
    # - Extract the name of the top-level directory in the archive into INST_DIR
    # - Extract the archive (creating INST_DIR)
    # - Link INST_DIR to PROD_DIR
    # - create marker file
    #  PROD_DIR is defined in Dockerfile and should not contain a (minor) version number
    PROD_URL=$1; PROD_SHA256=$2; PROD_DIR=$3; PROD_VERSION=$4; WGET_OPTIONS=$5

    DOWNLOAD_MARKER="$PROD_DIR-$PROD_VERSION.mark"
    if [ ! -e "$DOWNLOAD_MARKER" ]; then
        wget $WGET_OPTIONS -O tmp.zip $PROD_URL
        echo "$PROD_SHA256 tmp.zip" | sha256sum -c -
        INST_DIR=$(unzip -l tmp.zip | head -4 | tail -1 | awk '{print $4}' | cut -d "/" -f1)
        rm -rf $INST_DIR $PROD_DIR
        unzip tmp.zip
        rm -f tmp.zip
        ln -sf $INST_DIR $PROD_DIR
        touch $DOWNLOAD_MARKER
    fi
}

