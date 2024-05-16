#!/bin/bash

#Install tools 
if command -v apt-get > /dev/null 2>&1; then
    #Running on apt-based system
    sudo apt-get update
    sudo apt-get install -y bridge-utils net-tools network-manager git qemu-kvm libvirt-daemon-system libvirt-clients
    sudo systemctl enable libvirtd
    sudo systemctl start libvirtd
    
elif command -v dnf > /dev/null 2>&1; then
    #Running on dnf-based system
    sudo dnf update -y
    sudo dnf install -y bridge-utils net-tools git @virtualization
    sudo systemctl enable libvirtd
    sudo systemctl start libvirtd    
else
    echo "No compatible package manager found."
    exit 1
fi

#Install k3sup
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/

#Create bridges
sudo nmcli con add type bridge con-name brdmz ifname brdmz
sudo nmcli con up brdmz

sudo nmcli con add type bridge con-name brlan ifname brlan
sudo nmcli con up brlan

#Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin

#Install k3s kubernetes
k3sup install --local --no-extras --k3s-version $K3S_VERSION --k3s-extra-args '--write-kubeconfig-mode=644 --flannel-backend=wireguard-native'
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
sleep 10

#Install multus
kubectl apply -f manifests/multus/multus-daemonset-thick.yml


