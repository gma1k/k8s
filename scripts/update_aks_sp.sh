#!/bin/bash

set -eu

# Check service principal expiration date
check_sp_expiration() {
    echo "Checking service principal expiration date..."
    read -p "Enter the AKS cluster name: " AKS_NAME
    read -p "Enter the resource group name: " RG_NAME
    SP_ID=$(az aks show --resource-group "$RG_NAME" --name "$AKS_NAME" --query servicePrincipalProfile.clientId --output tsv)
    az ad app credential list --id "$SP_ID" --query "[].endDateTime" --output tsv
}

# Reset service principal credentials
reset_sp_and_update_aks() {
    echo "Resetting expired service principal credentials..."
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
        2) reset_sp_and_update_aks ;;
        3) echo "Exiting. Goodbye!" && exit ;;
        *) echo "Invalid choice. Please select 1, 2, or 3." ;;
    esac
done
