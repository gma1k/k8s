#!/bin/bash
# Usage: ./upgrade_k8s.sh <node_name>

set -eu

# Prompt for yes/no confirmation
ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo "$REPLY" | tr '[:upper:]' '[:lower:]') in
        y|yes) echo "yes" ;;
        *) echo "no" ;;
    esac
}

# Prompt user for confirmation before proceeding
if [[ "no" == $(ask_yes_or_no "Are you sure you want to upgrade Kubernetes?") ]]; then
    echo "Upgrade cancelled."
    exit 1
fi

# Get current Kubernetes version
current_kube_version=$(kubeadm version -o short)
echo "Current Kubernetes version: $current_kube_version"

# Prompt user for desired Kubernetes versions
read -p "Enter the desired kubeadm version (e.g., 1.27.2): " KUBEADM_VERSION
read -p "Enter the desired kubelet version (e.g., 1.27.2): " KUBELET_VERSION
read -p "Enter the desired kubectl version (e.g., 1.27.2): " KUBECTL_VERSION

# Function to drain a node
drain_node() {
    NODE_NAME="$1"
    echo "Draining node $NODE_NAME"
    sudo kubectl drain "$NODE_NAME" --ignore-daemonsets
}

# Upgrade Kubernetes
upgrade_node() {
    echo "Upgrading kubeadm, kubelet, and kubectl..."
    sudo apt-mark unhold kubeadm kubelet kubectl && \
        sudo apt-get update && \
        sudo apt-get install -y \
            "kubeadm=$KUBEADM_VERSION" \
            "kubelet=$KUBELET_VERSION" \
            "kubectl=$KUBECTL_VERSION" && \
        sudo apt-mark hold kubeadm kubelet kubectl
    echo "Upgraded to versions:"
    sudo kubeadm version
}

# Uncordon the node
uncordon_node() {
    NODE_NAME="$1"
    echo "Bringing the node back online by marking it schedulable..."
    kubectl uncordon "$NODE_NAME"
}

# Main script
main() {
    NODE_NAME="$1"
    drain_node "$NODE_NAME"
    upgrade_node
    uncordon_node "$NODE_NAME"
}

main "$@"
