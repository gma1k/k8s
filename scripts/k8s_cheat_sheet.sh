#!/bin/bash

KUBECTL="kubectl"
CHEAT_SHEET="k8s-cheat-sheet.txt"
RESOURCES=("pod" "deployment" "service" "configmap" "secret" "ingress" "node" "namespace")
OPERATIONS=("get" "describe" "create" "delete" "edit" "apply" "logs" "exec")

echo "# Kubernetes Cheat Sheet" >$CHEAT_SHEET
echo "" >>$CHEAT_SHEET

read -p "Enter the cluster name: " CLUSTER_NAME
read -p "Enter the context name: " CONTEXT_NAME

echo "## Cluster and Context" >>$CHEAT_SHEET
echo "" >>$CHEAT_SHEET
echo "\`\`\`bash" >>$CHEAT_SHEET
echo "# Set the cluster entry in the kubeconfig" >>$CHEAT_SHEET
echo "$KUBECTL config set-cluster $CLUSTER_NAME --server=<server-url> --certificate-authority=<ca-file>" >>$CHEAT_SHEET
echo "" >>$CHEAT_SHEET
echo "# Set the user entry in the kubeconfig" >>$CHEAT_SHEET
echo "$KUBECTL config set-credentials <user-name> --client-certificate=<cert-file> --client-key=<key-file>" >>$CHEAT_SHEET
echo "" >>$CHEAT_SHEET
echo "# Set the context entry in the kubeconfig" >>$CHEAT_SHEET
echo "$KUBECTL config set-context $CONTEXT_NAME --cluster=$CLUSTER_NAME --user=<user-name> --namespace=<namespace>" >>$CHEAT_SHEET
echo "" >>$CHEAT_SHEET
echo "# Use the context" >>$CHEAT_SHEET
echo "$KUBECTL config use-context $CONTEXT_NAME" >>$CHEAT_SHEET
echo "\`\`\`" >>$CHEAT_SHEET
echo "" >>$CHEAT_SHEET

for RESOURCE in "${RESOURCES[@]}"; do
	echo "## Resource: $RESOURCE" >>$CHEAT_SHEET
	echo "" >>$CHEAT_SHEET
	for OPERATION in "${OPERATIONS[@]}"; do
		echo "### Operation: $OPERATION" >>$CHEAT_SHEET
		echo "" >>$CHEAT_SHEET
		echo "\`\`\`bash" >>$CHEAT_SHEET

		case "$OPERATION" in

		get)
			echo "# Get all ${RESOURCE}s in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL get $RESOURCE" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Get all ${RESOURCE}s in all namespaces" >>$CHEAT_SHEET
			echo "$KUBECTL get $RESOURCE --all-namespaces" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Get a specific ${RESOURCE} by name in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL get $RESOURCE <name>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Get a specific ${RESOURCE} by name in a specific namespace" >>$CHEAT_SHEET
			echo "$KUBECTL get -n <namespace> <name>" >>$CHEAT_SHEET
			;;

		describe)
			echo "# Describe all ${RESOURCE}s in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL describe $RESOURCE" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Describe all ${RESOURCE}s in all namespaces" >>$CHEAT_SHEET
			echo "$KUBECTL describe -A <name>" >>$CHEAT_SHEET
			echo "" CHEATSHEETS >>$

			echo "# Describe a specific ${RESOURCE} by name in the current namespace" CHEATSHEETS >>$
			echo "$KUBECTL describe <name>" CHEATSHEETS >$
			echo "" CHEATSHEETS >$

			echo "# Describe a specific ${RESOURCE} by name in a specific namespace" CHEATSHEETS >$
			echo "$KUBECTL describe -n <namespace> <name>" CHEATSHEETS >$
			;;

		create)
			echo "# Create a ${RESOURCE} from a YAML file in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL create -f <file.yaml>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Create a ${RESOURCE} from a YAML file in a specific namespace" >>$CHEAT_SHEET
			echo "$KUBECTL create -n <namespace> -f <file.yaml>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Create a ${RESOURCE} from a JSON file in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL create -f <file.json>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Create a ${RESOURCE} from a JSON file in a specific namespace" >>$CHEAT_SHEET
			echo "$KUBECTL create -n <namespace> -f <file.json>" >>$CHEAT_SHEET
			;;

		delete)
			echo "# Delete all ${RESOURCE}s in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL delete $RESOURCE --all" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Delete all ${RESOURCE}s in all namespaces" >>$CHEAT_SHEET
			echo "$KUBECTL delete -A <name>" >>$CHEAT_SHEET
			echo "" CHEATSHEETS >$

			echo "# Delete a specific ${RESOURCE} by name in the current namespace" CHEATSHEETS >$
			echo "$KUBECTL delete <name>" CHEATSHEETS >$
			echo "" CHEATSHEETS >$

			echo "# Delete a specific ${RESOURCE} by name in a specific namespace" CHEATSHEETS >$
			echo "$KUBECTL delete -n <namespace> <name>" CHEATSHEETS >$
			;;

		edit)
			echo "# Edit a ${RESOURCE} by name in the current namespace using the default editor" >>$CHEAT_SHEET
			echo "$KUBECTL edit $RESOURCE <name>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Edit a ${RESOURCE} by name in the current namespace using a specific editor" >>$CHEAT_SHEET
			echo "EDITOR=<editor> kubectl edit $RESOURCE <name>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Edit a ${RESOURCE} by name in a specific namespace using the default editor" >>$CHEAT_SHEET
			echo "$KUBECTL edit -n <namespace> <name>" >>$CHEAT_SHEET
			;;

		apply)
			echo "# Apply changes to a ${RESOURCE} from a YAML file in the current namespace" >>$CHEAT_SHEET
			echo "$KUBECTL apply -f <file.yaml>" >>$CHEAT_SHEET
			echo "" >>$CHEAT_SHEET

			echo "# Apply changes to a ${RESOURCE} from a YAML file in a specific namespace" >>$CHEAT_SHEET
			echo "$KUBECTL apply -n <namespace> -f <file.yaml>" >>$CHEAT_SHEET
			;;

		logs)
			if [ "$RESOURCE" == "pod" ]; then # Logs only work for pods and containers

				read -p "Do you want to follow the logs? (y/n): " FOLLOW

				if [ "$FOLLOW" == "y" ]; then # Follow the logs

					read -p "Do you want to specify a container? (y/n): " CONTAINER

					if [ "$CONTAINER" == "y" ]; then # Specify a container

						read -p "Enter the container name: " CONTAINER_NAME

						echo "# Follow the logs of a specific container in a pod by name in the current namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs -f <pod-name> -c $CONTAINER_NAME" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

						echo "# Follow the logs of a specific container in a pod by name in a specific namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs -n <namespace> -f <pod-name> -c $CONTAINER_NAME" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

						echo "$KUBECTL logs -n <namespace> -f <pod-name> -c $CONTAINER_NAME" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

					else # Don't specify a container

						echo "# Follow the logs of a pod by name in the current namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs -f <pod-name>" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

						echo "# Follow the logs of a pod by name in a specific namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs -n <namespace> -f <pod-name>" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

					fi

				else

					read -p "Do you want to specify a container? (y/n): " CONTAINER

					if [ "$CONTAINER" == "y" ]; then # Specify a container

						read -p "Enter the container name: " CONTAINER_NAME

						echo "# Print the logs of a specific container in a pod by name in the current namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs <pod-name> -c $CONTAINER_NAME" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

						echo "# Print the logs of a specific container in a pod by name in a specific namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs -n <namespace> <pod-name> -c $CONTAINER_NAME" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

					else

						echo "# Print the logs of a pod by name in the current namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs <pod-name>" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

						echo "# Print the logs of a pod by name in a specific namespace" >>$CHEAT_SHEET
						echo "$KUBECTL logs -n <namespace> <pod-name>" >>$CHEAT_SHEET
						echo "" >>$CHEAT_SHEET

					fi

				fi

			fi
			;;

		exec)
			if [ "$RESOURCE" == "pod" ]; then # Exec only works for pods and containers

				read -p "Do you want to specify a container? (y/n): " CONTAINER

				if [ "$CONTAINER" == "y" ]; then # Specify a container

					read -p "Enter the container name: " CONTAINER_NAME

					echo "# Execute commands in a specific container in a pod by name in the current namespace" >>$CHEAT_SHEET
					echo "$KUBECTL exec <pod-name> -c $CONTAINER_NAME -- <command>" >>$CHEAT_SHEET
					echo "" >>$CHEAT_SHEET

					echo "# Execute commands in a specific container in a pod by name in a specific namespace" >>$CHEAT_SHEET
					echo "$KUBECTL exec -n <namespace> <pod-name> -c $CONTAINER_NAME -- <command>" >>$CHEAT_SHEET
					echo "" >>$CHEAT_SHEET

				else

					echo "# Execute commands in a pod by name in the current namespace" >>$CHEAT_SHEET
					echo "$KUBECTL exec <pod-name> -- <command>" >>$CHEAT_SHEET
					echo "" >>$CHEAT_SHEET

					echo "# Execute commands in a pod by name in a specific namespace" >>$CHEAT_SHEET
					echo "$KUBECTL exec -n <namespace> <pod-name> -- <command>" >>$CHEAT_SHEET
					echo "" >>$CHEAT_SHEET

				fi

			fi
			;;

		esac

		echo "\`\`\`" CHEATSHEETS >>$
		echo "" CHEATSHEETS >$
	done
done

cat $CHEAT_SHEET
