#!/bin/bash

# This script accepts 2 parameters
# 1) securely generated password
# 2) self-destruct timer

sudo su
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
 "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null:q

#install pre requs and Docker
sudo apt-get update
sudo apt-get -y -q install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    docker-ce \
    docker-ce-cli \
    containerd.io
 
# Testing using parameter as environment variable in container.
sudo docker run --env ghost_pass=$1 --env self_destruct_time=$2 --cap-add=NET_ADMIN --device=/dev/net/tun -p 443:443/tcp saiguna/openvpn_focal:26Oct &
#install AZ CLI to run self-destroy
curl -LsS https://aka.ms/InstallAzureCLIDeb | bash
rm -rf /var/lib/apt/lists/*
# Shut down after time alloted + 80 sec buffer
sleep $(($2+80))
az login --identity # login as system identity
az group delete --resource-group $3 --yes # delete resource group
#shutdown -h # do not shutdown - self delete
