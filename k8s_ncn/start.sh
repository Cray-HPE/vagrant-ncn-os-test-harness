#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh
cd $SCRIPT_DIR

# Refresh ssh key in case libvirt_host has been recreated.
ssh-keygen -R 192.168.56.4 > /dev/null 2>&1 || true
ssh-keyscan 192.168.56.4 >>~/.ssh/known_hosts 2>&1

vagrant destroy -f || true
[[ $(uname) == "Darwin" && -d /Applications/VNC\ Viewer.app ]] && \
    nohup sleep 5 && /Applications/VNC\ Viewer.app/Contents/MacOS/vncviewer 192.168.56.4 &

vagrant up --provider=libvirt
