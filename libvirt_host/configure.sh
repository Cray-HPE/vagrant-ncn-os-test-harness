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

virsh net-start default
virsh net-autostart default

virsh pool-define-as vagrant_images dir - - - - "/vagrant/images"
virsh pool-start vagrant_images
virsh pool-autostart vagrant_images

echo "/vagrant/guest_mount *(rw,sync,insecure,root_squash,no_subtree_check,fsid=25)" >> /etc/exports
systemctl enable nfs-server
systemctl start nfs-server

systemctl enable nginx
systemctl start nginx

rm -rf /srv/www/htdocs
ln -s /vagrant/htdocs /srv/www/htdocs
