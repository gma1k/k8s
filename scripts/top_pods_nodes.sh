#!/bin/bash

# List Kubernetes namespaces
list_namespaces() {
    kubectl get namespaces
}

# Get top pods
top_pods() {
    read -p "Enter the namespace name: " namespace
    if kubectl get namespace "$namespace" &>/dev/null; then
        kubectl top pods -n "$namespace"
    else
        echo "Namespace '$namespace' does not exist."
    fi
}

# Get top nodes
top_nodes() {
    kubectl top nodes
}

# Main menu
echo "Choose an option:"
echo "1. List Kubernetes namespaces"
echo "2. Display top pods for a namespace"
echo "3. Display top nodes"

read -p "Enter your choice: " choice

case "$choice" in
    1) list_namespaces ;;
    2) top_pods ;;
    3) top_nodes ;;
    *) echo "Invalid choice. Please select a valid option." ;;
esac
