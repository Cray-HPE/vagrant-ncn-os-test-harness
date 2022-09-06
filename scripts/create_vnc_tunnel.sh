#!/usr/bin/env bash

m001_host_ip=$1
ncn_host_name=$2

function run_msg(){
    cat <<-EOM
    When run, this script produces no output and occupies your terminal session. This is expected.
    You can run vnc viewer (or your vnc app of choice) and connect to localhost.
EOM
}

function help() {
    cat <<-EOH
    This helper script opens an SSH tunnel from your workstation through m001 on the CSM environment
    to the hosting NCN so that its VNC port is exposed as localhost on your workstation. This works
    because the Vagrantfile is already forwarding port 5900 (vnc) up to the NCN host.

    e.g. Your machine -> m001(ssh+vnc) -> ncn host(vnc) <- Vagrant environment (vnc)

    This script expects two arguments:
    1) The IP address of ncn-m001 in the target environment.
    2) The hostname of the hosting NCN.

    Example: scripts/create_vnc_tunnel.sh [m001 cmn IP] ncn-wXXX

$(run_msg)
EOH
}

if [[ -z $m001_host_ip || -z ncn_host_name ]]; then
    help
    exit 1
else
    run_msg
fi

ssh -N -T -l root -L5900:$ncn_host_name:5900 $m001_host_ip
