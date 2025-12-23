#!/bin/bash

# Create a resource group
create_resource_group() {
	echo "Creating resource group $resourceGroupName..."
	az group create --name "$resourceGroupName" --location "$location"
}

# Create a virtual network
create_virtual_network() {
	echo "Creating virtual network $vnetName..."
	az network vnet create -g "$resourceGroupName" --location "$location" \
		--name "$vnetName" --address-prefixes "$vnetAddressPrefix" -o none
	az network vnet subnet create -g "$resourceGroupName" --vnet-name "$vnetName" \
		--name nodesubnet --address-prefixes "$nodesubnetAddressPrefix" -o none
	az network vnet subnet create -g "$resourceGroupName" --vnet-name "$vnetName" \
		--name podsubnet --address-prefixes "$podsubnetAddressPrefix" -o none
}

# Create an AKS cluster with Azure CNI Overlay networking
create_aks_overlay() {
	echo "Creating AKS cluster with Azure CNI Overlay networking..."
	az aks create -n "$clusterName" -g "$resourceGroupName" -l "$location" \
		--network-plugin azure --network-plugin-mode overlay \
		--pod-cidr 192.168.0.0/16 --network-dataplane cilium
}

# Create an AKS cluster with Azure CNI using a virtual network
create_aks_vnet() {
	echo "Creating AKS cluster with Azure CNI using a virtual network..."
	az aks create -n "$clusterName" -g "$resourceGroupName" -l "$location" \
		--max-pods 250 --network-plugin azure \
		--vnet-subnet-id "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/nodesubnet" \
		--pod-subnet-id "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/podsubnet" \
		--network-dataplane cilium
}

# Main script
echo "Choose an option:"
echo "1. Assign IP addresses from an overlay network"
echo "2. Assign IP addresses from a virtual network"
read -p "Enter your choice (1 or 2): " option

case "$option" in
1)
	read -p "Enter AKS cluster name: " clusterName
	read -p "Enter resource group name: " resourceGroupName
	read -p "Enter location: " location
	if [[ -z "$clusterName" || -z "$resourceGroupName" || -z "$location" ]]; then
		echo "Error: All input fields are required."
		exit 1
	fi
	create_resource_group
	create_aks_overlay
	;;
2)
	read -p "Enter AKS cluster name: " clusterName
	read -p "Enter resource group name: " resourceGroupName
	read -p "Enter location: " location
	read -p "Enter subscription ID: " subscriptionId
	read -p "Enter virtual network name: " vnetName
	read -p "Enter virtual network address prefix (e.g., 10.0.0.0/8): " vnetAddressPrefix
	read -p "Enter nodesubnet address prefix (e.g., 10.240.0.0/16): " nodesubnetAddressPrefix
	read -p "Enter podsubnet address prefix (e.g., 10.241.0.0/16): " podsubnetAddressPrefix
	if [[ -z "$clusterName" || -z "$resourceGroupName" || -z "$location" || -z "$subscriptionId" || -z "$vnetName" || -z "$vnetAddressPrefix" || -z "$nodesubnetAddressPrefix" || -z "$podsubnetAddressPrefix" ]]; then
		echo "Error: All input fields are required."
		exit 1
	fi
	create_resource_group
	create_virtual_network
	create_aks_vnet
	;;
*)
	echo "Invalid choice. Please select 1 or 2."
	;;
esac
