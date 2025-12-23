#!/bin/bash

CILIUM_VERSION="1.17.4"
NAMESPACE="kube-system"

upgrade_cilium() {
	echo "Upgrading Cilium to version $CILIUM_VERSION in namespace $NAMESPACE..."
	helm upgrade cilium cilium/cilium \
		--version "$CILIUM_VERSION" \
		--namespace "$NAMESPACE" \
		--reuse-values \
		--set ingressController.enabled=true \
		--set ingressController.loadbalancerMode=dedicated
}

restart_cilium_operator() {
	echo "Restarting Cilium operator in namespace $NAMESPACE..."
	kubectl -n "$NAMESPACE" rollout restart deployment/cilium-operator
}

restart_cilium_ds() {
	echo "Restarting Cilium DaemonSet in namespace $NAMESPACE..."
	kubectl -n "$NAMESPACE" rollout restart ds/cilium
}

main() {
	upgrade_cilium
	restart_cilium_operator
	restart_cilium_ds
}

main
