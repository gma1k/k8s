#!/bin/bash
set -euo pipefail

# Usage: ./get_pod_ip.sh [pod_name] [namespace]
# Example: ./get_pod_ip.sh pod-worker2 default

pod_name="${1:-pod-worker2}"
namespace="${2:-default}"

if ! kubectl get namespace "$namespace" &>/dev/null; then
	echo "Error: Namespace '$namespace' does not exist" >&2
	exit 1
fi

pod_ip=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")

if [[ -z "$pod_ip" ]]; then
	echo "Error: Pod '$pod_name' not found in namespace '$namespace' or has no IP assigned" >&2
	exit 1
fi

echo "$pod_ip"
