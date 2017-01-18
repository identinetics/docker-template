#!/usr/bin/env bash

# create keys if missing

[ -e /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -q -N '' -t rsa -f /etc/ssh/ssh_host_rsa_key
[ -e /etc/ssh/ssh_host_ecdsa_key ] || ssh-keygen -q -N '' -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
[ -e /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -N '' -t ed25519 -f /etc/ssh/ssh_host_ed25519_key



echo 'starting sshd in foreground'
/usr/sbin/sshd -p 2022

echo 'ready to login, like:'
echo 'ssh -o "StrictHostKeyChecking no" -i ~/.ssh/id_ed25519_loopback -p 2022 <someuser>@thishost'

echo 'exiting this shell may terminate the container'
bash