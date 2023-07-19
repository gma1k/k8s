#!/bin/bash

create_cluster() {
  echo "Please enter the following values separated by commas:"
  echo "Project ID, cluster name, zone, number of nodes"
  read -p "-> " input

  IFS=',' read -r project cluster zone nodes <<< "$input"

  if [ -z "$project" ] || [ -z "$cluster" ] || [ -z "$zone" ] || [ -z "$nodes" ]; then
    echo "Invalid input format"
    exit 1
  fi

  echo "Creating cluster..."
  gcloud container clusters create "$cluster" --project "$project" --zone "$zone" --num-nodes "$nodes" --quiet

  echo "Cluster created: $cluster"
}

delete_cluster() {
  echo "Please enter the following values separated by commas:"
  echo "Project ID, cluster name, zone"
  read -p "-> " input

  IFS=',' read -r project cluster zone <<< "$input"

  if [ -z "$project" ] || [ -z "$cluster" ] || [ -z "$zone" ]; then
    echo "Invalid input format"
    exit 1
  fi

  echo "Deleting cluster..."
  gcloud container clusters delete "$cluster" --project "$project" --zone "$zone" --quiet

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
