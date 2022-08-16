#!/usr/bin/env bash
set -e

THIS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $THIS_SCRIPT_DIR/../scripts/env_handler.sh

# Refresh ssh key in case libvirt_host has been recreated.
ssh-keygen -R $LIBVIRT_HOST_IP > /dev/null 2>&1 || true

cd $THIS_SCRIPT_DIR
[[ $(vagrant status --machine-readable | grep "state,running") ]] || vagrant up --provider=virtualbox
[[ $(vagrant snapshot list | grep base) ]] || vagrant snapshot save base
cd $OLDPWD

ssh-keyscan $LIBVIRT_HOST_IP >>~/.ssh/known_hosts 2>&1

echo "SUCCESS: Libvirthost VM provisioned successfully."
