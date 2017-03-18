#!/usr/bin/env python

# Create a Docker Image Digest Indicator ('DIDI') from the output of `docker inspect'
# Intended usage:
#     filename = $(create_didi.py <image id|name>)

import json
import re
import subprocess
import sys

def main():
    metadata = load_image_metadata()
    write_signature_claim(metadata)


def load_image_metadata():
    img_metadata = subprocess.check_output(['docker', 'inspect', sys.argv[1]])
    return json.loads(img_metadata)


def write_signature_claim(metadata):
    try:
        repo_tags = metadata[0]['RepoTags']
        repo_digests = metadata[0]['RepoDigests']
    except (KeyError, IndexError):
        pass
    didi =  {
        "FormatVersion": 1,
        "RepoTags": repo_tags,
        "RepoDigests": repo_digests,
    }
    if len(repo_digests) > 1:
        raise Exception('Cannot handle more than on image digest')
    regex_result = re.search('sha256:(.+)$', repo_digests[0])
    digest_short = regex_result.group(1)[0:16]
    didi_filename = digest_short + '.json'

    with open(didi_filename, 'w') as fd:
        fd.write(json.dumps(didi, indent=4))
    print(didi_filename)


main()