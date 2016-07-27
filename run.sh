#!/usr/bin/env bash
# rhoerbe/docker-template@github 2016-07-20

while getopts ":hin:prR" opt; do
  case $opt in
    i)
      runopt='-it --rm'
      ;;
    n)
      re='^[0-9][0-9]$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" >&2; exit 1
      fi
      config_nr=$OPTARG
      ;;
    p)
      print="True"
      ;;
    r)
      useropt='-u 0'
      ;;
    R)
      remove='True'
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1
      ;;
    *)
      echo "usage: $0 [-h] [-i] [-n container-nr ] [-p] [-r] -[R] [cmd]
   -h  print this help text
   -i  start in interactive mode and remove container afterwards
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker run command on stdout
   -r  start command as root user (default is $CONTAINERUSER)
   -R  remove dangling container before start
   cmd shell command to be executed (default is $STARTCMD)"
      exit 0
      ;;
  esac
done
shift $((OPTIND-1))

SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
PROJ_HOME=$(cd $(dirname $SCRIPTDIR) && pwd)

cd $PROJ_HOME; confs=($PROJ_HOME/conf*.sh); cd $OLDPWD

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

if [ -z "$runopt" ]; then
    runopt='-d --restart=unless-stopped'
fi
if [ -z "$useropt" ]; then
    useropt="-u $CONTAINERUSER"
fi
if [ -z "$1" ]; then
    cmd=$STARTCMD
else
    cmd=$@
fi
docker_run="docker run $runopt $useropt --hostname=$CONTAINERNAME --name=$CONTAINERNAME
    $ENVSETTINGS $NETWORKSETTINGS $VOLMAPPING $IMAGENAME $cmd"

if [ $(id -u) -ne 0 ]; then
    sudo="sudo"
fi
$sudo docker rm -f $CONTAINERNAME 2>/dev/null || true
if [ "$print" = "True" ]; then
    echo $docker_run
fi
# remove dangling container
if [ -e $remove ]; then
    $sudo docker ps -a | grep $CONTAINERNAME > /dev/null && docker rm $CONTAINERNAME
fi

$sudo $docker_run
