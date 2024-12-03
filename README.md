# Configure-Wireguard-on-slave-with-Salt

This project focuses on configuring a Wireguard VPN to a master and slave host using Salt. A typical use-case for setting up your own VPN would be to gain access to a computer or server in your home network, while you are outside your home network. For this project I decided to use Vagrant and VirtualBox for an easy setup of two virtual hosts. The salt state-files in this project can be used to set up a VPN on any two computers that have salt installed. For convenience, I also installed `micro` on both the master and the slave.

I used the instructions on DigitalOcean's website as reference: https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-debian-11. I reckoned the instructions would work just as well on Debian 12.
<br></br>

## Requirements

This was done on a Lenovo L14 with AMD Ryzen, 256 GB SSD and 24 GB RAM running Debian 12. Software used: Vagrant, VirtualBox, Salt. All these should work with any amd64 architecture Win/Mac/Linux.
<br></br>

## Vagrantfile for two virtual hosts

First, I created a new vagrantfile in my home directory for setting up the two hosts, master and slave.

![image](https://github.com/user-attachments/assets/0e01fdf3-d570-4718-afa7-46ee40c43340)
<br></br>

In addition to just setting up two hosts, this vagrantfile also installed `curl`, as well as salt-master and salt-minion on the corresponding VM's. The IP-address of the master was also added to the configuration file for the minion.

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

After running `vagrant up`, I connected to the master with command `vagrant ssh master`. I immediately tried to accept the pending keys from the slave, but no keys were pending. So I connected to the slave to stop and start the service.

    $ exit
    $ vagrant ssh slave1
    $ sudo systemctl stop salt-minion
    $ sudo systemctl start salt-minion

I did indeed try with just restarting salt-minion, but the keys were still not "pending" on the master. 

Then I went back to the master and did the same steps, just to be sure.

    $ exit
    $ vagrant ssh master
    $ sudo salt-key -A


![image](https://github.com/user-attachments/assets/2e809f72-5f5e-4967-a56e-638eefd37ddc)
<br></br>

The next step was to create a folder for the salt module and the `init.sls`.

    $ sudo mkdir /srv/salt/wg_install
    $ cd /srv/salt/wg_install
    $ sudo micro init.sls
<br></br>

I added all the steps from installing wireguard to creating the keypair and adding the private key to the wireguard configuration file. To make sure these states would be idempotent, I added some conditions for some of the states.

A quick explanation of the states:

1. Install wireguard
2. Copy configuration file from master (only if not already present)
3. Generate private key (only if not already present)
4. Change permissions on the file `private.key` (only if private key was generated in previous state)
5. Generate public key from private key and overwrite output to possibly existing file
6. Append the private key to wg0.conf EOF
7. Start service with wg0 as the interface

![image](https://github.com/user-attachments/assets/ca67056e-e6e4-49a3-9e96-58abebb3e73c)
<br></br>

Below is a view of the file `wg0.conf` which was created on the master host

![image](https://github.com/user-attachments/assets/7fc91f98-b2e5-4b2d-976c-f0ece27f0128)
<br></br>

This state file should get us to the point where wireguard is set up on the server. Let's try it out!

Applying the state file and calling all slaves, since I only have one

    $ sudo salt '*' state.apply wg_install


All the states succeeded.

![image](https://github.com/user-attachments/assets/40f6185e-b553-48c7-bcda-75a5c714f038)
<br></br>


# References

How to set up Wireguard on Debian 12, DigitalOcean: https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-debian-11


