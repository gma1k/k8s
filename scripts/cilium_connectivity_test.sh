#!/bin/bash
set -euf -o pipefail

# Test all connectivities
test_all_connectivity() {
  echo "Testing all connectivities..."
  cilium connectivity test
  echo "** Results: **"
  results=$(cilium connectivity test 2>&1)
  echo "$results"
  if [[ $? -eq 0 ]]; then
    echo "All connectivities passed!"
  else
    echo "Failed to test all connectivities!"
    exit 1
  fi
}

# Test specific connectivity
test_specific_connectivity() {
  echo "Enter the name of the specific connectivity test: "
  read -r test_name
  if [[ -z "$test_name" ]]; then
    echo "Error: Please enter a valid test name."
    exit 1
  fi
  echo "Testing connectivity for '$test_name'..."
  cilium connectivity test --test "$test_name"
  echo "** Results: **"
  results=$(cilium connectivity test --test "$test_name" 2>&1)
  echo "$results"
  if [[ $? -eq 0 ]]; then
    echo "Connectivity test for '$test_name' passed!"
  else
    echo "Failed to test connectivity for '$test_name'!"
    exit 1
  fi
}

# Menu options
echo "Select an option:"
echo "  1) Test all connectivities"
echo "  2) Test specific connectivity"
read -r choice

# Process user choice
if [[ $choice -eq 1 ]]; then
  test_all_connectivity
elif [[ $choice -eq 2 ]]; then
  test_specific_connectivity
else
  echo "Invalid choice. Please enter 1 or 2."
  exit 1
fi
