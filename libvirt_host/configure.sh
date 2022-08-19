#!/usr/bin/env bash
set -ex

zypper -n refresh
# TODO: Pin these versions
zypper -n install -t pattern kvm_tools kvm_server
zypper -n install bridge-utils libguestfs nginx gptfdisk e2fsprogs
systemctl enable libvirtd
systemctl start libvirtd
virt-host-validate

mkdir -p /root/.ssh
cp /home/vagrant/.ssh/authorized_keys /root/.ssh/

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
create_virt_pool "default" "/home/vagrant/pool"
create_virt_pool "vagrant_images" "/vagrant/images"

if [[ ! $(cat /etc/exports | grep guest_mount) ]]; then
    echo "/vagrant/guest_mount *(rw,sync,insecure,root_squash,no_subtree_check,fsid=25)" >> /etc/exports
fi

function enable_and_start() {
    THIS_SERVICE=$1
    systemctl enable $THIS_SERVICE
    systemctl start $THIS_SERVICE
}

mkdir -p /vagrant/guest_mount

rm -rf /srv/www/htdocs
ln -s /vagrant/htdocs /srv/www/htdocs

enable_and_start nfs-server
enable_and_start nginx
enable_and_start vboxadd-service
enable_and_start kexec-load
# TODO: set crashkernel kernel param for kdump
#enable_and_start kdump
