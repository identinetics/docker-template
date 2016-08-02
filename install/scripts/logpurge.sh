#!/usr/bin/env bash

# purge log files in this container older than x days

days=7

while getopts ":hd:v" opt; do
  case $opt in
    d)
      re='^[0-9]{1,3}$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -d argument is not a number in the range frmom 0 .. 999" >&2; exit 1
      fi
      days=$OPTARG
      ;;
    v)
      verbose="True"
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1
      ;;
    *)
      echo "usage: $0 [-h] [-d <days>] [-p]
      purge log files produced
   -h  print this help text
   -d  <number of days to keep log files>  (default: 7 days)
   -v  verbose
   "
      exit 0
      ;;
  esac
done

shift $((OPTIND-1))

function purge {
    exec="find $1 -mtime +${days} -type f -delete"
    if [ "${verbose}" = "True" ]; then
        echo ${exec}
    fi
    $exec
}

purge /var/log/*
