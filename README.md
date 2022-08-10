# Vagrant NCN OS Test Harness

## Summary

This repo aims to provide an easy way to test installation content and Ansible orchestration against the OS of a management node.
It will download a k8s NCN image, create a libvirt vagrant box and launch the VM in another VM's libvirt service.

You must have an account at artifactory.algol60.net to use it. Contact CSM DevOps for one if needed.

## Getting Started

Any of the scripts below may guide you through an interactive script to populate your .env credentials if not already done.

1. If running Mac, `./mac_one_time_setup.sh` to make sure dependencies are met.
1. Run `cd libvirt_host && ./start.sh` to spin up the Libvirt host.
    - Takes about 10 minutes.
    - TIP: In the libvirt_host directory, use `vagrant halt` when stopping the environment to avoid needing to do this again.
1. Run `./update_box.sh` to produce a Vagrant box. You can optionally specify a CSM release as the first argument, e.g. '1.2'.
    - Takes about 10-15 minutes and requires 40GB of free disk space.
    - You will want to do periodically to ensure you are testing with something current for the CSM release.
1. From the root directory here, run `cd k8s_ncn && ./start.sh`.
1. Once the machine is booting, you can observe console output by attaching a vnc client at 192.168.56.4.

## TODO

1. Fix Vagrant detection that k8s worker booted.
1. Add cloud-init provisioning user data to spin up a single node worker.
1. Add helper scripts for checking product stream repos and running them via `vagrant provision`.
