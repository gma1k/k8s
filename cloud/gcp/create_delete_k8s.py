#!/usr/bin/env python3

import os
import subprocess

def create_cluster():
  print("Please enter the following values separated by commas:")
  print("Project ID, cluster name, zone, number of nodes")
  input = input("-> ")

  values = input.split(",")
  if len(values) != 4:
    print("Invalid input format")
    exit(1)

  project = values[0]
  cluster = values[1]
  zone = values[2]
  nodes = values[3]

  print("Creating cluster...")
  subprocess.run(["gcloud", "container", "clusters", "create", cluster, "--project", project, "--zone", zone, "--num-nodes", nodes, "--quiet"])

  print(f"Cluster created: {cluster}")

def delete_cluster():
  print("Please enter the following values separated by commas:")
  print("Project ID, cluster name, zone")
  input = input("-> ")

  values = input.split(",")
  if len(values) != 3:
    print("Invalid input format")
    exit(1)

  project = values[0]
  cluster = values[1]
  zone = values[2]

  print("Deleting cluster...")
  subprocess.run(["gcloud", "container", "clusters", "delete", cluster, "--project", project, "--zone", zone, "--quiet"])

  print(f"Cluster deleted: {cluster}")

print("Please choose an option:")
print("1) Create a cluster")
print("2) Delete a cluster")
option = input("-> ")

if option == "1":
  create_cluster()
elif option == "2":
  delete_cluster()
else:
  print("Invalid option")
