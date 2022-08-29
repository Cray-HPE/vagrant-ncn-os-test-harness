#!/usr/bin/env bash
set -e

function enable_and_start() {
    THIS_SERVICE=$1
    systemctl enable $THIS_SERVICE
    systemctl start $THIS_SERVICE
}

zypper -n refresh
zypper -n install -t pattern \
    kvm_tools=20180302-lp154.1.2 \
    kvm_server=20180302-lp154.1.2
zypper -n install \
    bridge-utils=1.6-1.33 \
    vagrant=2.2.18-bp154.2.55 \
    vagrant-libvirt=0.7.0-bp154.1.101 \
    libguestfs=1.44.2-150400.3.3.1 \
    nginx gptfdisk e2fsprogs hostname tmux vim htop wget
vagrant plugin install vagrant-env

enable_and_start libvirtd
virt-host-validate

mkdir -p /root/.ssh
cp /home/vagrant/.ssh/authorized_keys /root/.ssh/
cp /vagrant/.vagrant/machines/default/virtualbox/private_key /root/.ssh/
cp /vagrant/.vagrant/machines/default/virtualbox/private_key /home/vagrant/.ssh/

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
    echo "/vagrant *(rw,sync,insecure,root_squash,no_subtree_check,fsid=25)" >> /etc/exports
fi

mkdir -p /vagrant/guest_mount

rm -rf /srv/www/htdocs
ln -s /vagrant/htdocs /srv/www/htdocs

enable_and_start nfs-server
enable_and_start nginx
enable_and_start vboxadd-service
enable_and_start kexec-load
# TODO: set crashkernel kernel param for kdump
#enable_and_start kdump

# Add sp3 repo for access to artifacts for k8s_ncn.
[[ $(zypper repos | grep repo-sle-update-sp3) ]] || \
    zypper -n ar http://download.opensuse.org/update/leap/15.3/sle/ repo-sle-update-sp3
zypper refresh repo-sle-update-sp3

# TODO: Add fstab entry for nfs mount to persist after a non-Vagrant restart.

echo "SUCCESS: libvirt_host was successfully provisioned."
