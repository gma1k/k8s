#!/bin/bash
set -eu

# Check if Helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        echo "Error: Helm is not installed."
        exit 1
    fi
}

# Add Cilium Helm repository
add_cilium_repo() {
    helm repo add cilium https://helm.cilium.io/
    helm repo update
}

# Install Cilium
install_cilium() {
    helm install cilium cilium/cilium \
        --version 1.16.1 \
        --namespace kube-system \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=true \
        --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
        --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
        --set cgroup.autoMount.enabled=false \
        --set cgroup.hostRoot=/sys/fs/cgroup \
        --set k8sServiceHost=localhost \
        --set k8sServicePort=7445
}

# Main functions
check_helm
add_cilium_repo
install_cilium
