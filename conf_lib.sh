#!/usr/bin/env bash

# Common functions
# In most cases there is no need to replace these functions.
# However, if needed, then override them in conf.sh!

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

conflibdir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


conflib_version='2'
check_version() {
    # $1 passes conflib version supported by conf.sh
    if [[ -z $1 ]] || (( $1 < $conflib_version )); then
        echo "conf_lib.sh V${conflib_version} is not compatible - upgrade conf.sh"
    fi
}


load_config() {
    # determine config script (there may be more than one to run multiple containers)
    # if config_nr not given and there is only one file matching conf*.sh take this one
    proj_home=$(cd $(dirname $conflibdir) && pwd)
    cd $proj_home; confs=(conf*.sh); cd $OLDPWD
    if [[ ! -z ${config_nr} ]]; then
        conf_script=conf${config_nr}.sh
        if [[ ! -e "$proj_home/$conf_script" ]]; then
            echo "$proj_home/$conf_script not found"
            exit 1
        fi
    elif [[ ${#confs[@]} -eq 1 ]]; then
        conf_script=${confs[0]}
    else
        echo "No or more than one (${#confs[@]}) conf*.sh"
        printf "%s\n" "${confs[@]}"
        exit 1
    fi
    source $proj_home/$conf_script $@

    if [[ $DSCRIPTS_DOCKERFILE ]]; then
        export DSCRIPTS_DOCKERFILE_OPT="-f $DSCRIPTS_DOCKERFILE"
    else
        unset DSCRIPTS_DOCKERFILE_OPT
    fi
    if [[ "$DOCKER_REGISTRY" ]]; then
        export DOCKER_REGISTRY_PREFIX="$DOCKER_REGISTRY/"
    else
        unset DOCKER_REGISTRY_PREFIX
    fi
}


# ------------------------- functions for conf*.sh --------------------------


set_docker_registry() {
    # priority: conf.sh, then local.conf, then 'local'
    local local_user=$(grep DOCKER_REGISTRY_USER local.conf | awk '{ printf $2; }')
    if [[ ! "$DOCKER_REGISTRY_USER" ]]; then
        if [[ "$local_user" ]]; then
             export DOCKER_REGISTRY_USER=$local_user
        else
             export DOCKER_REGISTRY_USER="local"
        fi
    fi

    # priority: conf.sh, then local.conf, then '' (-> default registry)
    local local_host=$(grep DOCKER_REGISTRY_HOST local.conf | awk '{ printf $2; }')
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        if [[ "$local_host" ]]; then
             export DOCKER_REGISTRY=$local_host
        fi
    fi
}

_chkdir() {
    if [[ "${1:0:1}" == / ]]; then
        dir=$1  # absolute path
    else   # deprecated
        [[ -z $DOCKERVOL_SHORT ]] && echo 'DOCKERVOL_SHORT not defined' && exit 1
        dir=$DOCKERVOL_SHORT/$1
    fi
    if [[ ! -e "$dir" ]]; then
        echo "$0: Missing directory: $dir"
        exit 1
    fi
}


_create_chown_dir() {
    # args: path user [group]
    if [[ "${1:0:1}" == / ]]; then
        dir=$1  # absolute path
    else  # deprecated
        [[ -z $DOCKERVOL_SHORT ]] && echo 'DOCKERVOL_SHORT not defined' && exit 1
        dir=$DOCKERVOL_SHORT/$1
    fi
    user=$2
    if [[ -z $3 ]]; then
        group=$user
    else
        group=$3
    fi
    $sudo mkdir -p $dir >/dev/null 2>&1 || true
    $sudo chown -R $user:$group $dir >/dev/null 2>&1 || true
}


create_user() {
    a_username=$1; a_uid=$2
    # first start: create user/group/host directories
    if ! id -u $a_username &>/dev/null; then
        if [[ ${OSTYPE//[0-9.]/} == 'darwin' ]]; then  # OSX
                $sudo sudo dseditgroup -o create -i $a_uid $a_username >/dev/null 2>&1 || true
                $sudo dscl . create /Users/$a_username UniqueID $a_uid >/dev/null 2>&1 || true
                $sudo dscl . create /Users/$a_username PrimaryGroupID $a_uid >/dev/null 2>&1 || true
        else  # Linux
          source /etc/os-release
          case $ID in
            centos|fedora|rhel)
                $sudo groupadd --non-unique -g $a_uid $a_username >/dev/null 2>&1 || true
                $sudo adduser --non-unique -M --gid $a_uid --comment "" --uid $a_uid $a_username >/dev/null 2>&1  || true
                ;;
            debian|ubuntu)
                $sudo groupadd -g $a_uid $a_username >/dev/null 2>&1 || true
                $sudo adduser --gid $a_uid --no-create-home --disabled-password --gecos "" --uid $a_uid $a_username >/dev/null 2>&1 || true
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
    export CAPABILITIES=$($sudo docker inspect --format='{{.Config.Labels.capabilities}}' $IMAGENAME 2>/dev/null)
    if [[ $CAPABILITIES == '<no value>' ]]; then
        export CAPABILITIES=''
    fi
}


get_container_status() {
    if [[ "$($sudo docker ps -f name=$CONTAINERNAME |egrep -v ^CONTAINER)" ]]; then
        return 0   # running
    elif [[ "$($sudo docker ps -a -f name=$CONTAINERNAME|egrep -v ^CONTAINER)" ]]; then
        return 1   # stopped
    else
        return 2   # not found
    fi
}


get_metadata() {
    # Extract metadata for docker run defined with 'LABEL' in the Dockerfile
    key=$1
    value=$(docker inspect --format='{{.Config.Labels.${key}}}' $IMAGENAME)
    if [[ -z "$value" ]]; then
        echo "key $key not found in metadata of $IMAGENAME"
        exit 1
    fi
}


enable_pkcs11() {
    #enable Smartcard Reader in Docker
    # --privileged mapping of usb devices allows the generic configuration without knowing the
    # USB device name. Alternatively, devices can be mapped using '--device'
    export USBMAPPING='--privileged -v /dev/bus/usb:/dev/bus/usb'
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
    if [[ $DISPLAY ]]; then
        export ENVSETTINGS="$ENVSETTINGS -e DISPLAY=$DISPLAY    "
    else
        echo "cannot enable X11 client - DISPLAY not set"
        exit 1
    fi
    export VOLMAPPING="$VOLMAPPING -v /tmp/.X11-unix/:/tmp/.X11-unix:Z"
}


init_sudo() {
    if (( $(id -u) != 0 )); then
        sudo='sudo -n' # ONLY used for `docker ..` commands
        sudoopt='--sudo'
    fi
}


map_docker_volume() {
    # Map container directory to Docker volume
    # - Create volume if it does not exist
    # - Append to VOLMAPPING
    # - chmod g+w and create symlink in shortcut_dir
    mode=$1; vol_name=$2; containerpath=$3; mount_option=$4; shortcut_dir=$5
    if [[ $mode == 'list' ]]; then
        export VOLLIST="${VOLLIST} ${vol_name}"
        return
    fi
    if [[ ! -d "${shortcut_dir}" ]]; then
        echo "conf_lib.sh/map_docker_volume(): argument 5 must be a valid directory; args found: $@" && exit 1;
    fi
    $sudo docker volume create --name $vol_name >/dev/null
    export VOLMAPPING="$VOLMAPPING -v $vol_name:$containerpath:$mount_option"
    $sudo mkdir -p $shortcut_dir >/dev/null 2>&1 || true
    #if [[ "$TRAVIS" == "true" ]]; then
    #    chcon_opt='--selinux-type svirt_sandbox_file_t'
    #fi
    gw=
    if [[ "$CONTAINER_GROUPWRITE" != 'no' ]] ; then
        gw=--groupwrite
    fi
    if [[ $JENKINS_HOME=='' && $DOCKER_VOL_LOG_SYMLINKS_DISABLE!='' ]]; then
        fs_access="--symlink --prefix $shortcut_dir $symlink $gw"
    fi
    $conflibdir/docker_vol_mount.py $sudoopt $fs_access $chcon_opt --volume $vol_name
}


map_host_directory() {
    # map a host to a container path
    HOSTPATH=$1; containerpath=$2; mount_option=$3
    export VOLMAPPING="$VOLMAPPING -v $HOSTPATH:$containerpath:$mount_option"
    if [[ $mount_option == "ro" ]]; then
        _chkdir $HOSTPATH
    else
        _create_chown_dir $HOSTPATH $CONTAINERUID
    fi
}


# ------------------------- functions for build_prepare.sh --------------------------

get_or_update_repo() {
    if [[ ! -e $repodir ]]; then
        echo "cloning $repodir" \
        mkdir -p $repodir
        git clone $repourl $repodir
    elif [[ "$update_pkg" == "True" ]]; then
        echo "updating $repodir"
        cd $repodir && git pull && cd $OLDPWD
    fi
}


get_from_tarball() {
    if [[ ! -e $pkgroot/$pkgdir ]] || [[ "$update_pkg" == "True" ]]; then
        echo "downloading $pkgdir into $pkgroot"
        mkdir -p $pkgroot/$pkgdir && rm -rf $pkgroot/$pkgdir/*
        curl -L $pkgurl | tar -xz -C $pkgroot
    fi
}


get_from_ziparchive() {
    if [[ ! -e $pkgroot/$pkgdir ]] || [[ "$update_pkg" == "True" ]]; then
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
    # - Extract the name of the top-level directory in the archive into inst_dir
    # - Extract the archive (creating inst_dir)
    # - Link inst_dir to prod_dir
    # - create marker file
    #  prod_dir is defined in Dockerfile and should not contain a (minor) version number
    prod_url=$1; prod_sha256=$2; prod_dir=$3; prod_version=$4; wget_option=$5

    download_marker="$prod_dir-$prod_version.mark"
    if [[ ! -e "$download_marker" ]]; then
        wget $wget_option -O tmp.zip $prod_url
        echo "$prod_sha256 tmp.zip" | sha256sum -c -
        inst_dir=$(unzip -l tmp.zip | head -4 | tail -1 | awk '{print $4}' | cut -d "/" -f1)
        rm -rf $inst_dir $prod_dir
        unzip tmp.zip
        rm -f tmp.zip
        ln -sf $inst_dir $prod_dir
        touch $download_marker
    fi
}


# ---------------------------- functions for build.sh -----------------------------


do_not_build() {
    if [[ "$1" == "--build" ]]; then
         echo "Build the image locally has been disabled - get it from repo"
         exit 1
    fi
}


_echo_commit_status() {
# output ahead/behind upstream status
    branch=`git rev-parse --abbrev-ref HEAD`
    git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads | \
    while read local upstream; do
        # Use master if upstream branch is empty
        [[ -z $upstream ]] && upstream=master

        ahead=`git rev-list ${upstream}..${local} --count`
        behind=`git rev-list ${local}..${upstream} --count`

        if [[ $local == $branch ]]; then
            # Does this branch is ahead or behind upstream branch?
            if [[ $ahead -ne 0 && $behind -ne 0 ]]; then
                echo -n " ($ahead ahead and $behind behind $upstream) "
            elif [[ $ahead -ne 0 ]]; then
                echo -n " ($ahead ahead $upstream) "
            elif [[ $behind -ne 0 ]]; then
                echo -n " ($behind behind $upstream) "
            fi
            # Any locally modified files?
            count=$(git status -suno | wc -l | sed -e 's/ //g')
            (( "$count" > "0" )) && echo -n " ($count file(s) locally modified) "
        fi
    done;
}


_echo_repo_owner_name_branch() {
    git remote -v | head -1 | \
        perl -ne 'm{(git\@github.com:|https://github.com/)(\S+) }; print " - $2/"' | \
        perl -pe 's/\.git//'
    git symbolic-ref --short -q HEAD | tr -d '\n'
    printf ' '
}


_echo_last_commit() {
    git log -n1 | \
        grep -v  '^$' | \
        perl -pe '$_="#".substr($_,7,9) if /^commit/; s/^(Author:\s*|Date:\s*)/; /' | \
        tr -d '\n' | tr -s ' '
    echo
}

show_git_branches() {
# Show branches of all git repos in path
    find . -name '.git' | while read file; do
        repodir=$(dirname $file)
        cd $repodir
        _echo_repo_owner_name_branch
        [[ -e 'VERSION' ]] && echo -n '::' && cat VERSION | tr -d '\n'
        _echo_commit_status
        _echo_last_commit
        cd $OLDPWD
    done
}
