#!/usr/bin/env bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
STAGE_DIR=$SCRIPT_DIR/libvirt_host/images
BOOT_DIR=$SCRIPT_DIR/libvirt_host/boot
BRANCH="${1:-main}"
IMAGE_NAME=box.img
BOX_NAME=k8s_ncn
if [[ -z "${ARTIFACTORY_USER}" || -z "${ARTIFACTORY_TOKEN}" ]]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

function purge_old_assets() {
    echo "Destroying related VM and previous artifacts..."
    cd $SCRIPT_DIR/k8s_ncn
    vagrant destroy -f || true
    cd $OLDPWD
    rm -rf $STAGE_DIR
    rm -rf $BOOT_DIR
}
[[ $1 == "--purge" || $2 == "--purge" ]] && purge_old_assets
mkdir -p $STAGE_DIR
mkdir -p $BOOT_DIR

FREE_DISK_SPACE=$(df -kh . | tail -n1 | awk '{print $4}')
echo "This operation requires about 40GB of free hard drive space. If you see write errors, please check that you have free capacity."
echo "You current have ${FREE_DISK_SPACE} of free disk space."

# Determine correct version of image and begin downloading.
echo "Referencing image for the head of branch $BRANCH."
source /dev/stdin < <(curl -fsSL https://raw.githubusercontent.com/Cray-HPE/csm/$BRANCH/assets.sh | grep -E -o -m 1 -A 4 "^KUBERNETES_ASSETS=\(+")
QCOW2_URL=$(echo ${KUBERNETES_ASSETS[0]} | sed 's/squashfs/qcow2/g')
echo "Downloading image from $QCOW2_URL"
curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $STAGE_DIR/$IMAGE_NAME $QCOW2_URL
curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $BOOT_DIR/k8s_ncn.kernel ${KUBERNETES_ASSETS[1]}
curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $BOOT_DIR/k8s_ncn_initrd.xz ${KUBERNETES_ASSETS[2]}

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
    "virtual_size": 40
}
EOF

echo "Removing CSM dracut scripts from image..."
cd $SCRIPT_DIR/libvirt_host
vagrant ssh -c "sudo virt-customize -a /vagrant/images/box.img --run-command 'zypper -n remove dracut-metal-dmk8s dracut-metal-luksetcd dracut-metal-mdsquash'"
cd $OLDPWD

# sudo chown $(whoami):admin $STAGE_DIR/$IMAGE_NAME
echo "Creating a tarball of Vagrant assets. This may take a 5-10 minutes without console feedback."
cd $STAGE_DIR
tar cvzf ${BOX_NAME}.box metadata.json Vagrantfile $IMAGE_NAME
cd $OLDPWD
vagrant box add --name ${BOX_NAME} $STAGE_DIR/${BOX_NAME}.box --force