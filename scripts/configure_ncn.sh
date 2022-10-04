#!/usr/bin/env bash

set -ex

function enable_and_start() {
    THIS_SERVICE=$1
    systemctl enable $THIS_SERVICE
    systemctl start $THIS_SERVICE
}

zypper -n ar --no-gpgcheck https://download.opensuse.org/distribution/leap/15.3/repo/oss opensuse-oss
zypper addrepo https://download.opensuse.org/repositories/Virtualization:vagrant:Leap:15.3/openSUSE_Leap_15.3/Virtualization:vagrant:Leap:15.3.repo

zypper -n refresh
zypper -n install qemu-kvm
zypper -n install -t pattern \
    kvm_tools \
    kvm_server
zypper -n install \
    vagrant-libvirt \
    libguestfs \
    gptfdisk e2fsprogs hostname

# Optional nice-to-have dev utils while we can install them
zypper -n install htop tmux neovim

vagrant plugin install vagrant-env
zypper -n rr opensuse-oss
zypper -n rr Virtualization_vagrant_Leap_15.3

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
