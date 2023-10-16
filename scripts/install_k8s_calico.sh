#!/bin/bash

# A sudo check
check_sudo() {
  if [ [ "$(id -u)" -ne 0 ]]; then
    echo "Please run this script with sudo privileges."
    exit 1
  fi
}

# Install and configure containerd
install_containerd() {
  # Load containerd modules
  cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
  sudo modprobe overlay
  sudo modprobe br_netfilter

  # Set system configurations for Kubernetes networking
  cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sudo sysctl --system

  sudo apt-get update && sudo apt-get install -y containerd.io
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml
  sudo systemctl restart containerd
}

# Disable swap
disable_swap() {
  if [ -n "$(swapon --show)" ]; then
    echo "Disabling swap..."
    sudo swapoff -a
    echo "Commenting out the swap entry in /etc/fstab..."
    sudo sed -i '/ swap / s/^/#/' /etc/fstab
    echo "Swap is disabled."
    free -m
  else
    echo "Swap is already disabled."
  fi
}

# Install dependency packages for Kubernetes
install_k8s_dependencies() {
  sudo apt-get update
  sudo apt-get install -y apt-transport-https curl
}

# Add Kubernetes repository
add_k8s_repository() {
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
  sudo apt-get update
}

# Install and configure Kubernetes
install_k8s() {
  echo "Installing Kubernetes..."
  sudo apt-get update
  sudo apt-get install -y kubelet=1.27.0-00 kubeadm=1.27.0-00 kubectl=1.27.0-00
  sudo apt-mark hold kubeadm kubelet kubectl
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.27.0
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

# Install Calico as CNI
install_calico() {
  local calico_manifest_url="https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
  echo "Installing Calico..."
  if kubectl apply -f "$calico_manifest_url"; then
    echo "Calico CNI installed successfully!"
  else
    echo "Error: Failed to install Calico CNI."
    exit 1
  fi
}

# Print the join command of worker nodes
print_join_command() {
  echo "To join more worker nodes to the cluster, run this command on each node:"
  TOKEN=$(kubeadm token list | awk 'NR==2 {print $1}')
  HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  ENDPOINT=$(kubectl cluster-info | grep master | awk '{print $NF}')
  echo "kubeadm join $ENDPOINT --token $TOKEN --discovery-token-ca-cert-hash sha256:$HASH"
}

# Run the functions to install k8s with Calico
install_containerd
disable_swap
install_k8s_dependencies
add_k8s_repository
install_k8s
install_calico
print_join_command
