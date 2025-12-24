#!/bin/bash
set -euo pipefail

# List all namespaces
list_namespaces() {
	kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

# Get unused secrets
get_unused_secrets() {
	local namespace="$1"

	envSecrets=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.containers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null | xargs -n1 || true)
	envSecrets2=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.containers[*].envFrom[*].secretRef.name}' 2>/dev/null | xargs -n1 || true)
	volumeSecrets=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.volumes[*].secret.secretName}' 2>/dev/null | xargs -n1 || true)
	pullSecrets=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.imagePullSecrets[*].name}' 2>/dev/null | xargs -n1 || true)
	tlsSecrets=$(kubectl get ingress -n "$namespace" -o jsonpath='{.items[*].spec.tls[*].secretName}' 2>/dev/null | xargs -n1 || true)
	SASecrets=$(kubectl get secrets -n "$namespace" --field-selector=type=kubernetes.io/service-account-token -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | xargs -n1 || true)

	usedSecrets=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n" "$envSecrets" "$envSecrets2" "$volumeSecrets" "$pullSecrets" "$tlsSecrets" "$SASecrets" | grep -v '^$' | sort | uniq)
	allSecrets=$(kubectl get secrets -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | xargs -n1 | sort | uniq || true)

	if [[ -z "$allSecrets" ]]; then
		echo ""
		return
	fi

	unusedSecrets=$(diff <(echo "$usedSecrets") <(echo "$allSecrets") 2>/dev/null | grep '^>' | awk '{print $2}' || true)
	echo "$unusedSecrets"
}

# Delete unused secrets
delete_unused_secrets() {
	local namespace="$1"
	unusedSecrets=$(get_unused_secrets "$namespace")
	if [[ -z "$unusedSecrets" ]]; then
		echo "No unused secrets found in namespace $namespace."
		return
	fi

	echo "Unused secrets in namespace $namespace:"
	echo "$unusedSecrets"
	read -p "Do you want to delete these secrets? (y/n): " confirm
	if [[ "$confirm" == "y" ]]; then
		while IFS= read -r secret; do
			[[ -z "$secret" ]] && continue
			if ! kubectl delete secret "$secret" -n "$namespace" 2>/dev/null; then
				echo "Warning: Failed to delete secret $secret" >&2
			fi
		done <<<"$unusedSecrets"
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

case "$choice" in
1)
	echo "Available namespaces:"
	list_namespaces
	read -p "Enter the namespace: " namespace
	if ! kubectl get namespace "$namespace" &>/dev/null; then
		echo "Error: Namespace '$namespace' does not exist" >&2
		exit 1
	fi
	delete_unused_secrets "$namespace"
	;;
2)
	while IFS= read -r namespace; do
		[[ -z "$namespace" ]] && continue
		delete_unused_secrets "$namespace"
	done < <(list_namespaces)
	;;
3)
	exit 0
	;;
*)
	echo "Invalid choice, exiting."
	exit 1
	;;
esac
