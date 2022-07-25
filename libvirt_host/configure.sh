#!/usr/bin/env bash
set -ex

zypper -n refresh
zypper -n install -t pattern kvm_tools kvm_server
zypper -n install bridge-utils libguestfs
systemctl enable libvirtd
systemctl start libvirtd
virt-host-validate

mkdir -p /root/.ssh
cp /home/vagrant/.ssh/authorized_keys /root/.ssh/

virsh net-start default
virsh net-autostart default
