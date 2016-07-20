#!/usr/bin/env bash
# rhoerbe/docker-template@github 2016-07-20
set -e

while getopts ":hn:pru" opt; do
  case $opt in
    n)
      config_nr=$OPTARG
      re='^[0-9][0-9]$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument is not a number in the range from 02 .. 99" >&2; exit 1
      fi
      config_opt="-n ${config_nr}"
      ;;
    p)
      print="True"
      ;;
    r)
      remove_img="True"
      ;;
    u)
      update_pkg="-u"
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1
      ;;
    *)
      echo "usage: $0 [-h] [-n container-nr] [-p] [-r] [-u]
   -h  print this help text
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker build command on stdout
   -r  remove existing image (-f)
   -u  update packages in docker build context
   unknow option $opt
   "
      exit 0
      ;;
  esac
done

shift $((OPTIND-1))

# determine config script (there may be more than one to run multiple containers)
# if config_nr not given and there is only one file matching conf*.sh take this one
SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
confs=arr=(conf*.sh)
if [ ! -z ${config_nr} ]; then
    conf_script=conf${config_nr}.sh
    if [ -e "$SCRIPTDIR/$conf_script" ]; then
        echo "$SCRIPTDIR/$conf_script not found"
        exit 1
    fi
elif [ ${#arr[@]} -eq 1 ]; then
    conf_script=${arr[0]}
else
    echo 'More than one conf*.sh: need to provide -n argument'
fi
source $SCRIPTDIR/$conf_script.sh

[ -e build_prepare.sh ] && ./build_prepare.sh $config_opt $update_pkg

if [ $(id -u) -ne 0 ]; then
    sudo="sudo"
fi

docker_build="docker build $BUILDARGS -t=$IMAGENAME ."
if [ "$print" = "True" ]; then
    echo $docker_build
fi

if [ "remove_img" = "True" ]; then
    ${sudo} docker rmi -f $IMAGENAME 2> /dev/null || true
fi

${sudo} $docker_build

echo "image: $IMAGENAME"
