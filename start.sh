#!/bin/bash
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
set -euo pipefail

THIS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $THIS_SCRIPT_DIR/scripts/env_handler.sh
[[ $(vagrant plugin list | grep vagrant-env) ]] || vagrant plugin install vagrant-env
[[ $(vagrant plugin list | grep vagrant-libvirt) ]] || vagrant plugin install vagrant-libvirt

# Refresh ssh key in case libvirt_host has been recreated.
ssh-keygen -R $LIBVIRT_HOST_IP > /dev/null 2>&1 || true

cd $THIS_SCRIPT_DIR
[[ $(vagrant status --machine-readable | grep "state,running") ]] || vagrant up --provider=virtualbox
[[ $(vagrant snapshot list | grep base) ]] || vagrant snapshot save base
cd $OLDPWD

ssh-keyscan $LIBVIRT_HOST_IP >>~/.ssh/known_hosts 2>&1

echo "SUCCESS: Libvirthost VM provisioned successfully."
