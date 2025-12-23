#!/bin/bash
set -eu

# Get the namespace
get_namespace() {
	read -p "Enter the Kubernetes namespace to label resources in: " NAMESPACE

	if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
		echo "Error: Namespace '$NAMESPACE' does not exist."
		exit 1
	fi
}

# Get the label
get_label() {
	read -p "Enter the label in the format key=value: " LABEL

	if [[ ! "$LABEL" =~ ^[a-zA-Z0-9._-]+=[a-zA-Z0-9._-]+$ ]]; then
		echo "Error: Label format is invalid. Use key=value format."
		exit 1
	fi

	KEY=$(echo "$LABEL" | cut -d '=' -f 1)
	VALUE=$(echo "$LABEL" | cut -d '=' -f 2)
}

# Confirm the operation
confirm_operation() {
	echo "You are about to label all resources in the namespace '$NAMESPACE' with '$KEY=$VALUE'."
	read -p "Do you want to proceed? (yes/no): " CONFIRM
	if [[ "$CONFIRM" != "yes" ]]; then
		echo "Operation canceled."
		exit 0
	fi
}

# Label all resources in the namespace
label_resources() {
	RESOURCE_TYPES=$(kubectl api-resources --verbs=list --namespaced -o name)

	for RESOURCE_TYPE in $RESOURCE_TYPES; do
		echo "Labeling resources of type $RESOURCE_TYPE in namespace $NAMESPACE..."
		kubectl label $RESOURCE_TYPE -n "$NAMESPACE" --all "$LABEL" --overwrite
		if [[ $? -ne 0 ]]; then
			echo "Warning: Failed to label some resources of type $RESOURCE_TYPE."
		fi
	done

	echo "Labeling completed for namespace '$NAMESPACE' with label '$KEY=$VALUE'."
}

# Main script
get_namespace
get_label
confirm_operation
label_resources
