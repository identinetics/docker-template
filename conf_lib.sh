#!/usr/bin/env bash

# Common functions for conf.sh

# In most cases there is no need to make changes to these functions. If needed then
# overwrite them in conf.sh

map_volume() {
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


enablet_pkcs11() {
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

