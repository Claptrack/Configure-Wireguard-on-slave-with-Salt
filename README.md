# Configure-Wireguard-on-slave-with-Salt

This project focuses on configuring a Wireguard VPN to a master and slave host using Salt. A typical use-case for setting up your own VPN would be to gain access to a computer or server in your home network, while you are outside your home network. For this project I decided to use Vagrant and VirtualBox for an easy setup of two virtual hosts. The salt state-files in this project can be used to set up a VPN on any two computers that have salt installed.

## Vagrantfile for two virtual hosts

