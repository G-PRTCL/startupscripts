#!/bin/bash
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
sudo docker run --env ghost_pass=$1 --cap-add=NET_ADMIN --device=/dev/net/tun -p 443:443/tcp saiguna/openvpn_focal:latest
