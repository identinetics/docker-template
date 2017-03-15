#!/usr/bin/env python

# Return value from Dockerfile LABEL

import json
import sys

def main():
    check_commandline_arg()
    load_container_metadata()
    return_value_metadata_key()


def check_commandline_arg():
    print (len(sys.argv))
    if len(sys.argv) != 2:
        raise Exception('get_metadata.py needs exactly 1 argument (key of LABEL statement)')

def load_container_metadata():
    metadata = json.loads(sys.stdin.read())

def return_value_metadata_key():
    try:
        print(metadata[0]['ContainerConfig']['Labels'][sys.argv[0]])
    except (KeyError, IndexError):
        pass

main()