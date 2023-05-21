#!/usr/bin/env bash
# MIT License
#
# (C) Copyright 2023 Hewlett Packard Enterprise Development LP
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

set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
for LIB in $SCRIPT_DIR/scripts/lib/*; do source $LIB; done
source $SCRIPT_DIR/scripts/env_handler.sh
cd $SCRIPT_DIR
export STAGE_DIR=$SCRIPT_DIR/images
export BOOT_DIR=$SCRIPT_DIR/boot

function help() {
    cat <<EOH | sed -e 's/^    //';
    Summary:
    The get_ncn_boxes.sh script determines the latest version of the kubernetes image for a given CSM tag. If no
    tag is specified, either by command line or from the .env file, then the latest beta tag is chosen. It then
    downloads it from Artifactory and builds a Vagrant box. Lastly, it deletes your k8s_ncn vm and associated 
    volume so that your next boot uses the new image. The tag used to download is captured in the .env file.

    Requirements:
    - This script expects to be run from within the libvirthost vm.
    - $(display_disk_capacity)

    Four environment variables are expected for credentialing. These will be asked for if not found in your .env.
    - ARTIFACTORY_USER and ARTIFACTORY_TOKEN are necessary to gain access to Artifactory for image download.
    - VAGRANT_NCN_USER and VAGRANT_NCN_PASSWORD are necessary to populate ssh credentials into the image.

    Args:
    - [optional, CSM version], e.g. "v1.3.0-beta.50" determines which CSM version tag you want to build the image from.
      Right now, this must be the first argument. If unspecified, will default to the last tag containing "beta". Refer to
      https://github.com/Cray-HPE/csm/tags for a list of tags.
    - "--from-existing" skips the Artifactory download in case you are just modifying the existing image.
    - "--help" displays this message.
EOH
}

[[ $1 == '--help' || $2 == '--help' ]] && help && exit 0;

# CSM_TAG to latest beta version if not specified, and make sure it's not a different script arg.
LATEST_BETA_TAG=$(get_latest_beta_version)
[[ -z $CSM_TAG ]] && CSM_TAG="${1:-$LATEST_BETA_TAG}"
[[ $(echo $CSM_TAG | grep -E '^--') ]] && CSM_TAG="${LATEST_BETA_TAG}"
export CSM_TAG

# Set .env variables for later use 
set_tag $CSM_TAG
CSM_RELEASE_BRANCH=$(get_release_branch_from_tag $CSM_TAG)
set_release_branch $CSM_RELEASE_BRANCH

echo "Downloading images for ${CSM_TAG}..."
get_ncn_assets_vars $CSM_TAG
NCN_ARCH='x86_64'
K8S_KERNEL_URL=${KUBERNETES_ASSETS[1]}
K8S_INITRD_URL=${KUBERNETES_ASSETS[2]}
PIT_BOX_URL="https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/csm-images/stable/pre-install-toolkit/${PIT_IMAGE_ID}/pre-install-toolkit-${PIT_IMAGE_ID}-${NCN_ARCH}.box"
KUBERNETES_BOX_URL="https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/kubernetes-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.box"
STORAGE_CEPH_BOX_URL="https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/storage-ceph-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.box"

if [[ $1 == "--replace-existing" || $2 == "--replace-existing" ]]; then
    # vagrant ssh -- -t <<-EOC
    vagrant box remove pit || true
    vagrant box remove k8s_ncn || true
    vagrant box remove storage_ncn || true
# EOC
    rm $STAGE_DIR/*.box
fi

smart_download $STAGE_DIR/pre-install-toolkit.box $PIT_BOX_URL   
smart_download $STAGE_DIR/kubernetes.box $KUBERNETES_BOX_URL
smart_download $STAGE_DIR/storage-ceph.box $STORAGE_CEPH_BOX_URL

#vagrant ssh -- -t <<-EOC
    vagrant box add --name pit /vagrant/images/pre-install-toolkit.box --force
    vagrant box add --name k8s_ncn /vagrant/images/kubernetes.box --force
    vagrant box add --name storage_ncn /vagrant/images/storage-ceph.box --force
# EOC

