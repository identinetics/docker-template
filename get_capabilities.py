#!/usr/bin/env python

import json
import sys

with open(sys.stdin) as fd:
    metadata = json.loads(fd.read())
    print(metadata[0]['ContainerConfig']['Labels']['capabilites'])