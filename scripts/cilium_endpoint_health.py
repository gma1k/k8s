#!/usr/bin/env python3
import requests
import json

CILIUM_API = "http://CiliumAPI:Port"

def list_endpoints():
    r = requests.get(f"{CILIUM_API}/v1/endpoint")
    endpoints = r.json()
    for ep in endpoints:
        print(f"Pod: {ep['status']['pod-name']}, IP: {ep['status']['networking']['addressing'][0]['ipv4']}, State: {ep['status']['state']}")

if __name__ == "__main__":
    try:
        list_endpoints()
    except Exception as e:
        print(f"Error fetching Cilium endpoints: {e}")
