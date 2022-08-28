#!/usr/bin/env bash

brew install vagrant virtualbox vnc-viewer ngrok

#TODO: symlink eula to remove error message.
ln -s /Applications/VNC\ Viewer.app/Contents/MacOS/vncviewer /usr/local/bin/vncviewer
vagrant plugin install vagrant-env
# Download patch fix for setting up NFS folders on mac.
[[ $(vagrant --version) == "Vagrant 2.2.19" ]] && \
    sudo curl -o /opt/vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/plugins/hosts/darwin/cap/path.rb https://raw.githubusercontent.com/hashicorp/vagrant/42db2569e32a69e604634462b633bb14ca20709a/plugins/hosts/darwin/cap/path.rb

# Supposedly eliminates the need to type your password to configure NFS mounts per Vagrant docs.
sudo cat <<-EOF > /etc/sudoers.d/vagrant.conf
Cmnd_Alias VAGRANT_EXPORTS_ADD = /usr/bin/tee -a /etc/exports
Cmnd_Alias VAGRANT_NFSD = /sbin/nfsd restart
Cmnd_Alias VAGRANT_EXPORTS_REMOVE = /usr/bin/sed -E -e /*/ d -ibak /etc/exports
%admin ALL=(ALL) NOPASSWD: VAGRANT_EXPORTS_ADD, VAGRANT_NFSD, VAGRANT_EXPORTS_REMOVE
EOF
