#!/usr/bin/env bash

# optional script to initialize and update the docker build environment

update_pkg="False"

while getopts ":hnu" opt; do
  case $opt in
    n)
      update_pkg="False"
      ;;
    u)
      update_pkg="True"
      ;;
    *)
      echo "usage: $0 [-n] [-u]
   -n  do not update git repos in docker build context (default)
   -u  update git repos in docker build context

   To update packages delivered as tar-balls just delete them from install/opt
   "
      exit 0
      ;;
  esac
done

shift $((OPTIND-1))


workdir=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
cd $workdir
source ./conf${config_nr}.sh

get_or_update_repo() {
    if [ -e $repodir ] ; then
        [ "$update_pkg" ] \
            && echo "updating $repodir" \
            && cd $repodir && git pull && cd $OLDPWD
    else
        echo "cloning $repodir" \
        mkdir -p $repodir
        git clone $repourl $repodir        # first time
    fi
}

get_from_tarball() {
    if [ ! -e $pkgroot/$pkgdir ]; then \
        [ "$update_pkg" ] \
            echo "downloading $pkgdir into $pkgroot" \
            mkdir $pkgroot/$pkgdir \
            curl -L $pkgurl | tar -xz -C $pkgroot
    fi
}

# --- install software from github ---
#repodir='install/opt/xyz'
#repourl='https://github.com/abc/xyz'
#get_or_update_repo

# --- install software as tar ball ---
#pkgroot="$workdir/install/opt"
#pkgdir="pkg-123"
#pkgurl='http://downloads.sourceforge.net/project/............tar.gz'
#get_from_tarball

