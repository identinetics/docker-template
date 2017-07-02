#!/usr/bin/env python

'''
Print mount path for container volumes, and optionally:
  (a) create symlink in a shortcut directory
  (b) add g+w DAC privilege to volume path
  (c) exec chcon on volume path
'''
__author__ = 'r2h2'

import argparse
import json
import os
import stat
from subprocess import call, check_output, CalledProcessError

def main():
    get_args()
    print_volume_mount_path()
    add_group_write_DAC_privileges()
    create_shortcut_symlink()
    do_chcon()


def get_args():
    parser = argparse.ArgumentParser(description='Print Docker volume mount path')
    parser.add_argument('-g', '--groupwrite', dest='groupwrite', action="store_true",
                        help='Execute `chmod g+w` on mountpoint')
    parser.add_argument('-p', '--prefix', dest='prefix', default='/dv', help='Shortcur directory for symlink')
    parser.add_argument('-S', '--sudo', dest='sudo', action="store_true",
                        help='exec shell commands with sudo')
    parser.add_argument('-s', '--symlink', dest='symlink', action="store_true",
                        help='Create symlink at path prefix')
    parser.add_argument('-t', '--selinux-type', dest='type', help='Execute `chcon -Rt <type>`')
    parser.add_argument('-v', '--verbose', dest='verbose', action="store_true")
    parser.add_argument('-V', '--volume', dest='volume', required=True, help='Name of Docker volume')
    global args
    args = parser.parse_args()


def print_volume_mount_path():
    try:
        cmd = ["docker", "volume", "inspect", args.volume]
        if args.sudo :
            cmd.insert (0, args.sudo)
        in_str = check_output(cmd)
    except CalledProcessError as e:
        print("cannot execute 'docker volume inspect ' + volume")
        raise
    container = json.loads(in_str)
    global linkto_path
    linkto_path = container[0]['Mountpoint']
    if args.verbose:
        print(container[0]['Name'] + ': ' + linkto_path)


def add_group_write_DAC_privileges():
    if args.groupwrite:
        try:
            st = os.stat(linkto_path)
            os.chmod(linkto_path, st.st_mode | stat.S_IWGRP)  # add g+w
        except:
            pass


def create_shortcut_symlink():
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


def do_chcon():
    if args.type:
        cmd = ["chcon", "-Rt", args.type, linkto_path]
        if args.sudo:
            cmd.insert (0, 'sudo')
        call(cmd)
        if args.verbose:
            print("set label %s on %s" % (args.type, linkto_path))


main()