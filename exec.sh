#!/usr/bin/env bash
# rhoerbe/docker-template@github 2016-07-20

EXECCMD=/bin/bash
runopt='-it'
while getopts ":hiIn:pr" opt; do
  case $opt in
    I)
      runopt=''
      ;;
    n)
      config_nr=$OPTARG
      re='^[0-9][0-9]$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument is not a number in the range frmom 02 .. 99" >&2; exit 1
      fi
      ;;
    p)
      print='True'
      ;;
    r)
      useropt='-u 0'
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1
      ;;
    *)
      echo "usage: $0 [-h] [-i] [-I] [-n <containernr>] [-p] [-r] [cmd]
   -h  print this help text
   -i  interactive (default; results in options -it for docker exec)
   -I  non-interactive (no -it for docker exec)
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker exec command on stdout
   -r  execute as root user
   cmd shell command to be executed (default is $EXECCMD)
   "
      exit 0
      ;;
  esac
done

shift $((OPTIND-1))

# determine config script (there may be more than one to run multiple containers)
# if config_nr not given and there is only one file matching conf*.sh take this one
SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)
confs=(conf*.sh)
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

if [ -z "$1" ]; then
    cmd=$EXECCMD
else
    cmd=$@
fi
docker_exec="docker exec $runopt $useropt $CONTAINERNAME $cmd"

if [ $(id -u) -ne 0 ]; then
    sudo='sudo'
fi
if [ "$print" = 'True' ]; then
    echo $docker_exec
fi
${sudo} $docker_exec