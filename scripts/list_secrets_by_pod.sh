#!/bin/bash

# This script lists Kubernetes Secrets currently in use by pods in a specified namespace.
# Usage:
#   ./script.sh
#   ./script.sh -t <namespace>

set -eu 

# List namespaces
list_namespaces() {
    kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | nl
}

# List secrets in use by pods in a given namespace, along with pod names
list_secrets_with_pods() {
    local namespace=$1
    pods=$(kubectl get pods -n "$namespace" -o json)
    secrets=$(echo "$pods" | jq -r '.items[] | select(.spec.containers[].env[]?.valueFrom.secretKeyRef.name != null) | .metadata.name as $pod | .spec.containers[].env[]?.valueFrom.secretKeyRef.name as $secret | "\($secret) \($pod)"' | sort | uniq)

    if [[ -z "$secrets" ]]; then
        echo "No secrets used by Pods in the current namespace: $namespace"
    else
        echo "Secrets and the Pods that use them in namespace: $namespace"
        echo "$secrets" | while read -r secret pod; do
            echo "Secret: $secret, Pod: $pod"
        done
    fi
}

# Main script
if [[ "$#" -eq 2 && "$1" == "-t" ]]; then
    namespace=$2
else
    echo "Available namespaces:"
    namespaces=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    echo "$namespaces" | nl
    echo
    read -p "Enter the namespace number: " namespace_number

    total_namespaces=$(echo "$namespaces" | wc -l)
    if [[ "$namespace_number" -lt 1 || "$namespace_number" -gt "$total_namespaces" ]]; then
        echo "Invalid namespace number. Please try again."
        exit 1
    fi

    namespace=$(echo "$namespaces" | sed -n "${namespace_number}p")
fi

echo "Listing secrets in use by pods in namespace: $namespace"
list_secrets_with_pods "$namespace"
