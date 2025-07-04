#!/bin/bash
set -eu

list_empty_namespaces() {
    kubectl get ns --no-headers -o custom-columns=":metadata.name" | while read -r namespace; do
        if kubectl get all -n "$namespace" 2>&1 | grep -q "No"; then
            echo "Empty namespace: $namespace"
        fi
    done
}

delete_empty_namespaces() {
    echo "Choose an option:"
    echo "1. Delete all empty namespaces"
    echo "2. Delete specific empty namespaces"
    read -p "Enter your choice: " choice

    case "$choice" in
        1)
            kubectl get ns --no-headers -o custom-columns=":metadata.name" | while read -r namespace; do
                if kubectl get all -n "$namespace" 2>&1 | grep -q "No"; then
                    kubectl delete namespace "$namespace"
                fi
            done
            ;;
        2)
            read -p "Enter namespaces to delete (comma-separated): " namespaces
            IFS=',' read -ra ns_array <<< "$namespaces"
            for ns in "${ns_array[@]}"; do
                kubectl delete namespace "$ns"
            done
            ;;
        *)
            echo "Invalid choice. Exiting."
            ;;
    esac
}

echo "Options Menu:"
echo "1. List empty namespaces"
echo "2. Delete empty namespaces"
read -p "Enter your choice: " main_choice

case "$main_choice" in
    1)
        list_empty_namespaces
        ;;
    2)
        delete_empty_namespaces
        ;;
    *)
        echo "Invalid choice. Exiting."
        ;;
esac
