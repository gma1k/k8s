#!/bin/bash

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
  local test_name="$1"
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

# Parse options
while getopts ":a:t:" opt; do
  case $opt in
    a | --all)
      test_all_connectivity
      exit 0
      ;;
    t | --test)
      test_name="$OPTARG"
      if [[ -z "$test_name" ]]; then
        echo "Error: Please provide a test name with -t option."
        exit 1
      fi
      test_specific_connectivity "$test_name"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

# No options provided, default to testing all connectivities
test_all_connectivity
