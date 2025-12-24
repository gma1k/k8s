#!/bin/bash
set -euo pipefail

pods_with_limit_checks=""
pods_without_limit_checks=""

while IFS= read -r namespace; do
	while IFS= read -r pod; do
		limit_check=$(kubectl get pods "$pod" -n "$namespace" -o yaml | grep limits || true)
		if [ -n "$limit_check" ]; then
			pods_with_limit_checks="$pods_with_limit_checks\n$pod,$namespace"
		else
			pods_without_limit_checks="$pods_without_limit_checks\n$pod,$namespace"
		fi
	done < <(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
done < <(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

echo "Pods With Limit Checks"
echo -e "$pods_with_limit_checks"

echo ""
echo ""
echo "========="
echo ""
echo ""

echo "Pods Without Limit Checks"
echo -e "$pods_without_limit_checks"
