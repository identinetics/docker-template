#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    patch_sshd_config
    create_sshd_keys
    start_sshd
}


get_commandline_opts() {
    daemonmode='-D'
    while getopts ":dh" opt; do
      case $opt in
        d) daemonmode='';;
        *) usage; exit 0;;
      esac
    done
}


usage() {
    echo "usage: $0 [-d] [-h]
       -d  start in background (default: foreground)
       -h  print this help text
       -H  generate HTML output from metadata
       -i  interactive mode
       -n  configuration number ('<NN>' in conf<NN>.sh) (use if there is more than one)
       -p  print docker exec command on stdout
       -s  split and sign md aggregate using pyff for signing
       -S  split and sign md aggregate using xmlsectool for signing"
}


patch_sshd_config() {
    if [ ! -e /opt/etc/ssh/sshd_config ]; then
        cp -p /etc/ssh/sshd_config /opt/etc/ssh/sshd_config
        echo 'GSSAPIAuthentication no' >> /opt/etc/ssh/sshd_config
        echo 'useDNS no' >> /opt/etc/ssh/sshd_config
        sed -i -e 's/#Port 22/Port 2022/' /opt/etc/ssh/sshd_config
        sed -i -e 's/^HostKey \/etc\/ssh\/ssh_host_/HostKey \/opt\/etc\/ssh\/ssh_host_/' /opt/etc/ssh/sshd_config
        #sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /opt/etc/ssh/sshd_config
    fi
}

create_sshd_keys() {
    [ -e /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -q -N '' -t rsa -f /etc/ssh/ssh_host_rsa_key
    [ -e /etc/ssh/ssh_host_ecdsa_key ] || ssh-keygen -q -N '' -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
    [ -e /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -N '' -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
}


start_sshd() {
    echo 'starting sshd in foreground'
    echo 'terminating this service may terminate the container'
    /usr/sbin/sshd ${daemonmode} -f /opt/etc/ssh/sshd_config
    # login like 'ssh -o "StrictHostKeyChecking no" -i ~/.ssh/id_ed25519_loopback -p 2022 <someuser>@thishost'
}


main "$@"