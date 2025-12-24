#!/bin/bash

# List unmounted PVCs
list_unmounted_pvc() {
	echo "Unmounted PVCs:"
	kubectl describe -A pvc | grep -E "^Name:.*$|^Namespace:.*$|^Mounted By:.*$" | grep -B 2 "<none>" | grep -E "^Name:.*$|^Namespace:.*$"
}

# List unmounted PVs
list_unmounted_pv() {
	echo "Unmounted PVs:"
	kubectl get pv | grep Released
}

# Delete unmounted PVCs and PVs
delete_unmounted_resources() {
	echo "Deleting unmounted PVCs and PVs..."
	kubectl describe -A pvc | grep -E "^Name:.*$|^Namespace:.*$|^Mounted By:.*$" | grep -B 2 "<none>" | grep -E "^Name:.*$|^Namespace:.*$" | cut -f2 -d: | paste -d " " - - | xargs -n2 bash -c 'kubectl -n ${1} delete pvc ${0}'
	kubectl get pv | grep Released | awk '{print $1}' | xargs -I{} kubectl delete pv {}
	echo "Cleanup completed!"
}

# Main menu
while true; do
	echo "Choose an option:"
	echo "1. List unmounted PVCs"
	echo "2. List unmounted PVs"
	echo "3. Delete unmounted PVCs and PVs"
	echo "4. Exit"
	read -p "Enter your choice: " choice

	case "$choice" in
	1) list_unmounted_pvc ;;
	2) list_unmounted_pv ;;
	3) delete_unmounted_resources ;;
	4)
		echo "Exiting. Goodbye!"
		exit
		;;
	*) echo "Invalid choice. Please select a valid option." ;;
	esac
done
