#!/usr/bin/env bash
set -ex

zypper -n refresh
zypper -n install -t pattern kvm_tools kvm_server
zypper -n install bridge-utils libguestfs nginx
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
    if [[ ! $(virsh pool-list | grep $POOL_NAME | grep active) ]]; then
        virsh pool-define-as $POOL_NAME dir - - - - $POOL_PATH
        virsh pool-start $POOL_NAME
        virsh pool-autostart $POOL_NAME
    fi
}

create_virt_pool "vagrant_images" "/vagrant/images"

if [[ ! $(cat /etc/exports | grep guest_mount) ]]; then
    echo "/vagrant/guest_mount *(rw,sync,insecure,root_squash,no_subtree_check,fsid=25)" >> /etc/exports
fi

mkdir -p /vagrant/guest_mount
systemctl enable nfs-server
systemctl start nfs-server

rm -rf /srv/www/htdocs
ln -s /vagrant/htdocs /srv/www/htdocs
systemctl enable nginx
systemctl start nginx

systemctl enable vboxadd-service
systemctl start vboxadd-service

vagrant snapshot save base

echo "SUCCESS: Libvirthost VM provisioned successfully."