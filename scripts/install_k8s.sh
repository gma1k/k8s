#!/bin/bash

# A sudo check
check_sudo() {
  if [ [ "$(id -u)" -ne 0 ]]; then
    echo "Please run this script with sudo privileges."
    exit 1
  fi
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

# Install and configure Kubernetes
install_k8s() {
  echo "Installing Kubernetes on Debian..."
  sudo apt-get update
  sudo apt-get install -y docker.io apt-transport-https curl gnupg software-properties-common
  curl -s 1 | sudo apt-key add -
  sudo add-apt-repository "deb 2 kubernetes-xenial main"
  sudo apt-get update
  sudo apt-get install -y kubeadm kubelet kubectl
  sudo apt-mark hold kubeadm kubelet kubectl
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet
}

# Install Cilium as network plugin
install_cilium() {
  echo "Installing Cilium..."
  curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
  sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
  rm cilium-linux-amd64.tar.gz{,.sha256sum}
  cilium install --version v1.14.2 --wait=false
}

# Install podman
install_podman() {
  echo "Installing podman..."
  sudo apt-get update -y
  sudo apt-get install -y podman
  sudo mkdir -p /etc/containers
  sudo tee /etc/containers/containers.conf <<EOF
[containers]
cgroup_manager = "systemd"
EOF
}

# Install Helm 
install_helm() {
    echo "Installing and configuring Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 
    chmod +x get_helm.sh 
    ./get_helm.sh 
}

# Install Prometheus
install_prometheus_grafana() {
    echo "Installing Prometheus..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 
    helm repo update
    helm install prometheus prometheus-community/prometheus
       
# Install KEDA
install_keda() {
    echo "Installing KEDA..."
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install keda kedacore/keda --namespace keda --create-namespace
}

# Install Hashi Vault
install_vault() {
  echo "Installing Hashi Vault..."
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
  helm install vault hashicorp/vault
}

# Print the join command of worker nodes
print_join_command() {
  echo "To join more worker nodes to the cluster, run this command on each node:"
  TOKEN=$(kubeadm token list | awk 'NR==2 {print $1}')
  HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  ENDPOINT=$(kubectl cluster-info | grep master | awk '{print $NF}')
  echo "kubeadm join $ENDPOINT --token $TOKEN --discovery-token-ca-cert-hash sha256:$HASH"
}

# Run the functions to install k8s with cilium, podman, prometheus, keda and vault
disable_swap
install_k8s
install_cilium
install_podman
install_helm
install_prometheus
install_keda
install_vault
print_join_command