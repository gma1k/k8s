#!/bin/bash

# Check if resource requests are defined for a pod
has_resource_requests() {
    local pod="$1"
    local namespace="$2"
    kubectl get pods "$pod" -n "$namespace" -o jsonpath='{.spec.containers[0].resources.requests}' >/dev/null 2>&1
}

declare -a pods_with_resource_requests
declare -a pods_without_resource_requests

# Fetch all namespaces
while read -r namespace; do
    while read -r pod; do
        if has_resource_requests "$pod" "$namespace"; then
            pods_with_resource_requests+=("$pod,$namespace")
        else
            pods_without_resource_requests+=("$pod,$namespace")
        fi
    done < <(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
done < <(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

echo "Pods With Resource Requests"
printf '%s\n' "${pods_with_resource_requests[@]}"

echo -e "\n=========\n"

echo "Pods Without Resource Requests"
printf '%s\n' "${pods_without_resource_requests[@]}"
