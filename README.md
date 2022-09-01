# Vagrant NCN OS Test Harness

## Summary

This repo aims to provide an easy way to test installation content and Ansible orchestration against the OS of a management node.
It will download a k8s NCN image, create a libvirt vagrant box and launch the VM in another VM's libvirt service.

You must have an account at artifactory.algol60.net to use it. Contact CSM DevOps for one if needed.

## Getting Started

### Local Environment

Any of the scripts below may guide you through an interactive script to populate your .env credentials if not already done.

1. One-time: If running Mac, `./mac_one_time_setup.sh` to make sure dependencies are met.
1. One-time: Run `./start.sh` to spin up the Libvirt host.
    - Takes about 10 minutes.
1. Run `vagrant ssh` to shell into libvirt_host. Then run `cd /vagrant && sudo su`.
1. Run `./update_box.sh` to produce a Vagrant box. You can optionally specify a CSM tag as the first argument. For a list of tags, refer to <https://github.com/Cray-HPE/csm/tags>.
    - Takes about 30 minutes and requires 40GB of free disk space.
    - You will want to do periodically to ensure you are testing with something current for the CSM release.
1. Make sure you are on the VPN and run `cd k8s_ncn && ./start.sh`.
1. As the machine is booting, you can observe console output by attaching a vnc client at 192.168.56.4.
1. Run `vagrant ssh` to shell into the k8s_ncn VM and `cd /vagrant` to get to the guest_mount from the host.

From here, you can checkout any other repos on your host into [repo_root]/guest_mount and test them inside of the k8s_ncn. You can revert to snapshots of either the libvirt_host or the k8s_ncn to save time in test iterations.

### NCN Hosted

These instructions apply if trying to standup the vagrant environment from an NCN host.

1. Shell into an NCN worker, run `cd /var/lib/s3fs_cache && git clone https://github.com/Cray-HPE/vagrant_ncn_os_test_harness.git` Then cd into vagrant_ncn_os_test_harness.
1. One-time: Run `scripts/configure_ncn.sh` to install kvm and libvirt.
1. As needed: Run `scripts/update_box_from_ncn.sh [CSM Tag]` to create the vagrant box.
1. Run `cd k8s_ncn && scripts/start_on_ncn.sh`
1. Optional: If you want to see the console output during boot, you can create a ssh tunnel and vnc to the machine. Run this on your desktop/laptop `ssh -N -T -l root -L5900:[name of NCN, e.g. ncn-w004]:5900 [m001 IP address]` and then open your VNC app of choice and point it to localhost.

## Operations

### Libvirthost Appliance

The following list represents ad-hoc procedures (not sequential steps) for common operations.
All are performed from the k8s_ncn directory:

- In the libvirt_host directory, use `vagrant halt` when stopping the environment to avoid needing to do this again.
- If you do need to revert to a clean base use `vagrant snapshot restore base`.
- To ssh in, run 'vagrant ssh'.
- If the libvirthost VM freezes for any reason or you can't ssh into it, 

### K8s_NCN VM

The following list represents ad-hoc procedures (not sequential steps) for common operations.
All are performed from the k8s_ncn directory:

- Run 'vagrant snapshot save SNAPSHOT_NAME' to take snapshots of various states.
- To view the console, vnc to 192.168.56.4:5900.
- To ssh in run 'vagrant ssh'.
- When done for the day run 'vagrant halt' if you want to retain the current VM.
- Run 'vagrant destroy -f' to destroy it.
- Take and restore snapshots of the k8s_ncn vm using the scripts in /vagrant/k8s_ncn/scripts.

### Downloading the latest NCN image

- Simply run ./update_box.sh from the repo root directory to fetch the lates image. WARNING: This will destroy your existing k8s_ncn VM.
- You can specify the specific CSM tagged version by passing it in to ./update_box.sh as the first argument. Defaults to v1.3.0-RC.1.
  - Refer to [CSM Tags on Github](https://github.com/Cray-HPE/csm/tags) for the list of available tags.

## TODO

1. Address the myriad of TODO comments in this codebase.
1. Add cloud-init provisioning user data to spin up a single node worker.
1. Add helper scripts for checking product stream repos and running them via `vagrant provision`.
1. Speed up the update box script by making it not execute against an NFS mount.
1. Deliver built boxes to Artifactory.
