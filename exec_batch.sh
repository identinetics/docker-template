#!/usr/bin/env bash

while getopts ":hin:p" opt; do
  case $opt in
    i)
      runopt='-it --rm'
      ;;
    n)
      re='^[0-9][0-9]?$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument ($OPTARG) is not a number in the range frmom 2 .. 99" >&2; exit 1
      fi
      config_nr=$OPTARG
      ;;
    p)
      print="True"
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1
      ;;
    *)
      echo "usage: $0 [-h] [-i] [-p] [-r] [cmd]
   -h  print this help text
   -i  interactive mode
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker run command on stdout
   -r  start command as root user (default is $CONTAINERUSER)
   cmd shell command to be executed (default is $STARTCMD)"
      exit 0
      ;;
  esac
done
shift $((OPTIND-1))

# get config
SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
source $SCRIPTDIR/conf${config_nr}.sh

if [ $(id -u) -ne 0 ]; then
    sudo="sudo"
fi
${sudo} docker exec $runopt $CONTAINERNAME /start_pyff_batch.sh