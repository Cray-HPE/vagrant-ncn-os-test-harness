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
set -euo pipefail

echo >&2 'At this time, libvirt does not work natively on macOS!'
echo >&2 'This script is provided for experimental purposes.'

REINSTALL=0
VERB=Installing
ACTION=install

if [ "${1-:''}" = '--reinstall' ]; then
    REINSTALL=1
    VERB=Reinstalling
    ACTION=reinstall
    echo >&2 'This script may or may not prompt for an administrative password during the brew commands.'
fi

kernel="$(uname -s)"
arch="$(uname -m)"
libvirt_socket="/System/Volumes/Data/Users/$(whoami)/.cache/libvirt/libvirt-sock"
qemu_socket="/usr/local/var/run/libvirt/virtqemud-sock-ro"

if [[ ! "$kernel" = 'Darwin' ]]; then
    echo >&2 "FATAL: This script is designed for macOS [Darwin] but [$kernel] was detected."
    exit 1
else
    if [[ "$arch" = 'arm64' ]]; then
        echo >&2 "FATAL: This script is not designed for M1 Apple computer (arm64)"
        exit 1
    elif [[ "$arch" != 'x86_64' ]]; then
        echo >&2 "FATAL: This script is designed for [x86_64] but found [$arch]"
        exit 1
    fi
fi
if [ $(id -u) -eq 0 ]; then
    echo >&2 "DO NOT RUN THIS SCRIPT AS ROOT"
    exit 2
fi
if ! command -v brew >/dev/null 2>&1 ; then
    echo >&2 'FATAL: brew not detected, please ensure brew is installed.'
    exit 1
fi

libvirt_deps=(gcc libiconv libvirt)
echo "$VERB vagrant ... "
brew $ACTION --cask vagrant
echo "$VERB qemu ... "
brew $ACTION qemu
echo "$VERB ${libvirt_deps[@]} ... "
brew $ACTION "${libvirt_deps[@]}"
echo "Using the brew install libiconv for installing vagrant-libvirt."
export LDFLAGS="-L/usr/local/opt/libiconv/lib"
export CPPFLAGS="-I/usr/local/opt/libiconv/include"
if [ $REINSTALL -eq 1 ]; then
    vagrant plugin repair
fi
if ! vagrant plugin list | grep -q vagrant-libvirt; then
    vagrant plugin install vagrant-libvirt
else
    vagrant plugin update vagrant-libvirt
fi

printf "Checking for presence of user socket [$libvirt_socket] ... "
if [ ! -S $libvirt_socket ]; then
    echo 'FAILED!'
    printf >&2 "Could not find socket [$libvirt_socket], attempting a restart of libvirt ... "
    brew services restart libvirt
    sleep 5
    echo 'DONE'
    printf "Rechecking for [$libvirt_socket] ... "
    if [ ! -S $socket ]; then
        echo >&2 "FAILED!"
        echo >&2 'Try restarting your computer.'
    else
        echo 'SUCCESS'
    fi
else
    echo 'SUCCESS'
fi

printf "Checking for presence of qemu socket [$qemu_socket] ... "
if [ ! -S $qemu_socket ]; then
    echo 'FAILED!'
    exit 1
fi

cat << EOF
To use qemu on macOS in vagrant, you will need to connect to qemu:///session instead of (default) qemu:///system.

You can do this via the Vagrantfile by adding:

Vagrant.configure("2") do |config|
  config.vm.provider 'libvirt' do |domain|
    domain.uri = 'qemu:///session'
  end
end

Otherwise, if you export the env var "LIBVIRT_DEFAULT_URI='qemu:///session'" the same thing will be accomplished.

You can set this permenantly by adding it to your .zshrc or .bashrc.
EOF

cat << EOF
On macOS, qemu works only via the monolithic daemon. The modular daemon does not work.
Therefore, libvirt must be stopped & disabled in the user space and started via `sudo`.
You will be prompted for your sudo password in less than 3 seconds ...
EOF
echo 'Starting libvirt monolithic daemon ... '
brew services stop libvirt
sudo brew services start libvirt
echo >&2 'You will always have to run `sudo brew services start libvirt` when you restart your computer.'
echo "$0 is done."
