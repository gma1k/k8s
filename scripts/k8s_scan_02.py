#!/usr/bin/env python3

import os
import subprocess
import json
import requests

KUBE_CONFIG = os.path.expanduser("~/.kube/config")

KUBESCAPE_OUTPUT = "kubescape_output.json"
CHECKOV_OUTPUT = "checkov_output.json"
NVD_OUTPUT = "nvd_output.json"
NMAP_OUTPUT = "nmap_output.json"

NVD_API_URL = "https://services.nvd.nist.gov/rest/json/cves/1.0"
NVD_PARAMS = {
    "keyword": "kubernetes",
    "resultsPerPage": 100
}

NMAP_CMD = "nmap"
NMAP_PARAMS = [
    "-p", "1-65535",
    "-sV",
    "-oX", NMAP_OUTPUT
]

os.system("curl -s https://raw.githubusercontent.com/armosec/kubescape/master/install.sh | /bin/bash")
os.system("pip install checkov")
os.system("apt-get install nmap")

os.system(f"kubescape scan framework nsa --output json > {KUBESCAPE_OUTPUT}")

os.system(f"checkov -d . --output json --framework kubernetes > {CHECKOV_OUTPUT}")

response = requests.get(NVD_API_URL, params=NVD_PARAMS)
if response.status_code == 200:
    data = response.json()
    with open(NVD_OUTPUT, "w") as f:
        json.dump(data, f, indent=4)
else:
    print(f"Error: NVD API request failed with status code {response.status_code}")

with open(KUBE_CONFIG, "r") as f:
    config = json.load(f)
    cluster_ip = config["clusters"][0]["cluster"]["server"].split("//")[1].split(":")[0]

os.system(f"{NMAP_CMD} {' '.join(NMAP_PARAMS)} {cluster_ip}")

print("Kubernetes Security Scan Results:")
print(f"Kubescape output file: {KUBESCAPE_OUTPUT}")
print(f"Checkov output file: {CHECKOV_OUTPUT}")
print(f"NVD output file: {NVD_OUTPUT}")
print(f"Nmap output file: {NMAP_OUTPUT}")
