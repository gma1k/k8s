#!/bin/bash
set -eu

check_azure_cli_version() {
	local required_version="2.52.0"
	local installed_version=$(az --version | grep -oE '([0-9]+\.[0-9]+\.[0-9]+)')

	if [[ "$(printf '%s\n' "$required_version" "$installed_version" | sort -V | head -n1)" != "$required_version" ]]; then
		echo "Azure CLI version $required_version or later is required."
		read -p "Do you want to update Azure CLI? (y/n): " upgrade_choice
		if [[ "$upgrade_choice" == [Yy]* ]]; then
			echo "Updating Azure CLI..."
			az upgrade --yes
			echo "Azure CLI has been updated."
		else
			echo "Please update Azure CLI manually and then run this script again."
			exit 1
		fi
	fi
}

validate_cluster_and_resource_group() {
	local cluster_name="$1"
	local resource_group="$2"

	if ! az aks show -n "$cluster_name" -g "$resource_group" &>/dev/null; then
		echo "Error: Cluster '$cluster_name' in resource group '$resource_group' not found."
		exit 1
	fi
}

update_cluster_to_cilium() {
	read -p "Enter your AKS cluster name: " cluster_name
	read -p "Enter the resource group name where the cluster is located: " resource_group

	validate_cluster_and_resource_group "$cluster_name" "$resource_group"

	if az aks update -n "$cluster_name" -g "$resource_group" --network-dataplane cilium; then
		echo "The Azure CNI on '$cluster_name' has been updated to use Cilium dataplane."
	else
		exit_code=$?
		echo "Failed to update the Azure CNI on '$cluster_name'. Exit code: $exit_code"
		exit $exit_code
	fi
}

main_menu() {
	echo "=== AKS Cluster Update Script ==="
	echo "1. Check Azure CLI version"
	echo "2. Update AKS cluster to use Cilium"
	echo "3. Exit"
	read -p "Enter your choice (1/2/3): " choice

	case "$choice" in
	1) check_azure_cli_version ;;
	2) update_cluster_to_cilium ;;
	3)
		echo "Exiting. Goodbye!"
		exit
		;;
	*) echo "Invalid choice. Please select 1, 2, or 3." ;;
	esac
}
