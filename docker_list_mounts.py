#!/usr/bin/env python

__author__ = 'r2h2'

import argparse
import json
import os
import stat
from subprocess import call, check_output, CalledProcessError

def main():
    get_args()
    list_container_mounts()


def get_args():
    parser = argparse.ArgumentParser(description='List mounts of a docker container')
    parser.add_argument('-b', '--bind', action="store_true", help='list Type=bind')
    parser.add_argument('-o', '--other', action="store_true", help='list Type other than volume and bind')
    parser.add_argument('-p', '--printcontainer', action="store_true", help='print container name')
    parser.add_argument('-q', '--quiet', action="store_true", help='list only names')
    parser.add_argument('-v', '--volume', action="store_true", help='list Type=volume')
    parser.add_argument('-S', '--sudo', action="store_true",
                        help='exec shell commands with sudo')
    parser.add_argument('container', help='Continer name | id')
    global args
    args = parser.parse_args()


def list_container_mounts():
    try:
        cmd = ['docker', 'inspect', args.container]
        if args.sudo:
            cmd.insert (0, 'sudo')
        in_str = check_output(cmd)
        if args.printcontainer:
            print('Container: ' + args.container)
    except CalledProcessError as e:
        print("cannot execute 'docker inspect '" + args.container)
        raise
    in_json = json.loads(in_str)
    for mount in in_json[0]['Mounts']:
        print_mount(mount)


def print_mount(mount):
    if mount['Type'] == 'volume':
        if args.volume:
            print(mount['Name'])
            if not args.quiet:
                print('   ' + mount['Source'])
                print('   ' + mount['Destination'])
    elif mount['Type'] == 'bind':
        if args.bind:
            print(mount['Source'])
            if not args.quiet:
                print('   ' + mount['Destination'])
    else:
        print('Type: ' + mount['Type'])
        print('   ' + mount['Source'])
        print('   ' + mount['Destination'])


main()