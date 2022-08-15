#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh

# Refresh ssh key in case libvirt_host has been recreated.
ssh-keygen -R 192.168.56.4 > /dev/null 2>&1 || true

cd $SCRIPT_DIR
vagrant up --provider=virtualbox
cd $OLDPWD

ssh-keyscan 192.168.56.4 >>~/.ssh/known_hosts 2>&1
