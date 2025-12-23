#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'
bold=$(tput bold)
normal=$(tput sgr0)

deploy="$2"
namespace="$1"

if [[ $# -ne 2 ]]; then
	echo "usage: $0 <namespace> <deployment>"
	exit 1
fi

var=$(kubectl get deployment -n "${namespace}" --output=json "${deploy}" 2>/dev/null |
	jq -j '.spec.selector.matchLabels | to_entries | .[] | "\(.key)=\(.value),"')
selector="${var%?}"

pod_status() {
	no_of_pods=$(kubectl get po -n "$namespace" -l "$selector" 2>/dev/null | grep -v NAME | wc -l || echo "0")
	if [[ "$no_of_pods" -eq 0 ]]; then
		echo "Deployment $deploy has 0 replicas"
		exit 0
	fi
	pods_status=$(kubectl get po -n "$namespace" -l "$selector" 2>/dev/null | grep -v NAME | awk '{print $3}' | sort -u | tr '\n' ' ' || echo "")
	restart_count=$(kubectl get po -n "$namespace" -l "$selector" 2>/dev/null | grep -v NAME | awk '{print $4}' | grep -v RESTARTS | sort -ur | awk 'FNR <= 1' || echo "0")
	echo -e "${BLUE}Number of Pods            :${GREEN}$no_of_pods"
	echo -e "${BLUE}Pods Status               :${GREEN}$pods_status"
	echo -e "${BLUE}MAX Pod Restart Count     :${GREEN}$restart_count"
	readiness() {
		if kubectl get po -n "$namespace" 2>/dev/null | grep "$deploy" | grep -vE '1/1|2/2|3/3|4/4|5/5|6/6|7/7' &>/dev/null; then
			echo -e "${BLUE}Readiness                 :${RED}You have some Pods not ready"
		else
			echo -e "${BLUE}Readiness                 :${GREEN}ALL Pods are Ready"
		fi
	}
	readiness
}
pod_distribution() {
	echo -e "\e[1m\e[39mPod Distribution per Node\e[21m"
	while IFS= read -r nodes; do
		[[ -z "$nodes" ]] && continue
		pod_count=$(kubectl describe node "$nodes" 2>/dev/null | grep "$deploy" | wc -l || echo "0")
		echo -e "${BLUE}$nodes \t \t :${GREEN}$pod_count"
	done < <(kubectl get po -n "$namespace" -l "$selector" -o wide 2>/dev/null | grep "$deploy" | awk '{print $7}' | sort -u || true)

	echo -e "\e[1m\e[39mNode Distribution per Availability Zone\e[21m"
	node_dist=""
	while IFS= read -r node; do
		[[ -z "$node" ]] && continue
		node_dist="$node_dist $(kubectl get node --show-labels "$node" 2>/dev/null | awk '{print $6}' | grep -v LABELS || true)"
	done < <(kubectl get po -n "$namespace" -l "$selector" -o wide 2>/dev/null | grep "$deploy" | awk '{print $7}' | sort -u || true)

	# Detect availability zones dynamically
	a=$(echo "$node_dist" | grep -o '[a-z0-9-]*[a-z][0-9][a-z]' | grep -o '[0-9][a-z]$' | sort -u | head -1 | sed 's/.*\([a-z]\)/\1/' || echo "")
	if [[ -n "$a" ]]; then
		zone_base=$(echo "$node_dist" | grep -o '[a-z0-9-]*[0-9][a-z]$' | head -1 | sed 's/.*\([0-9][a-z]\)$/\1/' | sed 's/[a-z]$//' || echo "")
		a_count=$(echo "$node_dist" | grep -o "${zone_base}a" | wc -l || echo "0")
		b_count=$(echo "$node_dist" | grep -o "${zone_base}b" | wc -l || echo "0")
		c_count=$(echo "$node_dist" | grep -o "${zone_base}c" | wc -l || echo "0")
		echo -e "${BLUE}Zone ${zone_base}a \t \t :${GREEN}$a_count"
		echo -e "${BLUE}Zone ${zone_base}b \t \t :${GREEN}$b_count"
		echo -e "${BLUE}Zone ${zone_base}c \t \t :${GREEN}$c_count"
	else
		# Fallback to hardcoded if detection fails
		a=$(echo "$node_dist" | grep -o eu-central-1a | wc -l || echo "0")
		b=$(echo "$node_dist" | grep -o eu-central-1b | wc -l || echo "0")
		c=$(echo "$node_dist" | grep -o eu-central-1c | wc -l || echo "0")
		echo -e "${BLUE}eu-central-1a \t \t :${GREEN}$a"
		echo -e "${BLUE}eu-central-1b \t \t :${GREEN}$b"
		echo -e "${BLUE}eu-central-1c \t \t :${GREEN}$c"
	fi
}

pod_utilization() {
	first_pod=$(kubectl get po -n "$namespace" -l "$selector" 2>/dev/null | grep -v NAME | awk '{print $1}' | head -n1 || echo "")
	if [[ -z "$first_pod" ]]; then
		echo "No pods found for deployment"
		return
	fi

	cpulimit=$(kubectl describe node 2>/dev/null | grep "$first_pod" | awk '{print $5}' | grep -Ev "^$" | sort -u |
		awk '{ if ($0 ~ /[0-9]*m/) print $0; else print $0*1000;}' | sed 's/[^0-9]*//g' | head -1 || echo "0")

	memlimit=$(kubectl describe node 2>/dev/null | grep "$first_pod" | awk '{print $9}' | grep -Ev "^$" | sort -u |
		awk '{ if ($0 ~ /[0-9]*Gi/) print $0*1024; else if ($0 ~ /[0-9]*G/) print $0*1000; \
        else if ($0 ~ /[0-9]*M/ || $0 ~ /[0-9]*Mi/) print $0 ; else print $0}' | sed 's/[^0-9]*//g' | head -1 || echo "0")

	dcores=$(kubectl top pods -n "$namespace" 2>/dev/null | grep "$deploy" | awk '{print $2}' | sed 's/[^0-9]*//g' | awk '{n += $1}; END{print n+0}' || echo "0")
	dmem=$(kubectl top pods -n "$namespace" 2>/dev/null | grep "$deploy" | awk '{print $3}' | sed 's/[^0-9]*//g' | awk '{n += $1}; END{print n+0}' || echo "0")

	if [[ "$cpulimit" -eq 0 ]]; then
		echo -e "\e[1m\e[33mWARN: Pods do not have CPU Limits\e[21m"
	else
		echo -e "\e[1m\e[39mAverage Utilization \e[21m"
		deploymentcpu=$(bc <<<"scale=2;$dcores/($cpulimit*$no_of_pods)*100" 2>/dev/null || echo "0")
		echo -e "${BLUE}CPU Utilization                   :${GREEN}$deploymentcpu%"
		if [[ "$memlimit" -ne 0 ]]; then
			deploymentmem=$(bc <<<"scale=2;$dmem/($memlimit*$no_of_pods)*100" 2>/dev/null || echo "0")
			echo -e "${BLUE}Memory Utilization                :${GREEN}$deploymentmem%"
		fi
		echo -e "\e[1m\e[39mTop Pods CPU Utilization\e[21m"
		kubectl top pods -n "$namespace" -l "$selector" 2>/dev/null | grep -v NAME |
			awk 'FNR <= 5' | awk '{print $1,$2}' | awk -v limit="$cpulimit" '$2=($2/limit)*100"%"' |
			awk '{printf $1 " " "%0.2f\n",$2}' | sort -k2 -r |
			awk -v OFS='\t' '{if ($2 >= 80) print "\033[0;36m"$1," ", "\033[0;31m"":"$2"%"; else print "\033[0;36m"$1," ","\033[0;32m"":"$2"%";}'
	fi
	if [[ "$memlimit" -eq 0 ]]; then
		echo -e "\e[1m\e[33mWARN: Pods do not have Memory Limits\e[21m"
	else
		echo -e "\e[1m\e[39mTop Pods Memory Utilization\e[21m"
		kubectl top pods -n "$namespace" -l "$selector" 2>/dev/null | grep -v NAME |
			awk 'FNR <= 5' | awk '{print $1,$3}' | awk -v limit="$memlimit" '$2=($2/limit)*100"%"' |
			awk '{printf $1 " " "%0.2f\n",$2}' | sort -k2 -r |
			awk -v OFS=' \t' '{if ($2 >= 80) print "\033[0;36m"$1," ", "\033[0;31m"":"$2"%"; else print "\033[0;36m"$1," ","\033[0;32m"":"$2"%";}'
	fi
}

clear
if ! kubectl get deploy "$deploy" -n "$namespace" &>/dev/null; then
	echo -e "Deployment $deploy does not exist.\nPlease make sure you provide the correct deployment name and the correct namespace"
	exit 1
fi
echo -e "\e[1m\e[39mChecking Deployment $deploy...\e[21m"
pod_status
pod_utilization
pod_distribution
