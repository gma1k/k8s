#!/usr/bin/env python3

"""
Overview
--------
This is a prototype single-file CLI tool to automate basic Cilium policy testing on a Kubernetes cluster.
It supports applying policies, deploying lightweight test pods, running connectivity checks, generating
JSON reports, and cleaning up test resources.

Features included in this prototype
- CLI: implemented with Typer
- Kubernetes interactions: using the official `kubernetes` Python client
- Pod command execution: using kubernetes.stream.stream
- Policy apply path: via Kubernetes API (NetworkPolicy) or `cilium` CLI if provided
- Simple connectivity test: curl or nc from client pod to server pod
- Report output: JSON file with results

Limitations
- This prototype focuses on the common case; it is not production hardened.
- Assumes kubeconfig or in-cluster config is available.
- For Cilium-specific policy import you can install `cilium` CLI and the tool will call it if available.


Usage examples
--------------
# Apply a policy YAML (will try cilium CLI then fall back to kubectl apply via API)
python cilium-policy-tester.py apply-policy --file policies/deny-egress.yaml

# Run tests, teardown after run
python cilium-policy-tester.py run-tests --namespace cilium-test --policy-file policies/deny-egress.yaml --cleanup

# Generate report
python cilium-policy-tester.py report --input last_report.json

"""

from typing import Optional, List, Dict, Any
import json
import os
import time
import tempfile
import subprocess
import sys

import yaml
import typer
from rich.console import Console
from rich.table import Table
from rich import box

from kubernetes import client, config
from kubernetes.client.rest import ApiException
from kubernetes.stream import stream

app = typer.Typer(help="Cilium policy testing CLI prototype")
console = Console()

# ---------------------------
# Helper: Kubernetes client
# ---------------------------

def load_kube_config():
    try:
        config.load_kube_config()
        console.log("Loaded kubeconfig from default location")
    except Exception:
        try:
            config.load_incluster_config()
            console.log("Loaded in-cluster kubeconfig")
        except Exception as e:
            console.print("[red]Failed to load kube config:[/red]" + str(e))
            raise


# ---------------------------
# Utility functions
# ---------------------------

def run_local_cmd(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    console.log(f"Running local cmd: {' '.join(cmd)}")
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=check)


def cilium_cli_available() -> bool:
    try:
        run_local_cmd(["cilium", "version"], check=False)
        return True
    except FileNotFoundError:
        return False


# ---------------------------
# Apply policy
# ---------------------------
@app.command()
def apply_policy(file: str = typer.Option(..., help="Path to policy yaml (Cilium policy or k8s NetworkPolicy)"),
                 namespace: Optional[str] = typer.Option(None, help="Namespace for k8s NetworkPolicy")):
    """Apply a policy file. Tries `cilium policy import` if cilium CLI exists, otherwise attempts kubectl apply via API."""
    load_kube_config()

    # Try cilium CLI first
    if cilium_cli_available():
        console.print("Using cilium CLI to import policy")
        try:
            res = run_local_cmd(["cilium", "policy", "import", file])
            console.print(res.stdout)
            if res.returncode == 0:
                console.print("[green]Policy imported via cilium CLI[/green]")
                raise typer.Exit()
        except subprocess.CalledProcessError as e:
            console.print(f"cilium CLI import failed: {e.stdout}\n{e.stderr}")

    # Fallback: kubectl apply via kubernetes API (for NetworkPolicy or arbitrary manifests)
    console.print("Falling back to kubernetes API apply (creates resources as given in YAML)")
    with open(file) as fh:
        docs = list(yaml.safe_load_all(fh))

    k8s_client = client.ApiClient()

    # iterate over docs and create appropriate resources (best-effort)
    for doc in docs:
        if not isinstance(doc, dict) or 'kind' not in doc:
            continue
        kind = doc['kind']
        ns = doc.get('metadata', {}).get('namespace', namespace) or 'default'
        try:
            if kind.lower() == 'networkpolicy' or kind.lower() == 'networkpolicy':
                net_api = client.NetworkingV1Api(k8s_client)
                console.log(f"Creating NetworkPolicy in namespace {ns}")
                net_api.create_namespaced_network_policy(namespace=ns, body=doc)
                console.print(f"[green]NetworkPolicy created in {ns}[/green]")
            else:
                # Generic create via dynamic client? Use kubectl apply as last resort
                console.log(f"Resource kind {kind} not handled via API; attempting kubectl apply")
                run_local_cmd(["kubectl", "apply", "-f", file])
                break
        except ApiException as e:
            if e.status == 409:
                console.print(f"[yellow]{kind} already exists in {ns}[/yellow]")
            else:
                console.print(f"[red]Failed to create {kind}: {e}[/red]")


# ---------------------------
# Test harness
# ---------------------------

def make_pod_manifest(name: str, image: str = 'curlimages/curl:7.90.0', command: Optional[List[str]] = None, ns: str = 'default') -> Dict[str, Any]:
    cmd = command if command else ["sleep", "3600"]
    pod = {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': name, 'namespace': ns, 'labels': {'app': name}},
        'spec': {
            'containers': [{'name': name, 'image': image, 'command': cmd}],
            'restartPolicy': 'Never'
        }
    }
    return pod


def create_namespace_if_needed(v1: client.CoreV1Api, ns: str):
    try:
        v1.read_namespace(ns)
        console.log(f"Namespace {ns} already exists")
    except ApiException:
        body = client.V1Namespace(metadata=client.V1ObjectMeta(name=ns))
        v1.create_namespace(body)
        console.log(f"Created namespace {ns}")


def create_pod(v1: client.CoreV1Api, pod_manifest: Dict[str, Any], timeout: int = 60) -> bool:
    ns = pod_manifest['metadata']['namespace']
    name = pod_manifest['metadata']['name']
    try:
        v1.create_namespaced_pod(namespace=ns, body=pod_manifest)
    except ApiException as e:
        if e.status == 409:
            console.log(f"Pod {name} already exists in {ns}, continuing")
        else:
            console.print(f"[red]Failed to create pod {name}: {e}[/red]")
            return False

    # wait for pod to be ready (simple loop)
    for _ in range(timeout):
        try:
            p = v1.read_namespaced_pod(name=name, namespace=ns)
            status = p.status
            phase = status.phase or ''
            if phase.lower() == 'running':
                # check container ready
                if status.container_statuses and status.container_statuses[0].ready:
                    console.log(f"Pod {name} is running and ready")
                    return True
            elif phase.lower() in ('succeeded', 'failed'):
                console.log(f"Pod {name} entered {phase}")
                return phase.lower() == 'succeeded'
        except ApiException:
            pass
        time.sleep(1)
    console.print(f"[red]Timeout waiting for pod {name} to be ready[/red]")
    return False


def exec_in_pod(v1: client.CoreV1Api, name: str, ns: str, cmd: List[str], timeout: int = 10) -> Dict[str, Any]:
    try:
        resp = stream(v1.connect_get_namespaced_pod_exec,
                      name,
                      ns,
                      command=cmd,
                      stderr=True, stdin=False,
                      stdout=True, tty=False,
                      _preload_content=True)
        return {'stdout': resp, 'stderr': ''}
    except Exception as e:
        return {'stdout': '', 'stderr': str(e)}


# ---------------------------
# Connectivity test (single case)
# ---------------------------

def test_connectivity(v1: client.CoreV1Api, src_pod: str, dst_ip: str, dst_port: int, ns: str) -> Dict[str, Any]:
    # Try curl then nc
    curl_cmd = ["curl", "-sS", "--connect-timeout", "5", f"http://{dst_ip}:{dst_port}/" ]
    res = exec_in_pod(v1, src_pod, ns, curl_cmd)
    success = False
    reason = ''
    if res['stderr']:
        reason = res['stderr']
    elif 'Connection refused' in res['stdout'] or res['stdout'] == '':
        # try nc
        nc_cmd = ["/bin/sh", "-c", f"nc -z -w 3 {dst_ip} {dst_port} && echo OK || echo FAIL"]
        res_nc = exec_in_pod(v1, src_pod, ns, nc_cmd)
        out = res_nc.get('stdout', '')
        success = 'OK' in out
        reason = res_nc.get('stderr', '')
        return {'success': success, 'stdout': out, 'stderr': reason}
    else:
        success = True
    return {'success': success, 'stdout': res['stdout'], 'stderr': res['stderr']}


# ---------------------------
# Main run-tests command
# ---------------------------
@app.command()
def run_tests(namespace: str = typer.Option('cilium-test', help='Namespace where tests run'),
              policy_file: Optional[str] = typer.Option(None, help='Optional policy file to apply before tests'),
              cleanup: bool = typer.Option(True, help='Delete test resources after run'),
              report_file: Optional[str] = typer.Option(None, help='Path to write JSON report')):
    """Run a set of connectivity tests against a policy.

    Behavior:
    - Create namespace
    - Deploy a simple HTTP server pod (python http.server via busybox or curlimages) on a known port
    - Deploy a client pod
    - Run connectivity checks from client to server (by ClusterIP or pod IP)
    - Optionally cleanup
    """
    load_kube_config()
    k8s_core = client.CoreV1Api()
    apps = client.AppsV1Api()

    create_namespace_if_needed(k8s_core, namespace)

    # Apply policy if provided
    if policy_file:
        apply_policy(file=policy_file, namespace=namespace)

    # Create server pod (simple python http.server)
    server_name = 'server-http'
    server_manifest = make_pod_manifest(name=server_name, image='python:3.11-slim', command=["/bin/sh", "-c", "python -m http.server 8080"], ns=namespace)
    ok = create_pod(k8s_core, server_manifest, timeout=60)
    if not ok:
        console.print("[red]Server pod failed to start - aborting tests[/red]")
        raise typer.Exit(code=1)

    # Create client pod
    client_name = 'client'
    client_manifest = make_pod_manifest(name=client_name, image='curlimages/curl:7.90.0', command=["sleep", "3600"], ns=namespace)
    ok = create_pod(k8s_core, client_manifest, timeout=60)
    if not ok:
        console.print("[red]Client pod failed to start - aborting tests[/red]")
        raise typer.Exit(code=1)

    # Get server pod IP
    server_pod = k8s_core.read_namespaced_pod(name=server_name, namespace=namespace)
    server_ip = server_pod.status.pod_ip
    console.log(f"Server pod IP: {server_ip}")

    # Wait a bit for server to accept
    time.sleep(3)

    # Define tests
    tests = [
        {'name': 'http-8080', 'dst_ip': server_ip, 'dst_port': 8080, 'expect_allowed': True},
    ]

    results = []
    for t in tests:
        console.print(f"Running test {t['name']} -> {t['dst_ip']}:{t['dst_port']}")
        res = test_connectivity(k8s_core, client_name, t['dst_ip'], t['dst_port'], namespace)
        outcome = 'allowed' if res['success'] else 'denied'
        expected = 'allowed' if t['expect_allowed'] else 'denied'
        passed = (outcome == expected)
        console.print(f"Result: {outcome} (expected {expected}) -> {'[green]PASS[/green]' if passed else '[red]FAIL[/red]'}")
        results.append({'test': t['name'], 'dst': f"{t['dst_ip']}:{t['dst_port']}", 'outcome': outcome, 'expected': expected, 'passed': passed, 'raw': res})

    report = {'namespace': namespace, 'policy_file': policy_file, 'timestamp': int(time.time()), 'results': results}

    # Write report
    if not report_file:
        report_file = os.path.join(os.getcwd(), f'cilium_test_report_{int(time.time())}.json')
    with open(report_file, 'w') as fh:
        json.dump(report, fh, indent=2)
    console.print(f"[green]Wrote report to {report_file}[/green]")

    # Show table
    table = Table(title=f"Cilium Policy Test Results", box=box.SIMPLE_HEAVY)
    table.add_column("Test")
    table.add_column("Dest")
    table.add_column("Outcome")
    table.add_column("Expected")
    table.add_column("Passed")
    for r in results:
        table.add_row(r['test'], r['dst'], r['outcome'], r['expected'], str(r['passed']))
    console.print(table)

    if cleanup:
        console.print("Cleaning up test resources...")
        try:
            k8s_core.delete_namespaced_pod(name=client_name, namespace=namespace)
        except ApiException:
            pass
        try:
            k8s_core.delete_namespaced_pod(name=server_name, namespace=namespace)
        except ApiException:
            pass
        # do not delete namespace by default


# ---------------------------
# Report command
# ---------------------------
@app.command()
def report(input: str = typer.Option(..., help='Path to JSON report generated by run-tests'),
           show: bool = typer.Option(True, help='Show summary in terminal')):
    """Load a previous JSON report and pretty-print a summary."""
    with open(input) as fh:
        r = json.load(fh)
    if show:
        console.print(f"Report for namespace: [bold]{r.get('namespace')}[/bold] - policy: {r.get('policy_file')}")
        table = Table(box=box.SIMPLE)
        table.add_column("Test")
        table.add_column("Dest")
        table.add_column("Outcome")
        table.add_column("Expected")
        table.add_column("Passed")
        for t in r.get('results', []):
            table.add_row(t['test'], t['dst'], t['outcome'], t['expected'], str(t['passed']))
        console.print(table)
    else:
        console.print(json.dumps(r, indent=2))


# ---------------------------
# Cleanup command
# ---------------------------
@app.command()
def cleanup(namespace: str = typer.Option('cilium-test', help='Namespace to cleanup'),
            delete_namespace: bool = typer.Option(False, help='Delete the whole namespace')):
    load_kube_config()
    v1 = client.CoreV1Api()
    # delete pods
    try:
        pods = v1.list_namespaced_pod(namespace=namespace)
        for p in pods.items:
            try:
                v1.delete_namespaced_pod(name=p.metadata.name, namespace=namespace)
            except Exception:
                pass
    except ApiException as e:
        console.print(f"[red]Failed to list pods in {namespace}: {e}[/red]")
    if delete_namespace:
        try:
            v1.delete_namespace(namespace)
            console.print(f"Deleted namespace {namespace}")
        except ApiException as e:
            console.print(f"[red]Failed to delete namespace: {e}[/red]")


if __name__ == '__main__':
    app()
