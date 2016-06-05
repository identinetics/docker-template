#!/usr/bin/env bash

while getopts ":hn:pru" opt; do
  case $opt in
    n)
      config_nr=$OPTARG
      re='^[0-9][0-9]?$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument is not a number in the range frmom 2 .. 99" >&2; exit 1
      fi
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
      echo "usage: $0 [-h] [-i] [-n] [-p] [-r] [cmd]
   -h  print this help text
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker build command on stdout
   -r  remove existing image (-f)
   -u  update packages in docker build context
   "
      exit 0
      ;;
  esac
done

shift $((OPTIND-1))

cd $(dirname $BASH_SOURCE[0])
source ./conf${config_nr}.sh

[ -e build_prepare.sh ] && ./build_prepare.sh $update_pkg

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
