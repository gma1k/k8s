#!/bin/bash

# A sudo check
check_sudo() {
  if [ [ "$(id -u)" -ne 0 ]]; then
    echo "Please run this script with sudo privileges."
    exit 1
  fi
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

# Run the functions to install k8s with cilium, podman, prometheus, keda and vault
install_podman
install_helm
install_prometheus
install_keda
install_vault
