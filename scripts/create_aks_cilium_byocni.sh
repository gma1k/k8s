#!/bin/bash

# Add AKS extension
add_aks_extension() {
	az extension add --name aks-preview
	az extension update --name aks-preview
}

# Register AKS feature
register_aks_feature() {
	az feature register --namespace "Microsoft.ContainerService" --name "KubeProxyConfigurationPreview"
	az provider register --namespace Microsoft.ContainerService
}

# Create a resource group
create_resource_group() {
	az group create --name "$resource_group" --location $location
}

# Create a virtual network
create_virtual_network() {
	echo "Creating virtual network $vnet_name..."
	az network vnet create -g "$resource_group" --location "$location" \
		--name "$vnet_name" --address-prefixes "$vnetAddressPrefix" --subnet-name "$subnet_name" -o none
	az network vnet subnet create -g "$resource_group" --vnet-name "$vnet_name" \
		--name nodesubnet --address-prefixes "$nodesubnetAddressPrefix" -o none
	az network vnet subnet create -g "$resource_group" --vnet-name "$vnet_name" \
		--name podsubnet --address-prefixes "$podsubnetAddressPrefix" -o none
}

# Create an AKS cluster
create_aks_cluster() {
	az aks create --resource-group "$resource_group" --name "$cluster_name" --location "$location" --network-plugin none --vnet-subnet-id "/subscriptions/$subscriptionId/resourceGroups/$resource_group/providers/Microsoft.Network/virtualNetworks/$vnet_name/subnets/$subnet_name"
}

# Install Helm
install_helm() {
	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
	chmod +x get_helm.sh
	./get_helm.sh
}

# Configure Helm
configure_helm() {
	kubectl create serviceaccount tiller --namespace kube-system
	kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	helm init --service-account tiller
}

# Install Cilium
install_cilium() {
	helm install cilium cilium/cilium --version 1.14.0 \
		--namespace kube-system \
		--set kubeProxyReplacement=true \
		--set k8sServiceHost="$api_server_ip" \
		--set k8sServicePort="$api_server_port" \
		--set aksbyocni.enabled=true \
		--set nodeinit.enabled=true \
		--set hubble.enabled=true
}

# Main script
add_aks_extension
register_aks_feature

read -p "Enter a unique resource group name: " resource_group
read -p "Enter a unique AKS cluster name: " cluster_name
read -p "Enter location: " location
read -p "Enter subscription ID: " subscriptionId
read -p "Enter a VNet name: " vnet_name
read -p "Enter a subnet name: " subnet_name
read -p "Enter vnet address prefix (e.g., 10.0.0.0/8): " vnetAddressPrefix
read -p "Enter nodesubnet address prefix (e.g., 10.240.0.0/16): " nodesubnetAddressPrefix
read -p "Enter podsubnet address prefix (e.g., 10.241.0.0/16): " podsubnetAddressPrefix

create_resource_group "$resource_group"
create_virtual_network "$resource_group" "$vnet_name" "$subnet_name"
create_aks_cluster "$resource_group" "$cluster_name" "$vnet_name" "$subnet_name"
install_helm
configure_helm

# Get API server IP and port
api_server_ip=$(kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}' | cut -d':' -f2 | cut -d'/' -f3)
api_server_port=$(kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}' | cut -d':' -f3)

install_cilium "$api_server_ip" "$api_server_port"

echo "AKS cluster with Cilium CNI has been set up successfully!"
