# Vagrant NCN OS Test Harness

## Summary
This repo aims to provide an easy way to test installation content and Ansible orchestration against the OS of a management node.
Right now, it includes:

1. A one-time set up script for Mac users that installs vagrant, virtualbox, and vnc-viewer.
1. A script for downloading and producing a Vagrant box from the latest K8s image for a particular CSM release.
1. A Libvirt host running in a Virtualbox guest for deploying QCOW2 images against.
1. A Vagrantfile for deploying the k8s_ncn image into Libvirt and running Ansible plays against it.

## Known Issues

1. MAJOR: The k8s_ncn image does not yet boot. An Ubuntu box is left commented out in ./k8s_ncn/Vagrantfile to demonstrate functionality otherwise.

## Getting Started

1. If running Mac, `./mac_one_time_setup.sh` to make sure dependencies are met.
1. Run `cd libvirt_host && ./start.sh` to spin up the Libvirt host.
    - Takes about 10 minutes.
    - TIP: In the libvirt_host directory, use `vagrant halt` when stopping the environment to avoid needing to wait again.
1. To download the OS image, set your Artifactory credentials in environment variables optionally by adding the following lines to your .bashrc:
    - export ARTIFACTORY_USER=your_user_name
    - export ARTIFACTORY_TOKEN=your_artifactory_app_token
1. Run `./update_box.sh` to produce a Vagrant box.
    - Takes about 10-15 minutes and requires 40GB of free disk space.
1. From the root directory here, run `cd k8s_ncn && ./start.sh`
1. Once the machine is booting, you can observe console output by attaching a vnc client (vnc-viewer on mac) to 127.0.0.1.


# TODO

1. Fix the k8s_ncn image boot.
1. Add helper scripts for checking product stream repos and running them via `vagrant provision`.
