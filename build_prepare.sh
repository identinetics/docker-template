#!/usr/bin/env bash

# optional script to initialize and update the docker build environment

update_pkg="True"

while getopts ":hnu" opt; do
  case $opt in
    n)
      update_pkg="False"
      ;;
    u)
      update_pkg="True"
      ;;
    *)
      echo "usage: $0 [-h] [-i] [-n] [-p] [-r] [cmd]
   -h  print this help text
   -n  do not update git repos in docker build context
   -u  update git repos in docker build context (default)

   To update packages delivered a tar-balls just delete them  from install/opt
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
        echo "downloading $pkgdir into $pkgroot"
        mkdir $pkgroot/$pkgdir
        curl -L $pkgurl | tar -xz -C $pkgroot
    fi
}

repodir='install/opt/pysaml2'
repourl='https://github.com/rohe/pysaml2'
get_or_update_repo

pkgroot="$workdir/install/opt"
pkgdir="sip-4.18"
pkgurl='http://downloads.sourceforge.net/project/pyqt/sip/sip-4.18/sip-4.18.tar.gz'
get_from_tarball

