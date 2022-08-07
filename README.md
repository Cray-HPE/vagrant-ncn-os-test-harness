# Vagrant NCN OS Test Harness

## Summary
This repo aims to provide an easy way to test installation content and Ansible orchestration against the OS of a management node.
Right now, it includes:

1. A one-time set up script for Mac users that installs vagrant, virtualbox, and vnc-viewer.
1. A script for downloading and producing a Vagrant box from the latest K8s image for a particular CSM release.
1. A Libvirt host running in a Virtualbox guest for deploying QCOW2 images against.
1. A Vagrantfile for deploying the k8s_ncn image into Libvirt and running Ansible plays against it.

## Getting Started

You will need to set environment variables for credentials to download the vagrant box from artifactory, as well as for the ssh access into it. For now, contact Dennis Walker for access.

1. If running Mac, `./mac_one_time_setup.sh` to make sure dependencies are met.
1. Run `cd libvirt_host && ./start.sh` to spin up the Libvirt host.
    - Takes about 10 minutes.
    - TIP: In the libvirt_host directory, use `vagrant halt` when stopping the environment to avoid needing to wait again.
1. Set your Artifactory credentials in environment variables optionally by adding the following lines to your .bashrc. If you don't have credentials contact casm_devops.
    - export ARTIFACTORY_USER=your_user_name
    - export ARTIFACTORY_TOKEN=your_artifactory_app_token
1. Run `./update_box.sh` to produce a Vagrant box. You can optionally specify a CSM release as the first argument, e.g. '1.2'.
    - Takes about 10-15 minutes and requires 40GB of free disk space.
1. From the root directory here, run `cd k8s_ncn && ./start.sh`. You will need to set environment variables for the NCN user and password.
    - export VAGRANT_NCN_USER=example_user
    - export VAGRANT_NCN_PASSWORD=example_password
1. Once the machine is booting, you can observe console output by attaching a vnc client (vnc-viewer on mac) to 127.0.0.1.


# TODO

1. Fix Vagrant detection that k8s worker booted.
1. Add cloud-init provisioning user data to spin up a single node worker.
1. Add helper scripts for checking product stream repos and running them via `vagrant provision`.
