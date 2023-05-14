# Vagrant NCN OS Test Harness

- [Summary](#summary)
- [Getting Started](#getting-started)
    - [Local Hosted](#local-environment)
        - [Debian/Ubuntu](#debianubuntu)
        - [macOS](#macos)
    - [NCN Hosted](#ncn-hosted)
- [Operations](#operations)
    - [`libvirthost` appliance](#libvirthost-appliance)
    - [`k8s_ncn` VM](#k8s_ncn-vm)
    - [Downloading NCN images](#downloading-ncn-images)
        - [Downlading the latest NCN images](#downloading-the-latest-ncn-images)
        - [Manually downloading latest or specific NCN images](#manually-downloading-latest-or-specific-ncn-images)
          - [Download artifacts by an ID](#download-artifacts-by-an-id)
          - [Download the latest artifacts](#download-the-latest-artifacts)
- [TODO](#todo)

## Summary

This repo aims to provide an easy way to test installation content and Ansible orchestration against the OS of a management node.
It will download a k8s NCN image, create a libvirt vagrant box and launch the VM in another VM's libvirt service.

You must have an account at artifactory.algol60.net to use it. Contact CSM DevOps for one if needed.

## Getting Started

Any of the scripts below may guide you through an interactive script to populate your `.env` credentials if not already done.

For first-time users, use one of the scripts provided in the listed operating systems below, before moving onto [usage](#usage).

### Local Hosted

#### Debian/Ubuntu

This is a one-time step for initializing a Debian/Ubuntu environment. This requires passwordless `sudo` access.

1. Setup `libvirt`:

    ```bash
    ./scripts/debian_setup_libvirt.sh
    ```

1. Setup the environment:

    ```bash
    ./start.sh
    ```

1. Download a box of your choice, by referring to the [downloading the latest NCN images](#downloading-the-latest-ncn-images) section and then return here.

1. Load the boxes

    - Pre-install-toolkit

        ```bash
        vagrant box add --name pre-install-toolkit --provider libvirt pre-install-toolkit.box
        ```

    - Kubernetes

        ```bash
        vagrant box add --name kubernetes --provider libvirt kubernetes.box
        ```

    - Storage-CEPH

        ```bash
        vagrant box add --name storage-ceph --provider libvirt storage-ceph.box
        ```

1. Initialize a `Vagrantfile`

    - Pre-install-toolkit

        ```bash
        vagrant init pre-install-toolkit
        ```

    - Kubernetes

        ```bash
        vagrant init kubernetes
        ```

    - Storage-CEPH

        ```bash
        vagrant init storage-ceph
        ```

1. Start the VM(s)

    ```bash
    vagrant up --provider libvirt
    ```

1. SSH to the VM(s) 

    ```bash
    vagrant ssh
    ```

#### MacOS

> ***NOTE*** This section is in-progress.

This is a one-time step for initializing a MacOS environment. Run one of the following scripts to
setup the Mac environment for this repository.

1. Setup VirtualBox:

    ```bash
    ./scripts/macOS_setup_VirtualBox.sh
    ```

1. Setup `libvirt`:

    > ***NOTE*** `libvirt` currently does not support MacOS out-of-the-box, this path is currently provided for experimental purposes.

    ```bash
    ./scripts/macOS_setup_libvirt.sh
    ```

1. ***One-time:*** Run this to spin up the Libvirt host

    > Takes about 10 minutes.

    ```bash
    ./start.sh
    ```

1. Run this to shell into `libvirt_host`. 

    ```bash
    vagrant ssh
    cd /vagrant && sudo su
    ```

1. Run this to produce a Vagrant box. You can optionally specify a CSM tag as the first argument.

    > - For a list of tags, refer to <https://github.com/Cray-HPE/csm/tags>.
    > - Takes about 30 minutes and requires 40GB of free disk space.
    > - You will want to re-run this periodically to ensure you are testing with something current for the CSM release.

    ```bash
    ./update_box.sh
    ```

1. Make sure you are on the VPN, or an internal machine, and run the following:

    ```bash
    cd k8s_ncn && ./start.sh
    ```

1. As the machine is booting, you can observe console output by attaching a vnc client at `192.168.56.4`.
1. Run this to shell into the `k8s_ncn` VM and then get to the `guest_mount` from the host.

    ```bash
    vagrant ssh
    cd /vagrant
    ```

From here, you can checkout any other repos on your host into `[repo_root]/guest_mount` and test them inside of the k8s_ncn. You can revert to snapshots of either the `libvirt_host` or the `k8s_ncn` to save time in test iterations.

### NCN Hosted

These instructions apply if trying to standup the vagrant environment from an NCN host.

1. Shell into an NCN worker, run `

    ```bash
    cd /var/lib/s3fs_cache && git clone https://github.com/Cray-HPE/vagrant_ncn_os_test_harness.git
    cd vagrant_ncn_os_test_harness
    ```

1. ***One-time:*** Run the following to install KVM and `libvirt`. This script rarely gets run, so you will probably have to step through it by hand.

    ```bash
    ./scripts/configure_ncn.sh
    ```

    Additionally, we'll want to attempt to enable sr-iov network interfaces for the vNCN to use. Run the following script, a few times if it fails.

    ```bash
    ./k8s_ncn/scripts/enable_sriov_devices.sh
    ```

   Next, we'll need to generate the network ifcfg files to use an IP address at the end of the range.
   
   ```bash
   ./k8s_ncn/scripts/prepare_network_configuration.sh
   ```

1. ***As needed:*** Run this to create the vagrant box

    ```bash
    ./scripts/update_box_from_ncn.sh [CSM Tag]
    ```

1. Then change into the staging area and start the box.

    ```bash
    cd k8s_ncn && scripts/start_on_ncn.sh
    ```

1. Copy in the network configuration files and apply.

   ```bash
   export VAGRANT_VAGRANTFILE=Vagrantfile.ncn
   vagrant ssh
   cp -R /vagrant/sandbox/network/* /etc/sysconfig/network
   systemctl restart network
   ```

1. Join the node to Kubernetes. # TODO: Get this working. Currently, m002 is not able to see the vNCNs NMN connection.

   ```bash
   exit # This line only if you are shelled into the vncn
   kubeadm token create --print-join-command > sandbox/k8s_join_command
   chmod +x sandbox/k8s_join_command
   vagrant ssh
   /vagrant/sandbox/k8s_join_command
   ```

1. ***Recommended*** If you want to see the console output during boot, you can create a SSH tunnel and VNC to the machine.
   Run this on your desktop/laptop and then open your VNC app of choice (such as `vncviewer`) and point it to `localhost`.

    ```bash
    ncn_host=ncn-w004 server=surtur-ncn-m001.us.cray.com ssh -N -T -l root -L5900:$ncn_host:5900 $server
    ```

    If successful, it will prompt you for the root password and display no other output. Leave the terminal open and run VNC.

## Operations

### Libvirthost Appliance

The following list represents ad-hoc procedures (not sequential steps) for common operations.
All are performed from the k8s_ncn directory:

- In the libvirt_host directory, use the following when stopping the environment to avoid needing to do this step again

    ```bash
    vagrant halt
    ```

- If you do need to revert to a clean base run the following

    ```bash
    vagrant snapshot restore base
    ```

- To ssh in, run the following

    ```bash
    vagrant ssh
    ```

- If the libvirthost VM freezes for any reason or you can't ssh into it, run this to destroy it and restart.

    ```bash
    vagrant destroy -f
    ```

### `K8s_NCN` VM

The following list represents ad-hoc procedures (not sequential steps) for common operations.
All are performed from the `k8s_ncn/` directory:

- Run this to provision a pristine VM

    ```bash
    ./start.sh
    ```

- Run this to take snapshots of various states

    ```bash
    vagrant snapshot save SNAPSHOT_NAME
    ```

- To view the console, vnc to `192.168.56.4:5900`
- To ssh in run

    ```bash
    vagrant ssh
    ```

- When done for the day run this if you want to retain the current VM:

    ```bash
    vagrant halt
    ```

- Otherwise to destroy the VM

    ```bash
    vagrant destroy
    ```

- Take and restore snapshots of the `k8s_ncn` VM using the scripts in `/vagrant/k8s_ncn/scripts`.

### Downloading NCN Images

#### Downloading the Latest NCN Images

To fetch the latest artifacts by CSM release, simply run `./update_box.sh` from the repo root directory to fetch the latest image. 

> ***WARNING*** This will destroy your existing `k8s_ncn` VM.

You can specify the specific CSM tagged version by passing it in to ./update_box.sh as the first argument. Defaults to v1.3.0-RC.1.

> Refer to [CSM Tags on Github](https://github.com/Cray-HPE/csm/tags) for the list of available tags.

#### Manually Downloading Latest or Specific NCN Images

To download the latest artifacts manually, or by an IMAGE ID, use the following directions:

##### Download artifacts by an ID

- Set the image ID

    ```bash
    IMAGE_ID=0.3.47
    ```

- Pre-install-toolkit

    ```bash
    curl -f -o pre-install-toolkit.box https://$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN@artifactory.algol60.net/artifactory/csm-images/stable/pre-install-toolkit/${IMAGE_ID}/pre-install-toolkit-${IMAGE_ID}.box
    ```

- Kubernetes

    ```bash
    curl -f -o kubernetes.box https://$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN@artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${IMAGE_ID}/kubernetes-${IMAGE_ID}.box
    ```

- Storage-CEPH

    ```bash
    curl -f -o storage-ceph.box https://$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN@artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${IMAGE_ID}/storage-ceph-${IMAGE_ID}.box
    ```

##### Download the latest artifacts

- Pre-install-toolkit

    ```bash
    curl -f -o pre-install-toolkit.box https://$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN@artifactory.algol60.net/artifactory/csm-images/stable/pre-install-toolkit/\\[RELEASE\\]/pre-install-toolkit-\\[RELEASE\\].box
    ```

- Kubernetes

    ```bash
    curl -f -o kubernetes.box https://$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN@artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/\\[RELEASE\\]/kubernetes-\\[RELEASE\\].box
    ```

- Storage-CEPH

    ```bash
    curl -f -o storage-ceph.box https://$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN@artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/\\[RELEASE\\]/storage-ceph-\\[RELEASE\\].box
    ```

## TODO

1. Address the myriad of `TODO` comments in this codebase.
1. Add `cloud-init` provisioning user data to spin up a single node worker.
1. Add helper scripts for checking product stream repos and running them via `vagrant provision`.
1. Speed up the update box script by making it not execute against an NFS mount.
1. Use the built boxes in Artifactory for the SUSE/macOS path
