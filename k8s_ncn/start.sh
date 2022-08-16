#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh
cd $SCRIPT_DIR

# Refresh ssh key in case libvirt_host has been recreated.
ssh-keygen -R $LIBVIRT_HOST_IP > /dev/null 2>&1 || true
ssh-keyscan $LIBVIRT_HOST_IP >>~/.ssh/known_hosts 2>&1

vagrant destroy -f || true

function wait_then_vnc() {
    # TODO: Make wait_for a bigger value if the box needs to be uploaded to the libvirt_host
    wait_for=${1:-5}

    # vncviewer on Linux comes from tigervnc. Feel free to add options here.
    [[ $(which vncviewer) ]] && vnc_app=$(which vncviewer)

    # brew install vncviewer if on Mac OS.
    [[ $(uname) == "Darwin" && -d /Applications/VNC\ Viewer.app ]] && \
        vnc_app=/Applications/VNC\ Viewer.app/Contents/MacOS/vncviewer
    
    # Async run vncviewer guessing the wait_for for the vm to be booted.
    [[ !-z $vnc_app ]] && nohup sleep $wait_for && $vnc_app $LIBVIRT_HOST_IP &
}
wait_then_vnc

vagrant up --provider=libvirt
