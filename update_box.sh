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

set -ex
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
for LIB in $SCRIPT_DIR/scripts/lib/*; do source $LIB; done
source $SCRIPT_DIR/scripts/env_handler.sh
cd $SCRIPT_DIR
export STAGE_DIR=$SCRIPT_DIR/images
export BOOT_DIR=$SCRIPT_DIR/boot
export IMAGE_NAME=box.img
export BOX_NAME=k8s_ncn

function help() {
    cat <<EOH | sed -e 's/^    //';
    Summary:
    The $0 script determines the latest version of the kubernetes image for a given CSM tag.
    It then downloads it from Artifactory and builds a Vagrant box. Lastly, it deletes your k8s_ncn vm
    and associated volume so that your next boot uses the new image.

    Requirements:
    - This script expects to be run from within the libvirthost vm.
    - $(display_disk_capacity)

    Four environment variables are expected for credentialing. These will be asked for if not found in your .env.
    - ARTIFACTORY_USER and ARTIFACTORY_TOKEN are necessary to gain access to Artifactory for image download.

    Args:
    - [optional, CSM version], e.g. "v1.3.0-rc5" determines which CSM version tag you want to build the image from.
      Right now, this must be the first argument. If unspecified, will default to the last tag containing "rc". Refer to
      https://github.com/Cray-HPE/csm/tags for a list of tags.
    - "--from-existing" skips the Artifactory download in case you are just modifying the existing image.
    - "--help" displays this message.
EOH
}

[[ $1  == '--from-existing' || $2 == '--from-existing' ]] && FROM_EXISTING=1 || FROM_EXISTING=0 # Skips downloading new artifacts.
[[ $1 == '--help' || $2 == '--help' ]] && help && exit 0;
[[ $(hostname) == "libvirthost" ]] && \
    exit_w_message "WARNING: This script runs a lot faster from outside of the libvirt_host VM. Consider running at the root of this repo from the host."

# CSM_TAG to latest beta version if not specified, and make sure it's not a different script arg.
LATEST_BETA_TAG=$(get_latest_beta_version)
CSM_TAG="${1:-$LATEST_BETA_TAG}"
[[ $(echo $CSM_TAG | grep -E '^--') ]] && CSM_TAG="${LATEST_BETA_TAG}"
export CSM_TAG
echo "Building image using CSM ${CSM_TAG}..."

RELEASE_BRANCH=$(get_release_branch_from_tag $CSM_TAG)
# Produces array KUBERNETES_ASSETS coming from assets.sh in CSM repo.
get_k8s_ncn_artifact_urls $CSM_TAG
BOX_URL=$(get_k8s_ncn_qcow2_url ${KUBERNETES_ASSETS[0]})

function purge_old_assets() {
    echo "Destroying related VM and previous artifacts..."
    vagrant ssh -- -t <<-K8S_DESTROY
    cd /vagrant/k8s_ncn
    [[ $(vagrant status --machine-readable | grep "state,running") ]] && sudo vagrant destroy -f
K8S_DESTROY
    rm -rf $STAGE_DIR
    rm -rf $BOOT_DIR
}

# Start Libvirthost if not started so we can use virt-customize to modify the image.
$SCRIPT_DIR/start.sh

# Prepare asset directories
[[ $FROM_EXISTING == 1 ]] || purge_old_assets
mkdir -p $STAGE_DIR
mkdir -p $BOOT_DIR
display_disk_capacity

if [[ $FROM_EXISTING == 0 ]]; then
    smart_download $STAGE_DIR/$IMAGE_NAME $BOX_URL
fi
