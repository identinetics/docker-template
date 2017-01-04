#!/usr/bin/env python

# script to make container volume mounts available with a user-friedly path
# output to be executed in shell

__author__ = 'r2h2'

import argparse
import json
import os.path

parser = argparse.ArgumentParser(description='Create symlinks for Docker volume mounts')
parser.add_argument('-p', '--prefix', dest='prefix', default='/dv', help='Path prefix for alias')
parser.add_argument('input', type=argparse.FileType('r'),
					help='output of `docker instpect <container>`')
args = parser.parse_args()

with (open(args.input.name)) as fd:
	in_str = fd.read()
container = json.loads(in_str)

vols = container[0]['Mounts']
for vol_mount in vols:
	container_alias = args.prefix + container[0]['Name']
	print('mkdir -p ' + container_alias + os.path.dirname(vol_mount['Destination']))
	print('ln -s ' + vol_mount['Source'] + ' ' + container_alias + vol_mount['Destination'])