#!/bin/bash
set -eu

# List all namespaces
list_namespaces() {
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

# Get unused secrets
get_unused_secrets() {
    local namespace=$1

    envSecrets=$(kubectl get pods -n $namespace -o jsonpath='{.items[*].spec.containers[*].env[*].valueFrom.secretKeyRef.name}' | xargs -n1)
    envSecrets2=$(kubectl get pods -n $namespace -o jsonpath='{.items[*].spec.containers[*].envFrom[*].secretRef.name}' | xargs -n1)
    volumeSecrets=$(kubectl get pods -n $namespace -o jsonpath='{.items[*].spec.volumes[*].secret.secretName}' | xargs -n1)
    pullSecrets=$(kubectl get pods -n $namespace -o jsonpath='{.items[*].spec.imagePullSecrets[*].name}' | xargs -n1)
    tlsSecrets=$(kubectl get ingress -n $namespace -o jsonpath='{.items[*].spec.tls[*].secretName}' | xargs -n1)
    SASecrets=$(kubectl get secrets -n $namespace --field-selector=type=kubernetes.io/service-account-token -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | xargs -n1)

    usedSecrets=$(echo "$envSecrets\n$envSecrets2\n$volumeSecrets\n$pullSecrets\n$tlsSecrets\n$SASecrets" | sort | uniq)
    allSecrets=$(kubectl get secrets -n $namespace -o jsonpath='{.items[*].metadata.name}' | xargs -n1 | sort | uniq)

    unusedSecrets=$(diff <(echo "$usedSecrets") <(echo "$allSecrets") | grep '>' | awk '{print $2}')
    echo "$unusedSecrets"
}

# Delete unused secrets
delete_unused_secrets() {
    local namespace=$1
    unusedSecrets=$(get_unused_secrets $namespace)
    if [ -z "$unusedSecrets" ]; then
        echo "No unused secrets found in namespace $namespace."
        return
    fi

    echo "Unused secrets in namespace $namespace:"
    echo "$unusedSecrets"
    read -p "Do you want to delete these secrets? (y/n): " confirm
    if [ "$confirm" == "y" ]; then
        for secret in $unusedSecrets; do
            kubectl delete secret $secret -n $namespace
        done
        echo "Unused secrets deleted."
    else
        echo "Deletion aborted."
    fi
}

# Menu
echo "Select an option:"
echo "1) Clean up unused secrets in a specific namespace"
echo "2) Clean up unused secrets in all namespaces"
echo "3) Exit"
read -p "Enter your choice: " choice

case $choice in
    1)
        echo "Available namespaces:"
        list_namespaces
        read -p "Enter the namespace: " namespace
        delete_unused_secrets $namespace
        ;;
    2)
        for namespace in $(list_namespaces); do
            delete_unused_secrets $namespace
        done
        ;;
    3)
        exit 0
        ;;
    *)
        echo "Invalid choice, exiting."
        ;;
esac
