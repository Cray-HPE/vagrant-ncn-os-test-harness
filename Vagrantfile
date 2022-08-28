REQUIRED_PLUGINS = %w(vagrant-env)
exit unless REQUIRED_PLUGINS.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

Vagrant.configure("2") do |config|
    config.vm.box = "opensuse/Leap-15.4.x86_64"
    config.env.enable
    config.vm.network "private_network", ip: ENV['LIBVIRT_HOST_IP']
    config.vm.synced_folder ".", "/vagrant",
      type: "nfs",
      nfs_udp: false,
      nfs_version: 4
    config.vm.hostname = "libvirthost"
    config.vm.provider "virtualbox" do |v|
        v.name = "libvirthost"
        #v.gui = true
        v.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
        v.customize ['modifyvm', :id, '--vm-process-priority', 'high']
        v.customize ['modifyvm', :id, '--hwvirtex', 'on']
        v.customize ['modifyvm', :id, '--vtxux', 'on']
        v.customize ['modifyvm', :id, '--nestedpaging', 'on']
        v.customize ['modifyvm', :id, '--largepages', 'on']
        v.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
        v.customize ["modifyvm", :id, "--chipset", "ich9"]
        v.memory = ENV['LIBVIRT_HOST_MEMORY']
        v.cpus = ENV['LIBVIRT_HOST_CPUS']
    end
    config.vm.provision "shell", path: "scripts/configure.sh"
end
