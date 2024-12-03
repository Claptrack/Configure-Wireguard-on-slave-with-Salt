# Configure-Wireguard-on-slave-with-Salt

This project focuses on configuring a Wireguard VPN to a master and slave host using Salt. A typical use-case for setting up your own VPN would be to gain access to a computer or server in your home network, while you are outside your home network. For this project I decided to use Vagrant and VirtualBox for an easy setup of two virtual hosts. The salt state-files in this project can be used to set up a VPN on any two computers that have salt installed.

## Requirements

This was done on a Lenovo L14 with AMD Ryzen running Debian 12. Software used: Vagrant, VirtualBox, Salt. All these should work with any amd64 architecture Win/Mac/Linux.


## Vagrantfile for two virtual hosts

First, I created a new Vagrantfile in my home directory for setting up the two hosts, master and slave.

In addition to jsut setting up two hosts, this vagrantfile also installs salt-master and salt-minion. After running `vagrant up`, 

```
$minion = <<MINION
sudo apt-get update
sudo apt-get -y install curl
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | sudo tee /etc/apt/keyrings/salt-archive-keyring.pgp
sudo curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | sudo tee /etc/apt/sources.list.d/salt.sources
sudo apt-get update
sudo apt-get -y install salt-minion
echo "master: 192.168.56.102">/etc/salt/minion
sudo systemctl restart salt-minion
MINION

$master = <<MASTER
sudo apt-get update
sudo apt-get -y install curl
sudo curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | sudo tee /etc/apt/keyrings/salt-archive-keyring.pgp
sudo curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | sudo tee /etc/apt/sources.list.d/salt.sources
sudo apt-get update
sudo apt-get -y install salt-master
MASTER

Vagrant.configure("2") do |config|
	config.vm.box = "debian/bookworm64"

	config.vm.define "slave1" do |slave1|
	    slave1.vm.provision :shell, inline: $minion
		slave1.vm.hostname = "slave1"
		slave1.vm.network "private_network", ip: "192.168.56.101"
	end

	config.vm.define "master", primary: true do |master|
		master.vm.provision :shell, inline: $master
		master.vm.hostname = "master"
		master.vm.network "private_network", ip: "192.168.56.102"
	end
	
end
```
<br></br>


