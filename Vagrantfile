# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
REQUIRED_PLUGINS = %w[vagrant-env].freeze
exit 1 unless REQUIRED_PLUGINS.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    true
  )
end

nfs_vers = if RbConfig::CONFIG['host_os'].match?(/^darwin/)
             3
           else
             4
           end

Vagrant.configure('2') do |config|
  config.vm.box = 'opensuse/Leap-15.4.x86_64'
  config.env.enable
  config.vm.network 'private_network', ip: ENV['LIBVIRT_HOST_IP']
  config.vm.synced_folder '.', '/vagrant',
                          type: 'nfs',
                          nfs_udp: false,
                          nfs_version: nfs_vers,
                          linux__nfs_options: ['rw', 'no_subtree_check', 'no_root_squash', 'async']
  config.vm.hostname = 'libvirthost'
  config.vm.provider :libvirt do |ncn|
        # ncn.default_prefix = "csm-"
        ncn.autostart = true

        # Speeds up the boot a little by specifying exactly how to boot.
        ncn.boot 'hd'
        ncn.disk_device = 'vda'
        ncn.disk_bus = 'virtio'

        # Enables vnc console access at the LIBVIRT_HOST_IP.
        ncn.graphics_type = 'vnc'
        ncn.graphics_ip = '0.0.0.0'
        ncn.graphics_port = '5900'

        # TODO: Make something a little smarter here for CPU core request.
        ncn.cpus = ENV['LIBVIRT_HOST_CPUS']
        ncn.memory = ENV['LIBVIRT_HOST_MEMORY']

        # Enable KVM nested virtualization.
        ncn.nested = true
        ncn.cpu_mode = 'host-passthrough'

        # Maximizes compatibility for Intel-based machines.
        ncn.machine_type = 'q35'

        # Helps libvirt detect that the machine got an IP.
	    ncn.management_network_mac = '525400123457'
  end

  config.vm.provider 'virtualbox' do |v|
    v.name = 'libvirthost'
    # v.gui = true
    v.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
    v.customize ['modifyvm', :id, '--vm-process-priority', 'high']
    v.customize ['modifyvm', :id, '--hwvirtex', 'on']
    v.customize ['modifyvm', :id, '--vtxux', 'on']
    v.customize ['modifyvm', :id, '--nestedpaging', 'on']
    v.customize ['modifyvm', :id, '--largepages', 'on']
    v.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
    v.customize ['modifyvm', :id, '--chipset', 'ich9']
    v.memory = ENV['LIBVIRT_HOST_MEMORY']
    v.cpus = ENV['LIBVIRT_HOST_CPUS']
  end
  config.vm.provision 'shell', path: 'scripts/suse_setup_libvirt.sh'
end
