#!/bin/bash
# Usage: ./upgrade_k8s.sh <node_name>

set -euo pipefail

# Validate version format
validate_version() {
	local version="$1"
	if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "Error: Invalid version format. Expected format: X.Y.Z (e.g., 1.27.2)" >&2
		return 1
	fi
	return 0
}

# Prompt for yes/no confirmation
ask_yes_or_no() {
	read -p "$1 ([y]es or [N]o): "
	case $(echo "$REPLY" | tr '[:upper:]' '[:lower:]') in
	y | yes) echo "yes" ;;
	*) echo "no" ;;
	esac
}

# Check if node exists
check_node_exists() {
	local node_name="$1"
	if ! kubectl get node "$node_name" &>/dev/null; then
		echo "Error: Node '$node_name' does not exist" >&2
		exit 1
	fi
}

# Prompt user for confirmation before proceeding
if [[ "no" == $(ask_yes_or_no "Are you sure you want to upgrade Kubernetes?") ]]; then
	echo "Upgrade cancelled."
	exit 1
fi

# Validate node name provided
if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <node_name>"
	exit 1
fi

NODE_NAME="$1"
check_node_exists "$NODE_NAME"

# Get current Kubernetes version
current_kube_version=$(kubeadm version -o short 2>/dev/null || echo "Unknown")
echo "Current Kubernetes version: $current_kube_version"

# Prompt user for desired Kubernetes versions
read -p "Enter the desired kubeadm version (e.g., 1.27.2): " KUBEADM_VERSION
if ! validate_version "$KUBEADM_VERSION"; then
	exit 1
fi

read -p "Enter the desired kubelet version (e.g., 1.27.2): " KUBELET_VERSION
if ! validate_version "$KUBELET_VERSION"; then
	exit 1
fi

read -p "Enter the desired kubectl version (e.g., 1.27.2): " KUBECTL_VERSION
if ! validate_version "$KUBECTL_VERSION"; then
	exit 1
fi

# Function to drain a node
drain_node() {
	local node_name="$1"
	echo "Draining node $node_name"
	if ! sudo kubectl drain "$node_name" --ignore-daemonsets --delete-emptydir-data --timeout=300s; then
		echo "Error: Failed to drain node $node_name" >&2
		exit 1
	fi
}

# Upgrade Kubernetes
upgrade_node() {
	echo "Upgrading kubeadm, kubelet, and kubectl..."
	if ! sudo apt-mark unhold kubeadm kubelet kubectl; then
		echo "Warning: Failed to unhold packages (may not be held)" >&2
	fi

	if ! sudo apt-get update; then
		echo "Error: Failed to update package list" >&2
		exit 1
	fi

	if ! sudo apt-get install -y \
		"kubeadm=$KUBEADM_VERSION" \
		"kubelet=$KUBELET_VERSION" \
		"kubectl=$KUBECTL_VERSION"; then
		echo "Error: Failed to install Kubernetes packages" >&2
		exit 1
	fi

	if ! sudo apt-mark hold kubeadm kubelet kubectl; then
		echo "Warning: Failed to hold packages" >&2
	fi

	echo "Upgraded to versions:"
	sudo kubeadm version
}

# Uncordon the node
uncordon_node() {
	local node_name="$1"
	echo "Bringing the node back online by marking it schedulable..."
	if ! kubectl uncordon "$node_name"; then
		echo "Error: Failed to uncordon node $node_name" >&2
		exit 1
	fi
}

# Main script
drain_node "$NODE_NAME"
upgrade_node
uncordon_node "$NODE_NAME"
