#!/bin/bash

# Install Kubernetes
install_k8s() {
  echo "Installing Kubernetes..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
  kubectl version --client
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

# Install Cilium as network plugin
install_cilium() {
  echo "Installing Cilium..."
  curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
  sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
  rm cilium-linux-amd64.tar.gz{,.sha256sum}
  cilium install --version v1.14.2 --wait=false
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

# Run the functions to install k8s with cilium, podman, prometheus-grafana, keda and vault
install_k8s
install_podman
install_cilium
install_helm
install_prometheus
install_keda
install_vault
print_join_command
