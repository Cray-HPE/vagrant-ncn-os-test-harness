#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
# ssh-keygen -R 192.168.56.4
vagrant destroy -f || true
[[ $(uname) == "Darwin" && -d /Applications/VNC\ Viewer.app ]] && \
    nohup sleep 5 && /Applications/VNC\ Viewer.app/Contents/MacOS/vncviewer 192.168.56.4 &
vagrant up --provider=libvirt
