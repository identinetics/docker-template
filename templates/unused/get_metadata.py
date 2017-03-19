#!/usr/bin/env python

# Return value from Dockerfile LABEL

import json
import subprocess
import sys

def main():
    check_commandline_arg()
    metadata = load_image_metadata()
    return_value_metadata_key(metadata)


def check_commandline_arg():
    if len(sys.argv) != 3:
        raise Exception('get_metadata.py needs exactly 2 argumenta (imagename, key of LABEL)')


def load_image_metadata():
    img_metadata = subprocess.check_output(['docker', 'inspect', sys.argv[1]])
    return json.loads(img_metadata)


def return_value_metadata_key(metadata):
    try:
        print(metadata[0]['ContainerConfig']['Labels'][sys.argv[2]])
    except (KeyError, IndexError):
        raise KeyError("LABEL key %s not found" % sys.argv[2])


main()