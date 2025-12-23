#!/bin/bash

set -eu

# Check service principal expiration date
check_sp_expiration() {
	echo "Checking service principal expiration date..."
	until [ -n "$AKS_NAME" ]; do
		read -p "Enter AKS cluster name: " AKS_NAME
		[ -z "$AKS_NAME" ] && echo "AKS cluster name cannot be empty. Please enter a valid name."
	done

	until [ -n "$RG_NAME" ]; do
		read -p "Enter the resource group name: " RG_NAME
		[ -z "$RG_NAME" ] && echo "Resource group name cannot be empty. Please enter a valid name."
	done

	SP_ID=$(az aks show --resource-group "$RG_NAME" --name "$AKS_NAME" --query servicePrincipalProfile.clientId --output tsv)
	az ad app credential list --id "$SP_ID" --query "[].endDateTime" --output tsv
}

# Reset service principal credentials
reset_sp() {
	echo "Resetting expired service principal credentials..."
	SP_SECRET=$(az ad app credential reset --id "$SP_ID" --query password -o tsv)
	az ad sp credential reset --id "$SP_ID" --password "$SP_SECRET"
}

# Main menu
while true; do
	echo "Select an option:"
	echo "1. Check service principal expiration date"
	echo "2. Reset service principal and update AKS cluster"
	echo "3. Exit"
	read -p "Enter your choice: " choice

	case "$choice" in
	1) check_sp_expiration ;;
	2) reset_sp ;;
	3) echo "Exiting. Goodbye!" && exit ;;
	*) echo "Invalid choice. Please select 1, 2, or 3." ;;
	esac
done
