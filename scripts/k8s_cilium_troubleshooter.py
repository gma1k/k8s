#!/usr/bin/env python3

# Usage Examples: 
# Check Cilium agent status
# python3 k8s_cilium_troubleshooter.py cilium-health
# Test DNS inside a pod
# python3 k8s_cilium_troubleshooter.py dns-check --namespace test-ns --pod-name test-a
# Test if policy allows access
# python3 k8s_cilium_troubleshooter.py policy-check --namespace test-ns --source-pod test-pod-a --target-svc myapp.default.svc.cluster.local --port 80

import subprocess
import typer
from rich.console import Console
from kubernetes import client, config

app = typer.Typer()
console = Console()

def run_cmd(cmd: str):
    """Run a shell command and return output or error."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return e.stderr.strip()

@app.command()
def cilium_health():
    """Check the status of Cilium agents in the cluster."""
    console.rule("[bold cyan] Checking Cilium Status")
    output = run_cmd("cilium status --wait --verbose")
    if "OK" in output:
        console.print(" [green]Cilium agents are healthy[/green]")
    else:
        console.print(" [red]Cilium health check failed[/red]")
    console.print(output)

@app.command()
def pod_ping(source_ns: str, source_pod: str, target_ip: str):
    """Ping from one pod to another."""
    console.rule("[bold cyan] Pod-to-Pod Connectivity Test")
    cmd = f"kubectl exec -n {source_ns} {source_pod} -- ping -c 3 {target_ip}"
    output = run_cmd(cmd)
    if "0% packet loss" in output:
        console.print(f" [green]Ping successful from {source_pod} to {target_ip}[/green]")
    else:
        console.print(f" [red]Ping failed from {source_pod} to {target_ip}[/red]")
    console.print(output)

@app.command()
def dns_check(namespace: str, pod_name: str, hostname: str = "kubernetes.default"):
    """Verify DNS resolution inside a pod."""
    console.rule("[bold cyan] DNS Resolution Test")
    cmd = f"kubectl exec -n {namespace} {pod_name} -- nslookup {hostname}"
    output = run_cmd(cmd)
    if "Address" in output:
        console.print(f" [green]DNS resolution successful for {hostname}[/green]")
    else:
        console.print(f" [red]DNS resolution failed for {hostname}[/red]")
    console.print(output)

@app.command()
def policy_check(namespace: str, source_pod: str, target_svc: str, port: int):
    """Test if a Cilium network policy allows or blocks traffic."""
    console.rule("[bold cyan] Network Policy Enforcement Test")
    cmd = f"kubectl exec -n {namespace} {source_pod} -- curl -s -o /dev/null -w '%{{http_code}}' {target_svc}:{port}"
    output = run_cmd(cmd)
    if output == "200":
        console.print(f" [green]Policy allows access to {target_svc}:{port}[/green]")
    else:
        console.print(f" [red]Policy blocks or service unreachable at {target_svc}:{port}[/red]")
    console.print(f"Response: {output}")

if __name__ == "__main__":
    app()
