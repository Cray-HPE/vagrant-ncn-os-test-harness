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
    - The libvirt_host VM must be up in order to perform the necessary modifications to the image.
      ----- The libvirt_host is $(cd ./libvirt_host && vagrant status | grep virtualbox | grep -v "\n" | sed -e 's/^default                   //')
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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
STAGE_DIR=$SCRIPT_DIR/libvirt_host/images
BOOT_DIR=$SCRIPT_DIR/libvirt_host/boot
IMAGE_NAME=box.img
BOX_NAME=k8s_ncn
source $SCRIPT_DIR/scripts/env_handler.sh

function exit_w_message() {
    echo $1
    exit 1
}

# Branch name input validation.
BRANCH="${1:-main}"
[[ $(echo $BRANCH | grep -E '^--') ]] && BRANCH=main
[[ $BRANCH == "1.0" || $BRANCH == "1.2" || $BRANCH == "1.3" || $BRANCH == "1.4" || $BRANCH == "main" ]] || \
    exit_w_message "Please enter a valid CSM branch version: 1.0, 1.2, 1.3, 1.4, or main."
[[ $BRANCH == "1.3" ]] && BRANCH="main" # The version our main branch tracks.
[[ $BRANCH != "main" ]] && BRANCH="release/${BRANCH}" # Converts it to a release branch.



function purge_old_assets() {
    echo "Destroying related VM and previous artifacts..."
    cd $SCRIPT_DIR/k8s_ncn
    vagrant destroy -f || true
    cd $OLDPWD
    cd $SCRIPT_DIR/libvirt_host
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
}

# Start Libvirthost if not started so we can use virt-customize to modify the image.
$SCRIPT_DIR/libvirt_host/start.sh

# Prepare asset directories
[[ $FROM_EXISTING == 1 ]] || purge_old_assets
mkdir -p $STAGE_DIR
mkdir -p $BOOT_DIR
display_disk_capacity

# Determine correct version of image and begin downloading.
if [[ $FROM_EXISTING == 0 ]]; then
    echo "Referencing image for the head of branch $BRANCH."
    source /dev/stdin < <(curl -fsSL https://raw.githubusercontent.com/Cray-HPE/csm/$BRANCH/assets.sh | grep -E -m 1 -A 4 "^KUBERNETES_ASSETS=\(+")
    QCOW2_URL=$(echo ${KUBERNETES_ASSETS[0]} | sed 's/squashfs/qcow2/g')

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
    "name": "csm/k8s_ncn_${BRANCH}",
    "description": "This box contains a libvirt qcow2 image for testing the CSM K8s NCN image.",
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": 50
}
EOF
# NOTE FOR ABOVE ^: virtual_size must be larger than the original size of 46, otherwise the partitions are destroyed.

# Modify image so it boots in Vagrant correctly.
echo "Removing CSM dracut scripts from image..."
cd $SCRIPT_DIR/libvirt_host
vagrant ssh -- -t <<-EOS
    sudo virt-customize \
        -a /vagrant/images/box.img \
        --root-password password:${VAGRANT_NCN_PASSWORD} \
        --run-command 'zypper -n remove dracut-metal-dmk8s dracut-metal-luksetcd dracut-metal-mdsquash' \
        --run-command 'user add -m vagrant' \
        --password vagrant:password:vagrant
EOS
cd $OLDPWD

# Create the vagrant box.
echo "Creating a tarball of Vagrant assets. This may take a 5-10 minutes without console feedback."
cd $STAGE_DIR
tar cvzf ${BOX_NAME}.box metadata.json Vagrantfile $IMAGE_NAME
cd $OLDPWD
vagrant box add --name ${BOX_NAME} $STAGE_DIR/${BOX_NAME}.box --force
