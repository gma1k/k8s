#!/bin/bash
set -euo pipefail

# List namespaces
list_namespaces() {
	kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
}

# Test ingress with curl
test_ingress() {
	local namespace="$1"
	local ingress_host

	if ! kubectl get namespace "$namespace" &>/dev/null; then
		echo "Error: Namespace '$namespace' does not exist" >&2
		return 1
	fi

	# Get ingress details for the specified namespace
	ingress_host=$(kubectl get ingress -n "$namespace" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")

	if [[ -n "$ingress_host" ]]; then
		echo "Testing ingress for namespace $namespace (Host: $ingress_host)"

		# Check if ingress uses HTTPS
		if kubectl get ingress -n "$namespace" -o jsonpath='{.spec.tls[0].hosts[0]}' >/dev/null 2>&1; then
			curl -kL "https://$ingress_host" || true
		else
			curl -L "http://$ingress_host" || true
		fi
	else
		echo "No ingress found for namespace $namespace."
	fi
}

# Main menu
echo "Choose an option:"
echo "1. Test ingress on all namespaces"
echo "2. Test ingress on a specific namespace"
read -p "Enter your choice (1 or 2): " user_choice

case "$user_choice" in
1)
	echo "Testing ingress on all namespaces:"
	while IFS= read -r ns; do
		[[ -z "$ns" ]] && continue
		test_ingress "$ns"
	done < <(list_namespaces)
	;;
2)
	echo "Available namespaces:"
	list_namespaces
	read -p "Enter the namespace to test ingress: " chosen_namespace
	if [[ -z "$chosen_namespace" ]]; then
		echo "Error: Namespace cannot be empty" >&2
		exit 1
	fi
	test_ingress "$chosen_namespace"
	;;
*)
	echo "Invalid choice. Exiting."
	exit 1
	;;
esac
