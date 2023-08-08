#!/bin/bash

az group create --name aks-rg --location westeurope

az network vnet create --resource-group aks-rg --name aks-vnet --address-prefixes 10.0.0.0/8 --subnet-name aks-subnet --subnet-prefix 10.240.0.0/16

az ad sp create-for-rbac --skip-assignment --name aks-sp
AKS_SP_ID=$(az ad sp show --id http://aks-sp --query appId -o tsv)
AKS_SP_SECRET=$(az ad sp credential reset --name http://aks-sp --query password -o tsv)

AKS_SUBNET_ID=$(az network vnet subnet show --resource-group aks-rg --vnet-name aks-vnet --name aks-subnet --query id -o tsv)

az aks create --resource-group aks-rg --name aks-west-cluster --location westeurope --node-count 3 --min-count 1 --max-count 5 --enable-cluster-autoscaler --network-plugin azure --vnet-subnet-id $AKS_SUBNET_ID --service-principal $AKS_SP_ID --client-secret $AKS_SP_SECRET --enable-aad

az aks get-credentials --resource-group aks-rg --name aks-west-cluster

az group create --name aks-east-rg --location eastus

az network vnet create --resource-group aks-east-rg --name aks-east-vnet --address-prefixes 10.1.0.0/8 --subnet-name aks-east-subnet --subnet-prefix 10.241.0.0/16

AKS_EAST_SUBNET_ID=$(az network vnet subnet show --resource-group aks-east-rg --vnet-name aks-east-vnet --name aks-east-subnet --query id -o tsv)

az aks create --resource-group aks-east-rg --name aks-east-cluster --location eastus --node-count 3 --min-count 1 --max-count 5 --enable-cluster-autoscaler --network-plugin azure --vnet-subnet-id $AKS_EAST_SUBNET_ID --service-principal $AKS_SP_ID --client-secret $AKS_SP_SECRET

az aks get-credentials -g aks-east-rg -n aks-east-cluster

az aks list -o table
