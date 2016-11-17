#!/usr/bin/env bash

# create config files if missing
# sshd key files need to be in external storage to reuse exising key material if container is destroyed and re-created

if [ ! -e /opt/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config /opt/ssh/sshd_config
    echo 'GSSAPIAuthentication no' >> /opt/ssh/sshd_config
    echo 'useDNS no' >> /opt/ssh/sshd_config
fi
[ -e /opt/ssh/ssh_host_rsa_key ] || ssh-keygen -q -N '' -t rsa -f /opt/ssh/ssh_host_rsa_key
[ -e /opt/ssh/ssh_host_ecdsa_key ] || ssh-keygen -q -N '' -t ecdsa -f /opt/ssh/ssh_host_ecdsa_key
[ -e /opt/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -N '' -t ed25519 -f /opt/ssh/ssh_host_ed25519_key



echo 'starting sshd in foreground'
/usr/sbin/sshd -f /opt/ssh/sshd_config \
   -p 2022 \
   -h /opt/ssh/ssh_host_rsa_key \
   -h /opt/ssh/ssh_host_ecdsa_key \
   -h /opt/ssh/ssh_host_ed25519_key

echo 'ready to login, like:'
echo 'ssh -o "StrictHostKeyChecking no" -i ~/.ssh/id_ed25519_loopback -p 2022 user13@localhost'

echo 'exiting this shell will terminate the container'
bash