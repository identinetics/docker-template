#!/usr/bin/env bash
# rhoerbe/docker-template@github 2016-07-11

EXECCMD=/bin/bash
while getopts ":hin:pr" opt; do
  case $opt in
    i)
      runopt='-it'
      ;;
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
      useropt='-u 0'
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1
      ;;
    *)
      echo "usage: $0 [-h] [-i] [-n] [-p] [-r] [cmd]
   -h  print this help text
   -i  interactive (results in options -i -t for docker exec)
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker exec command on stdout
   -r  execute as root user
   cmd shell command to be executed (default is $EXECCMD)
   unknow option $opt
   "
      exit 0
      ;;
  esac
done

shift $((OPTIND-1))

SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
source $SCRIPTDIR/conf${config_nr}.sh

if [ -z "$1" ]; then
    cmd=$EXECCMD
else
    cmd=$@
fi
docker_exec="docker exec $runopt $useropt $CONTAINERNAME $cmd"

if [ $(id -u) -ne 0 ]; then
    sudo="sudo"
fi
if [ "$print" = "True" ]; then
    echo $docker_exec
fi
${sudo} $docker_exec
