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

# pull the custom openvpn image
 #sudo docker pull saiguna/openvpn_bionic
 docker pull saiguna/u2004:working
 #run open vpn image
 #sudo docker run --cap-add=NET_ADMIN -p 1194:1194/udp -p 943:943/tcp -p 9443:9443/tcp saiguna/openvpn_bionic
 sudo docker run --cap-add=NET_ADMIN -p 1194:1194/udp -p 943:943/tcp -p 9443:9443/tcp saiguna/u2004:working
