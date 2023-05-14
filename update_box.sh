#!/usr/bin/env bash
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
    The update_box.sh script determines the latest version of the kubernetes image for a given CSM tag.
    It then downloads it from Artifactory and builds a Vagrant box. Lastly, it deletes your k8s_ncn vm
    and associated volume so that your next boot uses the new image.

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
 get_ncn_assets_vars $CSM_TAG
K8S_KERNEL_URL=${KUBERNETES_ASSETS[1]}
K8S_INITRD_URL=${KUBERNETES_ASSETS[2]}
QCOW2_URL=$(get_k8s_ncn_qcow2_url ${KUBERNETES_ASSETS[0]})

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
    smart_download $STAGE_DIR/$IMAGE_NAME $QCOW2_URL
    smart_download $BOOT_DIR/k8s_ncn.kernel $K8S_KERNEL_URL
    smart_download $BOOT_DIR/k8s_ncn_initrd.xz $K8S_INITRD_URL
fi

echo "Preparing image for libvirt boot..."
# Modify image so it boots in Vagrant correctly. Use escaped dollar signs for commands running in libvirt_host.
run_in_vagrant <<-EOS
export ZYPPER_CACHE=/var/cache/zypp/packages
[[ \$(zypper repos | grep repo-sle-update-sp3) ]] || \
    zypper -n ar http://download.opensuse.org/update/leap/15.3/sle/ repo-sle-update-sp3
[[ -f \$(find \$ZYPPER_CACHE -name qemu-guest-agent*) ]] || \
    zypper -n install -d --from repo-sle-update-sp3 --oldpackage qemu-guest-agent-5.2.0-150300.115.2.x86_64

LIBGUESTFS_DEBUG=1 sudo virt-customize \
    -a /vagrant/images/box.img --network \
    --append-line /etc/fstab:"192.168.122.1:/vagrant/guest_mount /vagrant nfs rw,intr,nfsvers=4,proto=tcp 0 0" \
    --copy-in \$(find \$ZYPPER_CACHE -name liburing*):/tmp/ \
    --copy-in \$(find \$ZYPPER_CACHE -name qemu-guest-agent*):/tmp/ \
    --root-password password:${VAGRANT_NCN_PASSWORD} \
    --run-command 'zypper -n remove dracut-metal-dmk8s dracut-metal-luksetcd dracut-metal-mdsquash || true' \
    --run-command 'for PACKAGE in \$(ls /tmp/*.rpm); do [[ \$(rpm -qi \$PACKAGE) ]] || rpm -i \$PACKAGE; done' \
    --run-command 'rm /tmp/*.rpm' \
    --run-command 'systemctl disable kubelet cray-heartbeat spire-agent' \
    --run-command 'mv /etc/cloud/cloud.cfg.d /etc/cloud/cloud.cfg.d.bak && mkdir -p /etc/cloud/cloud.cfg.d' \
    --write /etc/cray/vagrant_image.bom:"CSM_TAG=${CSM_TAG}\nQCOW2_SOURCE=${QCOW2_URL}\nINITRD_SOURCE=${K8S_INITRD_URL}\nKERNEL_SOURCE=${K8S_KERNEL_URL}\nRELEASE_BRANCH=${RELEASE_BRANCH}" \
    --run-command 'echo -e "\$(cat /etc/cray/vagrant_image.bom)" > /etc/cray/vagrant_image.bom'
EOS
create_vagrant_box $CSM_TAG $BOX_NAME $IMAGE_NAME $STAGE_DIR
vagrant ssh -- -t <<-EOC
    vagrant box remove ${BOX_NAME} || true
    vagrant box add --name ${BOX_NAME} /vagrant/images/${BOX_NAME}.box --force
EOC

