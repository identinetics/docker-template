#!/usr/bin/env bash

# Common functions
# In most cases there is no need to replace these functions.
# However, if needed, then overwrite them in conf.sh
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

CONFLIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

load_config() {
    # determine config script (there may be more than one to run multiple containers)
    # if config_nr not given and there is only one file matching conf*.sh take this one
    PROJ_HOME=$(cd $(dirname $CONFLIBDIR) && pwd)
    cd $PROJ_HOME; confs=(conf*.sh); cd $OLDPWD
    if [ ! -z ${config_nr} ]; then
        conf_script=conf${config_nr}.sh
        if [ ! -e "$PROJ_HOME/$conf_script" ]; then
            echo "$PROJ_HOME/$conf_script not found"
            exit 1
        fi
    elif [ ${#confs[@]} -eq 1 ]; then
        conf_script=${confs[0]}
    else
        echo "No or more than one (${#confs[@]}) conf*.sh: need to provide -n argument:"
        printf "%s\n" "${confs[@]}"
        exit 1
    fi
    source $PROJ_HOME/$conf_script
}


# ------------------------- functions for conf*.sh --------------------------

chkdir() {
    if [[ "${1:0:1}" == / ]]; then
        dir=$1  # absolute path
    else   # deprecated
        [ -z $VOLROOT ] && echo 'VOLROOT not defined' && exit 1
        dir=$VOLROOT/$1
    fi
    if [ ! -e "$dir" ]; then
        echo "$0: Missing directory: $dir"
        exit 1
    fi
}


create_chown_dir() {
    # args: path user [group]
    if [[ "${1:0:1}" == / ]]; then
        dir=$1  # absolute path
    else  # deprecated
        [ -z $VOLROOT ] && echo 'VOLROOT not defined' && exit 1
        dir=$VOLROOT/$1
    fi
    user=$2
    if [ -z $3 ]; then
        group=$user
    else
        group=$3
    fi
    $sudo mkdir -p $dir
    $sudo chown -R $user:$group $dir
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


get_capabilities() {
    # Extract capabilites for docker run defined with the label "capabilites" in the Dockerfile
    export CAPABILITIES=$(docker inspect --format='{{.Config.Labels.capabilities}}' $IMAGENAME)
    if [[ $CAPABILITIES == '<no value>' ]]; then
        export CAPABILITIES=''
    fi
}


get_metadata() {
    # Extract metadata for docker run defined with 'LABEL' in the Dockerfile
    key=$1
    value=$(docker inspect --format='{{.Config.Labels.${key}}}' $IMAGENAME)
    if [ -z "$value" ]; then
        echo "key $key not found in metadata of $IMAGENAME"
        exit 1
    fi
}


enable_pkcs11() {
    #enable Smartcard Reader in Docker
    # --privileged mapping of usb devices allows the generic configuration without knowing the
    # USB device name. Alternatively, devices can be mapped using '--device'
    export ENVSETTINGS="$ENVSETTINGS --privileged -v /dev/bus/usb:/dev/bus/usb"
}


enable_sshd() {
    # add settings to start sshd (for remote debugging)
    export NETWORKSETTINGS="$NETWORKSETTINGS -p 2022:2022"
    export STARTCMD='/start_sshd.sh'  # need to have this script installed in image
    export START_AS_ROOT='True'
    export BUILDARGS="$BUILDARGS --build-arg SSHD_ROOTPW=$SSHD_ROOTPW"
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


init_sudo() {
    if [ $(id -u) -ne 0 ]; then
        sudo="sudo"
    fi
}


map_docker_volume() {
    # Map container directory to Docker volume
    # - Create volume if it does not exist
    # - Append to VOLMAPPING
    # - chmod g+w and create symlink in PREFIX
    VOL_NAME=$1; CONTAINERPATH=$2; MOUNT_OPTION=$3; PREFIX=$4
    if [ -z ${PREFIX+x} ]; then
        echo "conf_lib.sh/map_docker_volume(): All 4 arguments need to be set; found: $@" && exit 1;
    fi
    $sudo docker volume create --name $VOL_NAME >/dev/null
    export VOLMAPPING="$VOLMAPPING -v $VOL_NAME:$CONTAINERPATH:$MOUNT_OPTION"
    export VOLLIST="$VOLLIST $VOL_NAME"
    mkdir -p $PREFIX
    if [[ "$TRAVIS" == "true" ]]; then
        chcon_opt='--selinux-type svirt_sandbox_file_t'
    fi
    if [[ ! $JENKINS_HOME ]]; then
        fs_access="--symlink --prefix $PREFIX $symlink --groupwrite"
    fi
    $sudo $CONFLIBDIR/docker_vol_mount.py $fs_access $chcon_opt --volume $VOL_NAME
}


map_host_directory() {
    # map a host to a container path
    HOSTPATH=$1; CONTAINERPATH=$2; MOUNT_OPTION=$3
    export VOLMAPPING="$VOLMAPPING -v $HOSTPATH:$CONTAINERPATH:$MOUNT_OPTION"
    if [[ $MOUNT_OPTION == "ro" ]]; then
        chkdir $HOSTPATH
    else
        create_chown_dir $HOSTPATH $CONTAINERUID
    fi
}


set_staging_env() {
    # get current git branch and export STAGING_ENV to following values:
    #  master -> '-pr'
    #  qa -> '-qa'
    #  dev -> '-dev'
    #  any other -> ''
    if [ "$TRAVIS" == "true" ]; then
        GIT_BRANCH=$TRAVIS_BRANCH
    else
        GIT_BRANCH=$(git symbolic-ref --short -q HEAD)
    fi
    export STAGING_ENV=''
    if [ "$GIT_BRANCH" == "master" ]; then
        export STAGING_ENV='pr'
    elif [ "$GIT_BRANCH" == "qa" ]; then
        export STAGING_ENV='qa'
    elif [ "$GIT_BRANCH" == "dev" ]; then
        export STAGING_ENV='dev'
    fi
}


# ------------------------- functions for build_prepare.sh --------------------------

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


# ---------------------------- functions for build.sh -----------------------------


do_not_build() {
    if [ "$1" == "--build" ]; then
         echo "Do not build this image locally - get it from repo"
         exit 1
    fi
}


echo_commit_status() {
# output ahead/behind upstream status
    branch=`git rev-parse --abbrev-ref HEAD`
    git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads | \
    while read local upstream; do
        # Use master if upstream branch is empty
        [ -z $upstream ] && upstream=master

        ahead=`git rev-list ${upstream}..${local} --count`
        behind=`git rev-list ${local}..${upstream} --count`

        if [[ $local == $branch ]]; then
            # Does this branch is ahead or behind upstream branch?
            if [[ $ahead -ne 0 && $behind -ne 0 ]]; then
                echo -n " ($ahead ahead and $behind behind $upstream)"
            elif [[ $ahead -ne 0 ]]; then
                echo -n " ($ahead ahead $upstream)"
            elif [[ $behind -ne 0 ]]; then
                echo -n " ($behind behind $upstream)"
            fi
            # Any locally modified files?
            count=$(git status -suno | wc -l | sed -e 's/ //g')
            (( "$count" > "0" )) && echo -n " ($count file(s) locally modified)"
        fi
    done;
}


show_git_branches() {
# Show branches of all git repos in path
    find . -name '.git' | while read file; do
        repodir=$(dirname $file)
        echo -n $repodir | sed -e 's/^\.\///' | tr -d '\n'
        echo -n '::'
        cd $repodir
        git symbolic-ref --short -q HEAD | tr -d '\n'
        [ -e 'VERSION' ] && echo -n '::' && cat VERSION | tr -d '\n'
        echo_commit_status
        echo
        cd $OLDPWD
    done
}

