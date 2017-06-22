#!/usr/bin/env python

# Create a Docker Image Digest Indicator ('DIDI') from the output of `docker inspect'
# into output-directory
#
# Intended usage:
#     filename = $(create_didi.py <image id|name> <output-directory>)

import argparse
import json
import os
import re
import subprocess
import sys

def main():
    get_args()
    metadata = load_image_metadata()
    (repo_tags, repo_digests, created) = extract_metadata(metadata)
    didi = format_didi(repo_tags, repo_digests, created)
    write_json(didi, repo_digests)

def get_args():
    parser = argparse.ArgumentParser(description='Create docker image digest as a JSON file')
    parser.add_argument('dockerimage', help='image id or name')
    parser.add_argument('outputdir', help='output directory')
    global args
    args = parser.parse_args()
    os.makedirs(args.outputdir) if not os.path.isdir(args.outputdir) else None

def load_image_metadata():
    img_metadata = subprocess.check_output(['docker', 'inspect', args.dockerimage])
    return json.loads(img_metadata)


def extract_metadata(metadata):
    repo_tags = metadata[0]['RepoTags']
    repo_digests = metadata[0]['RepoDigests']
    created = metadata[0]['Created']
    return (repo_tags, repo_digests, created)


def format_didi(repo_tags, repo_digests, created):
    if len(repo_digests) > 1:
        raise Exception('Cannot handle more than one image digest')
    if len(repo_digests) == 0:
        raise Exception('No image digest; you need to push image to a registry')
    didi =  {
        "FormatVersion": 1,
        "Created": created,
        "RepoTags": repo_tags,
        "RepoDigests": repo_digests,
    }
    return didi


def write_json(didi, repo_digests):
    regex_result = re.search('sha256:(.+)$', repo_digests[0])
    digest_short = regex_result.group(1)[0:16]
    didi_filename = digest_short + '.json'
    didi_filepath = os.path.join(args.outputdir, didi_filename)
    os.remove(didi_filepath) if os.path.exists(didi_filepath) else None
    with open(didi_filepath, 'w') as fd:
        fd.write(json.dumps(didi, indent=4))
    print(didi_filename)


main()