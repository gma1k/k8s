#!/usr/bin/env python3

import nmap
import kubernetes
import json
import requests

scanner = nmap.PortScanner()
client = kubernetes.client.CoreV1Api()
nodes = client.list_node()

def check_nvd(ip):
    nvd_url = "https://nvd.nist.gov/vuln/search/results?form_type=Advanced&results_type=overview&search_type=all&query={}"
    
    response = requests.get(nvd_url.format(ip))
    
    if response.status_code == 200:
        html = response.text
        
        start = html.find("vuln-matching-records-count")
        end = html.find("</strong>", start)
        count = html[start + 28:end]
        
        print(f"NVD vulnerabilities found: {count}")
        
        start = html.find("<table id=\"vuln-results-table\"")
        end = html.find("</table>", start)
        table = html[start:end + 8]
        
        print(table)
    else:
        print(f"Error: Could not connect to the NVD Vulnerability Scanner. Status code: {response.status_code}")

for node in nodes.items:
    node_name = node.metadata.name
    node_ip = node.status.addresses[0].address
    
    print(f"Scanning node {node_name} with IP {node_ip}")
    
    scanner.scan(node_ip, '1-65535')
    
    scan_results = scanner[node_ip]
    
    if scan_results['tcp']:
        print(f"Open ports: {scan_results['tcp'].keys()}")
        
        for port in scan_results['tcp'].keys():
            port_state = scan_results['tcp'][port]['state']
            port_service = scan_results['tcp'][port]['name']
            
            print(f"Port {port} is {port_state} and runs {port_service}")
            
            if port_service in ['telnet', 'ftp', 'ssh']:
                print(f"WARNING: Port {port} is running a potentially insecure service: {port_service}")
    else:
        print(f"No port is open on node {node_name}")
    
    check_nvd(node_ip)
    
    print("-" * 50)
