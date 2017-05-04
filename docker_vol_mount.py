#!/usr/bin/env python

# script to make container show volume mount path with options
#   (a) link to an admin-friedly path
#   (b) add g+w DAC privilege to root path

__author__ = 'r2h2'

import argparse
import json
import os
import stat
from subprocess import call, check_output, CalledProcessError

parser = argparse.ArgumentParser(description='Show Docker volume mount')
parser.add_argument('-g', '--groupwrite', dest='groupwrite', action="store_true",
                    help='Execute `chmod g+w` on mountpoint')
parser.add_argument('-p', '--prefix', dest='prefix', default='/dv', help='Path prefix for symlink')
parser.add_argument('-s', '--symlink', dest='symlink', action="store_true",
                    help='Create symlink at path prefix')
parser.add_argument('-t', '--selinux-type', dest='type', help='Execute `chcon -Rt <type>`')
parser.add_argument('-v', '--verbose', dest='verbose', action="store_true")
parser.add_argument('-V', '--volume', dest='volume', required=True, help='Name of Docker volume')
args = parser.parse_args()

try:
    in_str = check_output(["docker", "volume", "inspect", args.volume])
except CalledProcessError as e:
    print("cannot execute 'docker volume inspect ' + volume")
    raise

container = json.loads(in_str)
linkto_path = container[0]['Mountpoint']
if args.verbose:
    print(container[0]['Name'] + ': ' + linkto_path)

if args.groupwrite:
    st = os.stat(linkto_path)
    os.chmod(linkto_path, st.st_mode | stat.S_IWGRP)  # add g+w

if args.symlink:
    linkfrom_path = os.path.join(args.prefix, args.volume)
    try:
        os.remove(linkfrom_path)
    except OSError:
        pass
    try:
        os.symlink(linkto_path, linkfrom_path)
        if args.verbose:
            print("created symlink %s -> %s" % (linkfrom_path, linkto_path))
    except OSError as e:
        print("error when creating symlink %s -> %s: %s" % (linkfrom_path, linkto_path, str(e)))


if args.type:
    call(["chcon", "-Rt", args.type, linkto_path])
    if args.verbose:
        print("set lebel %s on %s" % (args.type, linkto_path))
