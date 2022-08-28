#!/usr/bin/env bash
[[ $(virsh snapshot-list --domain csm-default | grep $1) ]] || \
    virsh snapshot-create-as --domain csm-default --name $1
