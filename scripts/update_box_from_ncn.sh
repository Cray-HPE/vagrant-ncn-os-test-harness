#!/usr/bin/env bash
set -e

function display_disk_capacity() {
    FREE_DISK_SPACE=$(df -kh . | tail -n1 | awk '{print $4}')
    echo "This operation requires about 40GB of free hard drive space. If you see write errors, please check that you have free capacity."
    echo "------ You currently have ${FREE_DISK_SPACE} of free disk space. ------"
}

function help() {
    cat <<EOH | sed -e 's/^    //';
    Summary:
    The update_box.sh script determines the latest version of the kubernetes image for a given CSM release.
    It then downloads it from Artifactory and builds a Vagrant box. Lastly, it deletes your k8s_ncn vm
    and associated volume so that your next boot uses the new image.

    Requirements:
    - This script expects to be run from within the libvirthost vm.
    - $(display_disk_capacity)

    Four environment variables are expected for credentialing. These will be asked for if not found in your .env.
    - ARTIFACTORY_USER and ARTIFACTORY_TOKEN are necessary to gain access to Artifactory for image download.
    - VAGRANT_NCN_USER and VAGRANT_NCN_PASSWORD are necessary to populate ssh credentials into the image.

    Args:
    - [optional, CSM version], e.g. "1.3" determines which CSM version you want to build the image from.
      Right now, this must be the first argument. If unspecified, will default to "1.3".
    - "--from-existing" skips the Artifactory download in case you are just modifying the existing image.
    - "--help" displays this message.
EOH
}

[[ $1  == '--from-existing' || $2 == '--from-existing' ]] && FROM_EXISTING=1 || FROM_EXISTING=0 # Skips downloading new artifacts.
[[ $1 == '--help' || $2 == '--help' ]] && help && exit 0;

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/..
cd $SCRIPT_DIR
STAGE_DIR=$SCRIPT_DIR/images
BOOT_DIR=$SCRIPT_DIR/k8s_ncn/boot
IMAGE_NAME=box.img
BOX_NAME=k8s_ncn
source $SCRIPT_DIR/scripts/env_handler.sh

function exit_w_message() {
    echo $1
    exit 1
}


# CSM_TAG name input validation.
LATEST_BETA_TAG=$(curl -s https://api.github.com/repos/Cray-HPE/csm/tags | jq -r 'limit(1; .[].name | select( . | contains("beta")))')
CSM_TAG="${1:-$LATEST_BETA_TAG}"
[[ $(echo $CSM_TAG | grep -E '^--') ]] && CSM_TAG="${LATEST_BETA_TAG}"
echo "Building image using CSM ${CSM_TAG}..."
# TODO: Find a way to more precisely track the csm-rpms sha used to build the image
RELEASE_BRANCH="release/$(echo $CSM_TAG | sed -nE 's/[v,V]([0-9]\.[0-9]).*/\1/p')"
[[ $(echo $RELEASE_BRANCH) == "release/1.4" ]] && RELEASE_BRANCH=main
CSM_ASSETS_URL="https://raw.githubusercontent.com/Cray-HPE/csm/$CSM_TAG/assets.sh"
[[ $(curl -LI ${CSM_ASSETS_URL} -o /dev/null -w '%{http_code}\n' -s) == "200" ]] || \
    exit_w_message "Please provide a valid CSM tag as the first argument. Refer to https://github.com/Cray-HPE/csm/tags"


function purge_old_assets() {
    echo "Destroying related VM and previous artifacts..."
    cd $SCRIPT_DIR/k8s_ncn
    [[ $(vagrant status --machine-readable | grep "state,running") ]] && vagrant destroy -f
    cd $OLDPWD
    rm -rf $STAGE_DIR
    rm -rf $BOOT_DIR
}

function smart_download() {
    PATH_LOCAL_FILE=$1
    DOWNLOAD_URL=$2
    echo "Downloading image from $DOWNLOAD_URL"
    if [[ -f $PATH_LOCAL_FILE ]]; then
        echo "File $PATH_LOCAL_FILE exists. Determining point to resume download from."
    fi
    until curl -C - -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $PATH_LOCAL_FILE $DOWNLOAD_URL
    do
        echo "Resuming download..."
        sleep 1
    done
    # TODO: Fetch and compare the sha to confirm file integrity.
}

# Prepare asset directories
[[ $FROM_EXISTING == 1 ]] || purge_old_assets
mkdir -p $STAGE_DIR
mkdir -p $BOOT_DIR
display_disk_capacity

# Determine correct version of image and begin downloading.
    echo "Referencing image at CSM tag $CSM_TAG: $CSM_ASSETS_URL"
    source /dev/stdin < <(curl -fsSL $CSM_ASSETS_URL | grep -E -m 1 -A 4 "^KUBERNETES_ASSETS=\(+")
    QCOW2_URL=$(echo ${KUBERNETES_ASSETS[0]} | sed 's/squashfs/qcow2/g')
if [[ $FROM_EXISTING == 0 ]]; then
    smart_download $STAGE_DIR/$IMAGE_NAME $QCOW2_URL
    smart_download $BOOT_DIR/k8s_ncn.kernel ${KUBERNETES_ASSETS[1]}
    smart_download $BOOT_DIR/k8s_ncn_initrd.xz ${KUBERNETES_ASSETS[2]}
fi

# Create a Vagrant box.
cat <<-EOF > $STAGE_DIR/Vagrantfile
Vagrant.configure("2") do |config|
    config.vm.provider :libvirt do |libvirt|
        libvirt.driver = "kvm"
        libvirt.host = 'localhost'
        libvirt.uri = 'qemu:///session'
    end
    config.vm.define "new" do |custombox|
        custombox.vm.box = "${BOX_NAME}"
        custombox.vm.provider :libvirt do |test|
            test.memory = 2048
            test.cpus = 2
        end
    end
end
EOF
cat <<-EOF > $STAGE_DIR/metadata.json
{
    "name": "csm/k8s_ncn_${CSM_TAG}",
    "description": "This box contains a libvirt qcow2 image for testing the CSM K8s NCN image.",
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": 50
}
EOF
# NOTE FOR ABOVE ^: virtual_size must be larger than the original size of 46, otherwise the partitions are destroyed.

# Modify image so it boots in Vagrant correctly.
ZYPPER_CACHE=/var/cache/zypp/packages
echo "Preparing image for libvirt boot..."
cd $STAGE_DIR
[[ ! -f $STAGE_DIR/qemu-guest-agent-6.2.0-826.10.x86_64.rpm ]] && \
    wget https://download.opensuse.org/repositories/Virtualization/15.3/x86_64/qemu-guest-agent-6.2.0-826.10.x86_64.rpm
cd $OLDPWD
LIBGUESTFS_DEBUG=1 sudo virt-customize \
    -a $STAGE_DIR/box.img --network \
    --append-line /etc/fstab:"192.168.122.1:/vagrant/guest_mount /vagrant nfs rw,intr,nfsvers=4,proto=tcp 0 0" \
    --copy-in $(find $STAGE_DIR -name qemu-guest-agent*):/tmp/ \
    --root-password password:${VAGRANT_NCN_PASSWORD} \
    --run-command 'zypper -n remove dracut-metal-dmk8s dracut-metal-luksetcd dracut-metal-mdsquash || true' \
    --run-command 'for PACKAGE in $(ls /tmp/*.rpm); do [[ $(rpm -qi $PACKAGE) ]] || rpm -i $PACKAGE; done' \
    --run-command 'rm /tmp/*.rpm' \
    --run-command 'systemctl disable kubelet cray-heartbeat spire-agent' \
    --run-command 'mv /etc/cloud/cloud.cfg.d /etc/cloud/cloud.cfg.d.bak && mkdir -p /etc/cloud/cloud.cfg.d' \
    --write /etc/cray/vagrant_image.bom:"CSM_TAG=${CSM_TAG}\nQCOW2_SOURCE=${QCOW2_URL}\nINITRD_SOURCE=${KUBERNETES_ASSETS[2]}\nKERNEL_SOURCE=${KUBERNETES_ASSETS[1]}\nRELEASE_BRANCH=${RELEASE_BRANCH}" \
    --run-command 'echo -e "$(cat /etc/cray/vagrant_image.bom)" > /etc/cray/vagrant_image.bom'

# Create the vagrant box.
echo "Creating a tarball of Vagrant assets. This may take a 5-10 minutes without console feedback."
cd $STAGE_DIR
tar cvf ${BOX_NAME}.box metadata.json Vagrantfile $IMAGE_NAME
cd $OLDPWD
vagrant box add --name ${BOX_NAME} $STAGE_DIR/${BOX_NAME}.box --force
