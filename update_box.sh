#!/usr/bin/env bash
# set -x
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
STAGE_DIR=$SCRIPT_DIR/libvirt_host/images
BOOT_DIR=$SCRIPT_DIR/libvirt_host/boot
BRANCH="${1:-main}"
[[ $BRANCH == "1.3" ]] && BRANCH="main" # The version our main branch tracks.
[[ $BRANCH != "main" ]] && BRANCH="release/${BRANCH}" # Converts it to a release branch.
IMAGE_NAME=box.img
BOX_NAME=k8s_ncn

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
    - The libvirt_host VM must be up in order to perform the necessary modifications to the image.
      ----- The libvirt_host is $(cd ./libvirt_host && vagrant status | grep virtualbox | grep -v "\n" | sed -e 's/^default                   //')
    - $(display_disk_capacity)

    Four environment variables are expected for credentialing:
    - ARTIFACTORY_USER and ARTIFACTORY_TOKEN are necessary to gain access to Artifactory for image download.
    - VAGRANT_NCN_USER and VAGRANT_NCN_PASSWORD are necessary to populate ssh credentials into the image.

    Args:
    - [optional, CSM version], e.g. "1.3" determines which CSM version you want to build the image from.
      Right now, this must be the first argument. If unspecified, will default to "1.3".
    - "--from-existing" skips the Artifactory download in case you are just modifying the existing image.
    - "--help" displays this message.
EOH
}

declare -A ARGS=$@
[[ ! $ARGS[*] =~ '--from-existing' ]]; FROM_EXISTING=$? # Skips downloading new artifacts.
[[ $ARGS[*] =~ '--help' ]] && help && exit 0;

if [[ -z "${ARTIFACTORY_USER}" || -z "${ARTIFACTORY_TOKEN}" ]]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    help
    exit 1
fi

if [[ -z "${VAGRANT_NCN_USER}" || -z "${VAGRANT_NCN_PASSWORD}" ]]; then
    echo "Missing authentication information for ssh. Please set VAGRANT_NCN_USER and VAGRANT_NCN_PASSWORD environment variables."
    help
    exit 1
fi

# Refresh ssh key in case libvirt_host has been recreated.
ssh-keygen -R 192.168.56.4
ssh-keyscan 192.168.56.4 >>~/.ssh/known_hosts

cd $SCRIPT_DIR/libvirt_host
vagrant up || $(echo "The libvirt_host must be up." && help && exit 1)
cd $OLDPWD

function purge_old_assets() {
    echo "Destroying related VM and previous artifacts..."
    cd $SCRIPT_DIR/k8s_ncn
    vagrant destroy -f || true
    cd $OLDPWD
    cd $SCRIPT_DIR/libvirt_host
    vagrant ssh -c "sudo virsh vol-delete k8s_ncn_vagrant_box_image_0_box.img --pool default"
    cd $OLDPWD
    rm -rf $STAGE_DIR
    rm -rf $BOOT_DIR
}
[[ $FROM_EXISTING == 1 ]] || purge_old_assets

mkdir -p $STAGE_DIR
mkdir -p $BOOT_DIR

display_disk_capacity

# Determine correct version of image and begin downloading.
if [[ $FROM_EXISTING == 0 ]]; then
    echo "Referencing image for the head of branch $BRANCH."
    source /dev/stdin < <(curl -fsSL https://raw.githubusercontent.com/Cray-HPE/csm/$BRANCH/assets.sh | grep -E -o -m 1 -A 4 "^KUBERNETES_ASSETS=\(+")
    QCOW2_URL=$(echo ${KUBERNETES_ASSETS[0]} | sed 's/squashfs/qcow2/g')
    echo "Downloading image from $QCOW2_URL"
    curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $STAGE_DIR/$IMAGE_NAME $QCOW2_URL
    curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $BOOT_DIR/k8s_ncn.kernel ${KUBERNETES_ASSETS[1]}
    curl -L -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o $BOOT_DIR/k8s_ncn_initrd.xz ${KUBERNETES_ASSETS[2]}
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
    "name": "csm/k8s_ncn_${BRANCH}",
    "description": "This box contains a libvirt qcow2 image for testing the CSM K8s NCN image.",
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": 50
}
EOF
# NOTE FOR ABOVE ^: virtual_size must be larger than the original size of 46, otherwise the partitions are destroyed.

echo "Removing CSM dracut scripts from image..."
cd $SCRIPT_DIR/libvirt_host
vagrant ssh -- -t <<-EOS
    sudo virt-customize \
        -a /vagrant/images/box.img \
        --root-password password:${VAGRANT_NCN_PASSWORD} \
        --run-command 'zypper -n remove dracut-metal-dmk8s dracut-metal-luksetcd dracut-metal-mdsquash'
EOS
cd $OLDPWD

# sudo chown $(whoami):admin $STAGE_DIR/$IMAGE_NAME
echo "Creating a tarball of Vagrant assets. This may take a 5-10 minutes without console feedback."
cd $STAGE_DIR
tar cvzf ${BOX_NAME}.box metadata.json Vagrantfile $IMAGE_NAME
cd $OLDPWD
vagrant box add --name ${BOX_NAME} $STAGE_DIR/${BOX_NAME}.box --force