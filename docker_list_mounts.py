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
    parser.add_argument('-d', '--debug', action="store_true")
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
        exit(1)
    in_json = json.loads(in_str)
    volumes = []
    for v in in_json[0]['Config']['Volumes']:
        volumes.append(v.rstrip('/'))
    if args.debug: print('Volumes:' + ', '.join(volumes))
    for mount in in_json[0]['Mounts']:
        print_mount(mount, volumes)


def print_mount(mount, volumes):
    # docker inspect does not output all keys for each entry - need some guessing:
    if args.debug: print('Mount:' + json.dumps(mount, indent=4))
    if 'Name' in mount:
        if mount['Destination'] in volumes:
            print_volinfo(mount)
        else:
            print("== Do not know how to handle entry with Name, but no Type=volume):")
            print(json.dumps(mount, indent=4))
    elif 'Type' in mount:
        if mount['Type'] == 'volume':
            print_volinfo(mount)
        elif mount['Type'] == 'bind':
            print_bindinfo(mount)
        else:
            print('Type: ' + mount['Type'])
            print('   ' + mount['Source'])
            print('   ' + mount['Destination'])


def print_volinfo(mount):
    if args.volume:
        print(mount['Name'])
        if not args.quiet:
            print('   ' + mount['Source'])
            print('   ' + mount['Destination'])


def print_bindinfo(mount):
    if args.bind:
        print(mount['Source'])
        if not args.quiet:
            print('   ' + mount['Destination'])


main()