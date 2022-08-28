#!/usr/bin/env bash
if [[ $(virsh snapshot-list --domain csm-default | grep $1) ]]; then
    virsh shutdown --domain csm-default
    # TODO: Probably need logic to wait for shutdown
    virsh snapshot-revert --domain csm-default --snapshotname $1 --running
else
    echo "Snapshot $1 does not exist. "
    exit 1
fi
