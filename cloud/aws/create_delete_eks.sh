#!/bin/bash

create_cluster() {
  echo "Please enter the following values separated by commas:"
  echo "Cluster name, region, node type"
  read -p "-> " input

  IFS=',' read -r cluster region node <<< "$input"

  if [ -z "$cluster" ] || [ -z "$region" ] || [ -z "$node" ]; then
    echo "Invalid input format"
    exit 1
  fi

  echo "Creating cluster..."
  aws eks create-cluster --name "$cluster" --region "$region" --nodegroup-name "$cluster-nodes" --node-type "$node" --nodes 2

  echo "Cluster created: $cluster"
}

delete_cluster() {
  echo "Please enter the following values separated by commas:"
  echo "Cluster name, region"
  read -p "-> " input

  IFS=',' read -r cluster region <<< "$input"

  if [ -z "$cluster" ] || [ -z "$region" ]; then
    echo "Invalid input format"
    exit 1
  fi

  echo "Deleting cluster..."
  aws eks delete-cluster --name "$cluster" --region "$region"

  echo "Cluster deleted: $cluster"
}

echo "Please choose an option:"
echo "1) Create a cluster"
echo "2) Delete a cluster"
read -p "-> " option

case $option in
  1) create_cluster ;;
  2) delete_cluster ;;
  *) echo "Invalid option" ;;
esac
