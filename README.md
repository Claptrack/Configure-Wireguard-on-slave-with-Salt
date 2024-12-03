# Configure-Wireguard-on-slave-with-Salt

This project focuses on configuring a Wireguard VPN to a master and slave host using Salt. A typical use-case for setting up your own VPN would be to gain access to a computer or server in your home network, while you are outside your home network. In this project we are only creating a tunnel for access to the server, we are not routing all internet traffic via the server. We will leave that to the commercial VPN providers for now.

For this project I decided to use Vagrant and VirtualBox for an easy setup of two virtual hosts. The salt state-files in this project can be used to set up a VPN on any two computers that have salt installed. For convenience, I also installed `micro` on both the master and the slave.

I used the instructions on DigitalOcean's website as reference (steps 1, 2, 3, 6, 7 and 8): https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-debian-11. I reckoned the instructions would work just as well on Debian 12.
<br></br>

The goal was to "automate" the configuration on both the master and the slave as much as possible, and naturally to make the states idempotent. First there was one state file, for configuring the server. Then there was a second state file for configuring the peer. At some point the generated keys had to be exchanged between the hosts as well. Let's see how far we got...
<br></br>

## Requirements

This was done on a Lenovo L14 with AMD Ryzen, 256 GB SSD and 24 GB RAM running Debian 12. Software used: Vagrant, VirtualBox, Salt. All these should work with any amd64 architecture Win/Mac/Linux.
<br></br>

## Vagrantfile for two virtual hosts

### Creating the VM's with Vagrantfile
First, I created a new vagrantfile in my home directory for setting up the two hosts, master and slave.

![image](https://github.com/user-attachments/assets/0e01fdf3-d570-4718-afa7-46ee40c43340)
<br></br>

In addition to just setting up two hosts, this vagrantfile also installed `curl`, as well as `salt-master` and `salt-minion` on the corresponding VM's. The IP-address of the master was also added to the configuration file for the minion.

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

After running `vagrant up`, I connected to the master with command `vagrant ssh master`. 

![image](https://github.com/user-attachments/assets/2e809f72-5f5e-4967-a56e-638eefd37ddc)
<br></br>

## Testing Salt

### Testing the master-slave-architecture

I immediately tried to accept the pending keys from the slave, but no keys were pending. So I connected to the slave to stop and start the service.

    $ exit
    $ vagrant ssh slave1
    $ sudo systemctl stop salt-minion
    $ sudo systemctl start salt-minion
<br></br>

I did indeed try with just restarting salt-minion, but the keys were still not "pending" on the master. 

Then I went back to the master and did the same steps, just to be sure.

    $ exit
    $ vagrant ssh master
    $ sudo salt-key -A
<br></br>

## Salt state file to configure Wireguard on server

### Creating the state file

After accepting the key of the slave, I could start writing states.

I created a folder for the salt module and the `init.sls`.

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

I configured Wireguard to only use an IPv4 address. This will be the address of the Wireguard server.

![image](https://github.com/user-attachments/assets/7fc91f98-b2e5-4b2d-976c-f0ece27f0128)
<br></br>

This state file should get us to the point where wireguard is set up on the server. Let's try it out!
<br></br>

### Applying the states

Applying the state file and calling all slaves, since I only have one

    $ sudo salt '*' state.apply wg_install
<br></br>

All the states succeeded.

![image](https://github.com/user-attachments/assets/40f6185e-b553-48c7-bcda-75a5c714f038)
<br></br>

Let's look at some of the individual states' results:

First, the installation

![image](https://github.com/user-attachments/assets/a1953c37-c202-4033-8fa9-5103dd665475)
<br></br>

Copying the configuration file from the master

![image](https://github.com/user-attachments/assets/799a26a0-2632-4a74-bd82-f90d777b4923)
<br></br>

Generating the private key and changing permissions on the new file created

**Notice how I did not use `sudo tee` to output the privatekey to stdout, but instead just writing it to the file.**

![image](https://github.com/user-attachments/assets/8dd45657-4ea7-4628-b00d-30bbc4016046)
<br></br>

Generating the public key and copying the private key to `wg0.conf`

![image](https://github.com/user-attachments/assets/11e35d38-009e-47d6-a941-df7b107869b5)
<br></br>

And lastly, starting the service

![image](https://github.com/user-attachments/assets/5e07a587-819d-4efa-ad81-29f2fb510f48)
<br></br>



**Let's try that a couple more times**

![image](https://github.com/user-attachments/assets/c4f0f85d-64d2-41e8-bdda-3d121a147292)

![image](https://github.com/user-attachments/assets/43ae15a5-8c2a-4ad3-a5e6-677cc6539b1f)
<br></br>

Let's check the output of `/etc/wireguard/wg0.conf`

![image](https://github.com/user-attachments/assets/ff3918d1-5102-40d5-b0c0-626fd72ef1f9)
<br></br>

I was struggling to find a command that would append the private key after a certain string. At this point I was not sure If this needed to be fixed manually in the configuration file on the server.
<br></br>

## Configuring Wireguard on the peer

### Creating a state file and applying it locally

I decided to copy the existing state file to another module which I called `wg_local`. The idea was to use the state file to configure (almost) the same steps on the peer (master), and then just apply the state locally.

A few changes were made to the state file:

I created a new configuration file for the peer in `/srv/salt/wg_local`, so I had to change the source in the state file.

![image](https://github.com/user-attachments/assets/9615857b-c7f7-4017-8221-dda254faf48f)
<br></br>

At this point the configuration file included the address of the server, as well as the allowed IPv4 address range for the peer(s). The private and public keys would be appended to the end of the file to then be moved to the corresponding lines.

![image](https://github.com/user-attachments/assets/953061e1-620e-4e23-869d-c2f01bda9d7e)
<br></br>

I added an additional destination for the public key to be written to, since that will be needed for the server at a later stage

![image](https://github.com/user-attachments/assets/a87671b9-a2ec-4cc3-8fe7-62204dbc69f9)
<br></br>

Trying out the wg_local module locally:

A couple errors were raised

![image](https://github.com/user-attachments/assets/ddf355fe-b12a-465e-8f95-7017aac9cf3b)
<br></br>

I believe this issue was raised because I was trying to add output of `wg pubkey` to multiple files, so I changed that to `wg pubkey | sudo tee > [filename1] [filename2] > /dev/null`. I also changed the second destination of file to `/etc/wireguard/wg_last` (which is the module for copying the keys).

I applied another state that I created earlier (wg_remove) which removed the pkg installation as well as all files created. Then I applied the wg_local state again

![image](https://github.com/user-attachments/assets/b313a0c5-4f78-4592-b127-d5741bae41be)
<br></br>

And another

![image](https://github.com/user-attachments/assets/1c03d500-f9c3-41a9-be90-24a6343fbbe4)
<br></br>

**A quick recap:**

So far we have configured wireguard to run on the server. We have generated a key pair, and the private key is stored (on a new line) in the wireguard configuration file on the server.

We've also configured wireguard on the peer and generated a key pair. The private key is appended to the EOF in `wg0.conf`.
<br></br>

### Creating a third state file for copying the last keys

First I went to the `wg0.conf` on the peer, since the private key was on the last line in the configuration. I moved the key to the correct line in the configuration.

![image](https://github.com/user-attachments/assets/9ec69f60-4a8a-469c-a55f-9a39813d0778)
<br></br>

Then I created a new folder for the third and (hopefully) last module

![image](https://github.com/user-attachments/assets/a815d4ed-73cd-4383-942d-d96526f68bf4)
<br></br>

And a new state file, which included the following states







# References

How to set up Wireguard on Debian 12, DigitalOcean: https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-debian-11


