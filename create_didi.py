#!/usr/bin/env python

# Create a Docker Image Digest Indicator ('DIDI') from the output of `docker inspect'
# in the subdirectory 'didi'
#
# Intended usage:
#     filename = $(create_didi.py <image id|name>)

import json
import os
import re
import subprocess
import sys

def main():
    metadata = load_image_metadata()
    (repo_tags, repo_digests) = extract_metadata(metadata)
    didi = format_didi(repo_tags, repo_digests)
    write_json(didi, repo_digests)


def load_image_metadata():
    img_metadata = subprocess.check_output(['docker', 'inspect', sys.argv[1]])
    return json.loads(img_metadata)


def extract_metadata(metadata):
    repo_tags = metadata[0]['RepoTags']
    repo_digests = metadata[0]['RepoDigests']
    return (repo_tags, repo_digests)


def format_didi(repo_tags, repo_digests):
    if len(repo_digests) > 1:
        raise Exception('Cannot handle more than on image digest')
    if len(repo_digests) == 0:
        raise Exception('No image digest; you need to push image to a registry')
    didi =  {
        "FormatVersion": 1,
        "RepoTags": repo_tags,
        "RepoDigests": repo_digests,
    }
    return didi


def write_json(didi, repo_digests):
    regex_result = re.search('sha256:(.+)$', repo_digests[0])
    digest_short = regex_result.group(1)[0:16]
    didi_filename = digest_short + '.json'
    didi_filepath = os.path.join('didi', didi_filename)
    if not os.path.isdir('didi'):
        os.makedirs('didi')
    with open(didi_filepath, 'w') as fd:
        fd.write(json.dumps(didi, indent=4))
    print(didi_filename)


main()