#!/bin/bash

# Iterate list of all secrets in AWS Secrets Manager and inject into cluster as k8s secrets
# USAGE: ./inject_secrets.sh secret_prefix cluster namespace region profile
# USAGE EXMP: ./inject_secrets.sh myapp/dev foocluster app us-west-2 profilename

if [[ $# -ne 5 ]] ; then
    echo "usage: $0 secret_prefix cluster namespace region profile" >&2
    exit 2
fi

secret_prefix=$1
cluster=$2
namespace=$3
AWS_REGION=$4
AWS_PROFILE=$5

kubectl_ver=$(kubectl version --client=true -o json | jq -rj '.clientVersion | .major, ".", .minor')
dry_run_flag="--dry-run"
if [[ "$ver_major" -gt "1" ]] || [[ "$ver_minor" -gt "17" ]]; then
    dry_run_flag="--dry-run=client"
fi

echo "Injecting all secrets under ${secret_prefix} from AWS Secrets Manager into cluster ${cluster}, namespace ${namespace}"

secret_count=0

for secret_name in $(aws secretsmanager list-secrets --profile ${AWS_PROFILE} --region ${AWS_REGION} --query 'SecretList[?Name!=`null`]|[?starts_with(Name, `'${secret_prefix}'`) == `true`].Name' --output text); do
    secret_count=$((secret_count+1))

    if [[ $secret_name == "None" ]]; then
        echo "error: aws secrets manager list-secrets returned None."
        exit 1
    fi

    unset k8s_secret_name value

    echo "secret name: $secret_name"
    k8s_secret_name=$(echo ${secret_name#"$secret_prefix"/} | tr "/_" "-")
    if [[ -z $k8s_secret_name ]]; then
        echo "warning: k8s_secret_name empty for secret_name=$secret_name"
    fi

    value=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --query 'SecretString' --output text --region ${AWS_REGION})
 
    if [[ -z $value ]]; then
        echo "warning: secret value is empty for secret_name=${secret_name}. not injecting this secret."
    else
        if [[ ${secret_count} -eq 1 ]]; then
            # table header
            echo
            line=$(printf -- '=%.0s' {1..20}; echo "")
            printf "%-65s----> %s\n" "AWS Secret name" "k8s Secret Name"
            printf "%-70s %s\n" ${line} ${line}
        fi
        printf "%-70s %s\n" ${secret_name} ${k8s_secret_name}

        kubectl create secret generic ${k8s_secret_name} --from-literal=password=${value} -n ${namespace} ${dry_run_flag} -o yaml | kubectl apply -f - > /dev/null
    fi
done

unset value

if [[ $secret_count -eq 0 ]]; then
    echo "No secrets found in AWS Secrets Manager for secret name prefix ${secret_prefix}."
fi
