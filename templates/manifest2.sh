#!/bin/bash

# This script must be copied in the docker image to /opt/bin/manifest2.sh (-> Dockerfile)

main() {
    _get_system_python_packages                 #  requires pip
    #_get_venv_python_packages venv_path#       #  requires pip
    _get_file_checksum /opt/bin/start.sh       #  requres sha256sum
    _get_file_checksum /opt/bin/start.sh       #  requres sha256sum
}


_get_system_python_packages() {
    pip freeze | sed -e 's/^/PYTHON::/'
}


_get_system_python_packages() {
    venv_path=$1
    source $venv_path/bin/activate
    venv=basename $venv_path
    pip freeze | sed -e "s/^/PYTHON\[${xxx}\]::/"
}


_get_file_checksum() {
    filepath=$1
    sha256sum $filepath | awk '{print "FILE::" $2 "==#" substr($1,1,7)}'
}


main