#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
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
