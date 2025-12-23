#!/bin/bash
set -euo pipefail

# Iterate list of all secrets in AWS Secrets Manager and inject into cluster as k8s secrets
# USAGE: ./inject_secrets.sh secret_prefix cluster namespace region profile
# USAGE EXMP: ./inject_secrets.sh myapp/dev foocluster app us-west-2 profilename

if [[ $# -ne 5 ]]; then
	echo "usage: $0 secret_prefix cluster namespace region profile" >&2
	exit 2
fi

secret_prefix="$1"
cluster="$2"
namespace="$3"
AWS_REGION="$4"
AWS_PROFILE="$5"

# Validate namespace exists
if ! kubectl get namespace "$namespace" &>/dev/null; then
	echo "Error: Namespace '$namespace' does not exist" >&2
	exit 1
fi

kubectl_ver=$(kubectl version --client=true -o json | jq -rj '.clientVersion | .major, ".", .minor')
ver_major=$(echo "$kubectl_ver" | cut -d. -f1)
ver_minor=$(echo "$kubectl_ver" | cut -d. -f2)
dry_run_flag="--dry-run"
if [[ "$ver_major" -gt "1" ]] || [[ "$ver_minor" -gt "17" ]]; then
	dry_run_flag="--dry-run=client"
fi

echo "Injecting all secrets under ${secret_prefix} from AWS Secrets Manager into cluster ${cluster}, namespace ${namespace}"

secret_count=0

# Use jq for safer filtering
secret_list=$(aws secretsmanager list-secrets \
	--profile "${AWS_PROFILE}" \
	--region "${AWS_REGION}" \
	--output json 2>/dev/null || {
	echo "Error: Failed to list secrets from AWS Secrets Manager" >&2
	exit 1
})

if [[ -z "$secret_list" ]]; then
	echo "Error: No secrets returned from AWS Secrets Manager" >&2
	exit 1
fi

# Filter secrets using jq
while IFS= read -r secret_name; do
	[[ -z "$secret_name" ]] && continue

	secret_count=$((secret_count + 1))

	if [[ "$secret_name" == "None" ]]; then
		echo "error: aws secrets manager list-secrets returned None." >&2
		exit 1
	fi

	echo "secret name: $secret_name"
	k8s_secret_name=$(echo "${secret_name#"$secret_prefix"/}" | tr "/_" "-")
	if [[ -z "$k8s_secret_name" ]]; then
		echo "warning: k8s_secret_name empty for secret_name=$secret_name" >&2
		continue
	fi

	value=$(aws secretsmanager get-secret-value \
		--secret-id "$secret_name" \
		--query 'SecretString' \
		--output text \
		--region "${AWS_REGION}" 2>/dev/null || {
		echo "warning: failed to get secret value for secret_name=${secret_name}" >&2
		continue
	})

	if [[ -z "$value" ]]; then
		echo "warning: secret value is empty for secret_name=${secret_name}. not injecting this secret." >&2
	else
		if [[ $secret_count -eq 1 ]]; then
			# table header
			echo
			line=$(
				printf -- '=%.0s' {1..20}
				echo ""
			)
			printf "%-65s----> %s\n" "AWS Secret name" "k8s Secret Name"
			printf "%-70s %s\n" "$line" "$line"
		fi
		printf "%-70s %s\n" "$secret_name" "$k8s_secret_name"

		if ! kubectl create secret generic "$k8s_secret_name" \
			--from-literal=password="$value" \
			-n "$namespace" \
			"$dry_run_flag" \
			-o yaml 2>/dev/null | kubectl apply -f - >/dev/null 2>&1; then
			echo "warning: failed to create secret $k8s_secret_name" >&2
		fi
	fi
done < <(echo "$secret_list" | jq -r --arg prefix "$secret_prefix" '.SecretList[]? | select(.Name != null and (.Name | startswith($prefix))) | .Name')

if [[ $secret_count -eq 0 ]]; then
	echo "No secrets found in AWS Secrets Manager for secret name prefix ${secret_prefix}."
fi
