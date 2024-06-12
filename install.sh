#!/bin/bash

export KUBEVIRT_RELEASE=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export K3S_VERSION=v1.28.7+k3s1
export CDI_TAG=$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)
export CDI_VERSION=$(echo ${CDI_TAG##*/})
export VIRTCTL_VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)

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

#Get virtualization status
sudo virt-host-validate qemu

#Disable apparmor (if enabled)
sudo systemctl stop apparmor
sudo systemctl disable apparmor

#Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin

#Install k3s kubernetes and set permissions
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION INSTALL_K3S_EXEC="--disable=traefik" sh -
sudo chmod 744 /etc/rancher/k3s/k3s.yaml
touch /var/lib/rancher/k3s/server/manifests/local-storage.yaml.skip

#Install multus
kubectl apply -f manifests/multus/multus-daemonset-thick.yml
#kubectl wait --for condition=Available daemonset.apps/kube-multus-ds -n kube-system --timeout=120s

#Install ingress-nginx
kubectl apply -f manifests/ingress-nginx/ingress-nginx.yaml

#Install longhorn
kubectl apply -f manifests/longhorn/longhorn.yml

#Install kubevirt
kubectl apply -f manifests/kubevirt/1-kubevirt-operator.yaml
kubectl apply -f manifests/kubevirt/2-kubevirt-cr.yaml
kubectl -n kubevirt wait kv kubevirt --for condition=Available --timeout=120s

#Install containerized data importer
kubectl apply -f manifests/cdi/1-cdi-operator.yaml
kubectl apply -f manifests/cdi/2-cdi-cr.yaml
kubectl apply -f manifests/cdi/3-cdi-uploadproxy-nodeport.yaml

#Install virtctl

wget https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-${VIRTCTL_VERSION}-linux-amd64
sudo install virtctl-${VIRTCTL_VERSION}-linux-amd64 /usr/local/bin/virtctl