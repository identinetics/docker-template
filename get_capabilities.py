#!/usr/bin/env python

import json
import sys

metadata = json.loads(sys.stdin.read())
try:
    print(metadata[0]['ContainerConfig']['Labels']['capabilites'])
except KeyError IndexError:
    pass
