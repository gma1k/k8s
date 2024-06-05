#!/bin/bash

# Check for the required arguments
check_arguments() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <application_name> <namespace>"
        exit 1
    fi
}

# Display the usage information
print_usage() {
    echo "Usage: $0 <application_name> <namespace>"
}

# Get pod details
get_pod_details() {
    local app_name="$1"
    local namespace="$2"
    kubectl get pods -n "$namespace" -l app="$app_name" -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
}

# Check pod health
check_pod_health() {
    local app_name="$1"
    local namespace="$2"
    local pod_names=$(kubectl get pods -n "$namespace" -l app="$app_name" -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')

    local all_pods_healthy=true
    while read -r pod_name; do
        local pod_status=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
        if [[ "$pod_status" != "Running" ]]; then
            echo "Pod '$pod_name' is not running!"
            all_pods_healthy=false
        fi
    done <<< "$pod_names"

    if [[ "$all_pods_healthy" == "true" ]]; then
        echo "All pods for '$app_name' seem healthy."
    fi
}

# Get pod logs
get_pod_logs() {
    local app_name="$1"
    local namespace="$2"
    local pod_names=$(kubectl get pods -n "$namespace" -l app="$app_name" -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')

    while read -r pod_name; do
        kubectl logs "$pod_name" -n "$namespace"
    done <<< "$pod_names"
}

# Check resource utilization
check_resource_utilization() {
    local app_name="$1"
    local namespace="$2"
    
    echo "Events for $app_name in namespace $namespace:"
    kubectl get events -n "$namespace" --field-selector involvedObject.kind=Pod

    local hpa_count=$(kubectl get hpa -n "$namespace" -l app="$app_name" 2>/dev/null | wc -l)
    echo "HPA count for $app_name in namespace $namespace: $hpa_count"
}

# Describe pods
describe_pods() {
    local app_name="$1"
    local namespace="$2"
    kubectl describe pods -n "$namespace" "$app_name"
}

# Main menu
main_menu() {
    echo "Choose an option:"
    echo "1. Get pod details"
    echo "2. Check pod health"
    echo "3. Get pod logs"
    echo "4. Check resource utilization"
    echo "5. Describe pods"
    echo "6. Exit"
    read -p "Enter your choice: " choice

    case "$choice" in
        1) get_pod_details "$app_name" "$namespace";;
        2) check_pod_health "$app_name" "$namespace";;
        3) get_pod_logs "$app_name" "$namespace";;
        4) check_resource_utilization "$app_name" "$namespace";;
        5) describe_pods "$app_name" "$namespace";;
        6) echo "Exiting..."; exit 0;;
        *) echo "Invalid choice. Please select a valid option.";;
    esac
}

# Main script
check_arguments "$@"
app_name="$1"
namespace="$2"
main_menu
