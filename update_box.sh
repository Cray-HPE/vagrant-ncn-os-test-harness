#!/usr/bin/env bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BOX_DIR=$SCRIPT_DIR/images
STAGE_DIR=$BOX_DIR/temp
mkdir -p $STAGE_DIR

BRANCH="${1:-main}"
IMAGE_NAME=box.img
BOX_NAME=k8s_ncn

if [[ -z "${ARTIFACTORY_USER}" || -z "${ARTIFACTORY_TOKEN}" ]]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

echo "This operation requires about 40GB of free hard drive space. If you see write errors, please check that you have free capacity."

# Determine correct version of image and begin downloading.
echo "Referencing image for the head of branch $BRANCH."
source /dev/stdin < <(curl -fsSL https://raw.githubusercontent.com/Cray-HPE/csm/$BRANCH/assets.sh | grep -E -o -m 1 -A 4 "^KUBERNETES_ASSETS=\(+")
QCOW2_URL=$(echo ${KUBERNETES_ASSETS[0]} | sed 's/squashfs/qcow2/g')
echo "Downloading image from $QCOW2_URL"
curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $STAGE_DIR/$IMAGE_NAME $QCOW2_URL

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
    "name": "csm/k8s_ncn_${BRANCH}",
    "description": "This box contains a libvirt qcow2 image for testing the CSM K8s NCN image.",
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": 25
}
EOF

# sudo chown $(whoami):admin $STAGE_DIR/$IMAGE_NAME
echo "Creating a tarball of Vagrant assets. This may take a 5-10 minutes without console feedback."
cd $STAGE_DIR
tar cvzf ${BOX_NAME}.box metadata.json Vagrantfile $IMAGE_NAME
cd $OLDPWD
vagrant box add --name ${BOX_NAME} $STAGE_DIR/${BOX_NAME}.box