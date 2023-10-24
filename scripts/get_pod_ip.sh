#!/bin/bash

POD2=$(kubectl get pod pod-worker2 --template '{{.status.podIP}}')
echo $POD2
