#!/bin/bash
# Script to test ingress
set -euf -o pipefail

# Retrieve ingress hostnames
get_ingress_hostnames() {
	kubectl get ing --all-namespaces | tail -n +2 | awk '{print $3}' | cut -d',' -f1
}

# Validate hostname format
validate_hostname() {
	local hostname="$1"
	if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]] && [[ ! "$hostname" =~ ^[0-9.]+$ ]]; then
		return 1
	fi
	return 0
}

# Check ingress endpoints
check_ingress_endpoints() {
	local hostname="$1"
	if ! validate_hostname "$hostname"; then
		echo "Warning: Invalid hostname format: $hostname" >&2
		return 1
	fi
	echo "Checking $hostname.."
	curl -sLI -w "HTTP Response: %{http_code}\n" "https://$hostname" -o /dev/null || true
	echo ""
}

# Process ingress endpoints
process_ingress_endpoints() {
	local ingress_list=($(get_ingress_hostnames))

	for ingress in "${ingress_list[@]}"; do
		check_ingress_endpoints "$ingress"
	done
}
