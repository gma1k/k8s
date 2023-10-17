#!/bin/bash

# Perform etcd backup
perform_backup() {
    echo "Performing etcd backup..."
    read -p "Enter etcd endpoints (e.g., https://10.0.1.101:2379): " endpoints
    read -p "Enter path to etcd CA certificate (e.g., /home/k8s_user/etcd-certs/etcd-ca.pem): " cacert
    read -p "Enter path to etcd server certificate (e.g., /home/k8s_user/etcd-certs/etcd.crt): " cert
    read -p "Enter path to etcd server key (e.g., /home/k8s_user/etcd-certs/etcd.key): " key
    read -p "Enter backup file path (e.g., /home/cloud_user/etcd_backup.db): " backup_file

    ETCDCTL_API=3 etcdctl snapshot save "$backup_file" \
        --endpoints="$endpoints" \
        --cacert="$cacert" \
        --cert="$cert" \
        --key="$key"
    
    echo "Backup completed successfully."
}

# Perform etcd restore
perform_restore() {
    echo "Performing etcd restore..."
    read -p "Enter initial cluster configuration (e.g., etcd-restore=https://10.0.1.101:2380): " initial_cluster
    read -p "Enter initial advertise peer URLs (e.g., https://10.0.1.101:2380): " advertise_urls
    read -p "Enter the name for the restored cluster (e.g., etcd-restore): " cluster_name
    read -p "Enter backup file path (e.g., /home/cloud_user/etcd_backup.db): " backup_file
    read -p "Enter data directory path (e.g., /var/lib/etcd): " data_dir

    sudo ETCDCTL_API=3 etcdctl snapshot restore "$backup_file" \
        --initial-cluster "$initial_cluster" \
        --initial-advertise-peer-urls "$advertise_urls" \
        --name "$cluster_name" \
        --data-dir "$data_dir"
    
    sudo chown -R etcd:etcd "$data_dir"
    sudo systemctl start etcd
    
    echo "Restore completed successfully."
}

# Prompt preform a action
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
