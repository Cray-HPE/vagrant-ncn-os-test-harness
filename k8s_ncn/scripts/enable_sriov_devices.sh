#!/usr/bin/env bash

set -e

K8S_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/..

if [[ ! $(hostname | grep ncn-) ]]; then
  echo "This script is only meant to be run on an NCN host."
  exit 1
fi

function enable_virtual_function_for_dev(){
  DEV=$1
  setting_file=/sys/class/net/$DEV/device/sriov_numvfs
  if (( $(cat $setting_file) == 0 )); then
    echo 1 > $setting_file
  fi
}

# TODO: Persist virtual devices across reboots

function get_virtual_dev_name_for_dev(){
  DEV=$1
  VIRT_FN_NUM=${2:-0}
  VIRT_DEV_NAME=$(ls /sys/class/net/${DEV}/device/virtfn${VIRT_FN_NUM}/net/)
  echo $VIRT_DEV_NAME
}

# TODO: Check that virtual function device is available for vm passthrough

function set_virtual_dev_name_for_vm() {
  VM_DEV=$1
  HOST_DEV=$(get_virtual_dev_name_for_dev $VM_DEV)
  if [[ -z $HOST_DEV ]]; then
    echo "No virtual function devices were found for device $VM_DEV. Check that the driver supports SR-IOV and has it enabled."
    exit 1
  fi
  sed -i "s/export SRIOV_${VM_DEV}=.*/export SRIOV_${VM_DEV}=${HOST_DEV}/" $K8S_DIR/../.env
  echo "Found and set SRIOV_${VM_DEV} to ${HOST_DEV}."
}

enable_virtual_function_for_dev "mgmt0"
enable_virtual_function_for_dev "mgmt1"
set_virtual_dev_name_for_vm "mgmt0"
set_virtual_dev_name_for_vm "mgmt1"

