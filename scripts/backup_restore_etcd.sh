#!/bin/bash
set -euo pipefail

# Validate endpoint format
validate_endpoint() {
	local endpoint="$1"
	if [[ ! "$endpoint" =~ ^https?://[0-9.]+:[0-9]+$ ]]; then
		echo "Error: Invalid endpoint format. Expected format: https://IP:PORT"
		return 1
	fi
	return 0
}

# Validate file exists
validate_file() {
	local file_path="$1"
	local file_type="$2"
	if [[ ! -f "$file_path" ]]; then
		echo "Error: $file_type file does not exist: $file_path"
		return 1
	fi
	return 0
}

# Perform etcd backup
perform_backup() {
	echo "Performing etcd backup..."
	read -p "Enter etcd endpoints (e.g., https://10.0.1.101:2379): " endpoints
	if ! validate_endpoint "$endpoints"; then
		exit 1
	fi

	read -p "Enter path to etcd CA certificate (e.g., /home/k8s_user/etcd-certs/etcd-ca.pem): " cacert
	if ! validate_file "$cacert" "CA certificate"; then
		exit 1
	fi

	read -p "Enter path to etcd server certificate (e.g., /home/k8s_user/etcd-certs/etcd.crt): " cert
	if ! validate_file "$cert" "Server certificate"; then
		exit 1
	fi

	read -p "Enter path to etcd server key (e.g., /home/k8s_user/etcd-certs/etcd.key): " key
	if ! validate_file "$key" "Server key"; then
		exit 1
	fi

	read -p "Enter backup file path (e.g., /home/cloud_user/etcd_backup.db): " backup_file
	backup_dir=$(dirname "$backup_file")
	if [[ ! -d "$backup_dir" ]]; then
		echo "Error: Backup directory does not exist: $backup_dir"
		exit 1
	fi

	if ! ETCDCTL_API=3 etcdctl snapshot save "$backup_file" \
		--endpoints="$endpoints" \
		--cacert="$cacert" \
		--cert="$cert" \
		--key="$key"; then
		echo "Error: Backup failed"
		exit 1
	fi

	echo "Backup completed successfully."
}

# Perform etcd restore
perform_restore() {
	echo "Performing etcd restore..."
	read -p "Enter initial cluster configuration (e.g., etcd-restore=https://10.0.1.101:2380): " initial_cluster
	if [[ -z "$initial_cluster" ]]; then
		echo "Error: Initial cluster configuration cannot be empty"
		exit 1
	fi

	read -p "Enter initial advertise peer URLs (e.g., https://10.0.1.101:2380): " advertise_urls
	if ! validate_endpoint "$advertise_urls"; then
		exit 1
	fi

	read -p "Enter the name for the restored cluster (e.g., etcd-restore): " cluster_name
	if [[ -z "$cluster_name" ]]; then
		echo "Error: Cluster name cannot be empty"
		exit 1
	fi

	read -p "Enter backup file path (e.g., /home/cloud_user/etcd_backup.db): " backup_file
	if ! validate_file "$backup_file" "Backup"; then
		exit 1
	fi

	read -p "Enter data directory path (e.g., /var/lib/etcd): " data_dir
	if [[ ! -d "$(dirname "$data_dir")" ]]; then
		echo "Error: Parent directory does not exist: $(dirname "$data_dir")"
		exit 1
	fi

	if ! sudo ETCDCTL_API=3 etcdctl snapshot restore "$backup_file" \
		--initial-cluster "$initial_cluster" \
		--initial-advertise-peer-urls "$advertise_urls" \
		--name "$cluster_name" \
		--data-dir "$data_dir"; then
		echo "Error: Restore failed"
		exit 1
	fi

	if ! sudo chown -R etcd:etcd "$data_dir"; then
		echo "Error: Failed to change ownership of data directory"
		exit 1
	fi

	if ! sudo systemctl start etcd; then
		echo "Error: Failed to start etcd service"
		exit 1
	fi

	echo "Restore completed successfully."
}

# Prompt to perform an action
echo "Choose an action:"
echo "1. Backup"
echo "2. Restore"
read -p "Enter your choice (1 or 2): " choice

case "$choice" in
1)
	perform_backup
	;;
2)
	perform_restore
	;;
*)
	echo "Invalid choice. Exiting."
	exit 1
	;;
esac
