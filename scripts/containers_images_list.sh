#!/bin/bash
# Argument 1: Task -t
# Argument 2: Task number (1, 2, 3, 4)
# Example 1: ./kubectl_list_containers_images.sh -t 1
# Example 2: ./kubectl_list_containers_images.sh to list availble tasks
# Reference: https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/

usage() {
  echo "Usage: $0 [-t task]"
  echo "Available tasks are:"
  echo "1 - List all Container images"
  echo "2 - List Container images by Pod"
  echo "3 - List Container images filtering by Pod label"
  echo "4 - List Container images filtering by Pod namespace"
  exit 1
}

while getopts ":t:" opt; do
  case $opt in
    t)
      task=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

shift $((OPTIND-1))

if [ -z "$task" ]; then
  echo "No task specified. Please choose one of the available tasks."
  usage
else
  PS3="Please enter your choice: "
  select namespace in "All namespaces" $(kubectl get ns | awk 'NR>1 {print $1}')
  do
    case $namespace in
      "")
        echo "Invalid choice. Please try again."
        ;;
      "All namespaces")
        echo "You chose all namespaces."
        namespace=""
        break
        ;;
      *)
        echo "You chose $namespace."
        break
        ;;
    esac
  done

  case $task in
    1)
      if [ -z "$namespace" ]; then # If namespace is empty
        echo "Listing all container images."
        kubectl get pods -o jsonpath="{.items[*].spec.containers[*].image}" |\
        tr -s '[[:space:]]' '\n' |\
        sort |\
        uniq -c
      else
        echo "Listing all container images in namespace $namespace."
        kubectl get pods -n $namespace -o jsonpath="{.items[*].spec.containers[*].image}" |\
        tr -s '[[:space:]]' '\n' |\
        sort |\
        uniq -c
      fi
      break
      ;;
    2)
      if [ -z "$namespace" ]; then
        echo "Listing container images by pod."
        kubectl get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |\
        sort
      else #
        echo "Listing container images by pod in namespace $namespace."
        kubectl get pods -n $namespace -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |\
        sort
      fi
      break
      ;;
    3)
      if [ -z "$namespace" ]; then
        echo "No namespace specified. Please choose a namespace first."
        break
      else
        PS3="Please enter your choice: "
        select label in $(kubectl get pods -n $namespace --show-labels | awk 'NR>1 {print $NF}' | awk -F, '{for (i=1;i<=NF;i++) print $i}' | sort | uniq)
        do
          case $label in
            "")
              echo "Invalid choice. Please try again."
              ;;
            *)
              echo "You chose $label."
              label=$(echo $label | cut -d'=' -f1) # Get the name of the label
              break
              ;;
          esac
        done
        echo "Listing container images filtering by pod label $label in namespace $namespace."
        kubectl get pods -n $namespace -o jsonpath="{.items[*].spec.containers[*].image}" -l $label
      fi
      break
      ;;
    4)
      if [ -z "$namespace" ]; then # If namespace is empty
        echo "No namespace specified. Listing container images filtering by pod namespace."
        kubectl get pods -o jsonpath="{.items[*].spec.containers[*].image}"
      else
        echo "Listing container images filtering by pod namespace in namespace $namespace."
        kubectl get pods -n $namespace -o jsonpath="{.items[*].spec.containers[*].image}"
      fi
      break
      ;;
    *)
      echo "Invalid task: $task. Please choose one of the available tasks."
      usage
      ;;
  esac
fi
