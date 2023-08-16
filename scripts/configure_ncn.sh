#!/bin/bash
#
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
set -ex

function enable_and_start() {
    THIS_SERVICE=$1
    systemctl enable $THIS_SERVICE
    systemctl start $THIS_SERVICE
}

zypper -n ar https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Backports/SLE-15-SP3_x86_64/standard?auth=basic SUSE-Backports-SLE-15-SP3-x86_64
zypper -n ar https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Products/SLE-Module-Server-Applications/15-SP3/x86_64/product?auth=basic SUSE-SLE-Module-Server-Applications-15-SP3-x86_64-Pool
zypper -n ar https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Server-Applications/15-SP3/x86_64/update?auth=basic SUSE-SLE-Module-Server-Applications-15-SP3-x86_64-Updates
zypper -n ar https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Products/SLE-Module-Basesystem/15-SP3/x86_64/product?auth=basic SUSE-SLE-Module-Basesystem-15-SP3-x86_64-Pool
zypper -n ar https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/15-SP3/x86_64/update?auth=basic SUSE-SLE-Module-Basesystem-15-SP3-x86_64-Updates
zypper -n --gpg-auto-import-keys refresh

echo 'Installing KVM packages ... '
zypper -n install qemu-kvm
zypper -n install -t pattern \
    kvm_tools \
    kvm_server
echo 'Installing vagrant-libvirt packages'
zypper -n install \
    vagrant-libvirt \
    gptfdisk e2fsprogs hostname

# Optional nice-to-have dev utils while we can install them
echo 'Installing dev tools ...'
zypper -n install htop tmux neovim

echo 'Installing vagrant-env'
vagrant plugin install vagrant-env

echo 'Cleaning up; removing repos ...'
zypper -n rr SUSE-Backports-SLE-15-SP3-x86_64
zypper -n rr SUSE-SLE-Module-Server-Applications-15-SP3-x86_64-Pool
zypper -n rr SUSE-SLE-Module-Server-Applications-15-SP3-x86_64-Updates
zypper -n rr SUSE-SLE-Module-Basesystem-15-SP3-x86_64-Pool
zypper -n rr SUSE-SLE-Module-Basesystem-15-SP3-x86_64-Updates

enable_and_start libvirtd
virt-host-validate

if [[ ! $(virsh net-list | grep default | grep active) ]]; then
    virsh net-start default
    virsh net-autostart default
fi

function create_virt_pool() {
    POOL_NAME=$1
    POOL_PATH=$2
    mkdir -p $POOL_PATH
    if [[ ! $(virsh pool-list | grep $POOL_NAME | grep active) ]]; then
        virsh pool-define-as $POOL_NAME dir - - - - $POOL_PATH
        virsh pool-start $POOL_NAME
        virsh pool-autostart $POOL_NAME
    fi
}

# TODO: Map the storage pool to the host NFS mount to bypass the need for a redundant box upload.
create_virt_pool "default" "$(pwd)/pool"

enable_and_start nfs-server

echo "SUCCESS: libvirt_host was successfully provisioned."
