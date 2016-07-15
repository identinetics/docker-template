#!/usr/bin/env bash
# rhoerbe/docker-template@github 2016-07-15
set -x

# Initialize and update the docker build environment
# Providing resources before starting docker build provides better control about updates
# and can speed up the build process.

update_pkg="False"

while getopts ":hnuU" opt; do
  case $opt in
    n)
      config_nr=$OPTARG
      re='^[0-9][0-9]?$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument is not a number in the range from 2 .. 99" >&2; exit 1
      fi
      ;;
    u)
      update_pkg="True"
      ;;
    U)
      update_pkg="False"
      ;;
    *)
      echo "usage: $0 [-n] [-u]
   -U  do not update git repos in docker build context (default)
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
        if [ "$update_pkg" == "True" ]; then
            echo "updating $repodir"
            cd $repodir && git pull && cd $OLDPWD
        fi
    else
        echo "cloning $repodir" \
        mkdir -p $repodir
        git clone $repourl $repodir
    fi
}

get_from_tarball() {
    if [ ! -e $pkgroot/$pkgdir ]; then \
        if [ "$update_pkg" == "True" ]; then
            echo "downloading $pkgdir into $pkgroot"
            mkdir $pkgroot/$pkgdir
            curl -L $pkgurl | tar -xz -C $pkgroot
        fi
    fi
}

get_from_ziparchive() {
    if [ ! -e $pkgroot/$pkgdir ]; then
        if [ "$update_pkg" == "True" ]; then
            echo "downloading $pkgdir into $pkgroot"
            mkdir $pkgroot/$pkgdir
            wget -qO- -O tmp.zip $pkgurl && unzip tmp.zip && rm tmp.zip
        fi
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

