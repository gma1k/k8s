#!/bin/bash

pods_with_limit_checks=""
pods_without_limit_checks=""

for namespace in `kubectl get namespaces | grep -v NAME | cut -d ' ' -f 1` ; do
  for pod in `kubectl get pods -n $namespace | grep -v NAME | cut -d ' ' -f 1` ; do
        limit_check=`kubectl get pods $pod -n $namespace -o yaml | grep limits`
        if [ ! -z "$limits_check" ]; then
           pods_with_limit_checks="$pods_with_limit_checks\n$pod,$namespace"
        else
           pods_without_limit_checks="$pods_with_limit_checks\n$pod,$namespace"
        fi
  done
done

echo "Pods With Limit Checks"
echo $pods_with_limit_checks

echo ""
echo ""
echo "========="
echo ""
echo ""

echo "Pods Without Limit Checks"
echo $pods_without_limit_checks
