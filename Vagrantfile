# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = '2'

VM_NAME = "snowwhite"
MEMORY_SIZE_MB = 1024
NUMBER_OF_CPUS = 2

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = 'ubuntu/focal64'

  config.vm.define "snowwhite" do |snowwhite|
    snowwhite.vm.provider "virtualbox" do |v|
      v.name = VM_NAME
      v.customize ["modifyvm", :id, "--memory", MEMORY_SIZE_MB]
      v.customize ["modifyvm", :id, "--cpus", NUMBER_OF_CPUS]
    end
    snowwhite.vm.network :forwarded_port, host: 4000, guest: 4000
    snowwhite.vm.network :forwarded_port, host: 5432, guest: 5432
    snowwhite.vm.provision :shell, path: "bootstrap.sh"
  end
end
