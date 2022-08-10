#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh
cd $SCRIPT_DIR
# ssh-keygen -R 192.168.56.4
if [[ -z "${VAGRANT_NCN_USER}" || -z "${VAGRANT_NCN_PASSWORD}" ]]; then
    echo "Missing authentication information for ssh. Please set VAGRANT_NCN_USER and VAGRANT_NCN_PASSWORD environment variables."
    exit 1
fi
vagrant destroy -f || true
[[ $(uname) == "Darwin" && -d /Applications/VNC\ Viewer.app ]] && \
    nohup sleep 5 && /Applications/VNC\ Viewer.app/Contents/MacOS/vncviewer 192.168.56.4 &

vagrant up --provider=libvirt
