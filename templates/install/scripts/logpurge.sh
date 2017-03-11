#!/usr/bin/env bash

# purge log files in this container older than x days

main() {
    get_commandline_opts
    purge $LOGPURGEFILES
}

get_commandline_opts() {
    days=7
    while getopts ":hd:p" opt; do
      case $opt in
        d) re='^[0-9]{1,3}$'
           if ! [[ $OPTARG =~ $re ]] ; then
             echo "error: -d argument is not a number in the range frmom 0 .. 999" >&2; exit 1
           fi
           days=$OPTARG;;
        p) print="True";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) echo "usage: $0 [-h] [-d <days>] [-p]
           purge log files produced
           -h  print this help text
           -d  <number of days to keep log files>  (default: 7 days)
           -v  verbose
           "; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}

function purge {
    FILES_TO_BE_PURGED=$1
    exec="find ${FILES_TO_BE_PURGED} -mtime +${days} -type f -delete"
    if [ "${print}" = "True" ]; then
        echo ${exec}
    fi
    $exec
}


main