#!/usr/bin/env bash
set -e
K8S_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/..
SANDBOX_DIR=$K8S_DIR/sandbox
cp -R /etc/sysconfig/network $SANDBOX_DIR/
SUBNETS_FILE=$SANDBOX_DIR/networks.csv

function get_networks() {
  cray sls networks list --format json | jq -r '.[] | [.Name, .IPRanges[0]] | @csv' > $SUBNETS_FILE
}

function exit_with_message() {
  echo $1
  exit 1
}

function get_subnet_cidr_for() {
  SUBNET_NAME=$1
  SUBNET=$(cat $SUBNETS_FILE | grep "^\"${SUBNET_NAME}\"")
  echo $SUBNET | grep -Po ',"\K[^"]*'
}

function show_all_possible_ips_for() {
  SUBNET_RANGE=$(get_subnet_cidr_for $1)
  nmap -sL -n $SUBNET_RANGE | awk '/Nmap scan report/{print $NF}' | sort -r | grep -v 255
}

function find_free_ip_in() {
  for IP in $(show_all_possible_ips_for $1); do
    if [[ $(ping -c 1 $IP | grep "Host Unreachable") ]]; then
      echo $IP
      break
    fi
  done
}

function update_ip_in_ifcfg_for() {
  CFG_FILE="$SANDBOX_DIR/network/ifcfg-bond0.$(echo $1 | awk '{print tolower($0)}')0"
  if [[ ! -f $CFG_FILE ]]; then
    return
  fi 
  NEW_IP=$(find_free_ip_in $1)
  [[ -z $NEW_IP ]] && exit_with_message "Did not find a free IP address in subnet for $1"
  sed -i "s/^IPADDR=.*/IPADDR=${NEW_IP}/" $CFG_FILE
  echo "Set IPADDR to $NEW_IP in $CFG_FILE."
}

[[ ! $(hostname | grep ncn-) ]] && exit_with_message "This script only works if run on an NCN. Exiting."

get_networks

for NETWORK in $(cat $SUBNETS_FILE | grep -Po '\K[^"][A-Z_]{1,9}(?=")'); do
  update_ip_in_ifcfg_for "${NETWORK}"
done

sed -i "s/BONDING_SLAVE_0=mgmt1/BONDING_SLAVE_0=eth1/" $SANDBOX_DIR/network/ifcfg-bond0
sed -i "s/BONDING_SLAVE_1=mgmt1/BONDING_SLAVE_1=eth2/" $SANDBOX_DIR/network/ifcfg-bond0

# TODO: Set connect and set the HSN interface.
