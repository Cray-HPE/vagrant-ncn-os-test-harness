#!/bin/bash
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

SCRIPT_DIR=/vagrant
source /etc/environment
# source /etc/cray/vagrant_image.bom
CSM_RELEASE_BRANCH="${CSM_RELEASE_BRANCH:=main}"


function download_file() {
    PATH_LOCAL_FILE=$1
    DOWNLOAD_URL=$2
    echo "Downloading file from $DOWNLOAD_URL"
    sudo curl -L $DOWNLOAD_URL --output $PATH_LOCAL_FILE
}

function fetch_zypper_repos() {
    mkdir -p $SCRIPT_DIR/repos
    REPO_MANIFESTS=(
        conntrack.spec
        cray.repos
        google.template.repos
        hpe.template.repos
        suse.template.repos
    )
    for REPO_MANIFEST in ${REPO_MANIFESTS[*]}; do
        download_file $SCRIPT_DIR/repos/$REPO_MANIFEST "https://raw.githubusercontent.com/Cray-HPE/csm-rpms/${CSM_RELEASE_BRANCH}/repos/${REPO_MANIFEST}"
    done
    # Also fetch the script used to populate them.
    download_file $SCRIPT_DIR/repos/rpm-functions.sh "https://raw.githubusercontent.com/Cray-HPE/csm-rpms/${CSM_RELEASE_BRANCH}/scripts/rpm-functions.sh"
    sudo chmod +x $SCRIPT_DIR/repos/rpm-functions.sh
    # Silence the echo of credential.
    sudo sed -i 's/echo "Adding repo ${alias} at ${url}"/# echo "Adding repo ${alias} at ${url}"/g' $SCRIPT_DIR/repos/rpm-functions.sh
}
fetch_zypper_repos

cd /vagrant/repos
source ./rpm-functions.sh
sudo add-cray-repos
sudo add-google-repos
sudo add-hpe-repos
sudo add-suse-repos
sudo add-fake-conntrack
sudo zypper lr -e /tmp/repos.repos
cat /tmp/repos.repos
cd $OLDPWD
