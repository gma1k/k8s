#!/usr/bin/env python3

# Usage Examples: 
# python3 k8s_net_troubleshoot.py <command> [options] 
# python3 k8s_net_troubleshoot.py health
# python3 k8s_net_troubleshoot.py --kubeconfig ~/.kube/k3s.yaml health
# python3 k8s_net_troubleshoot.py connectivity --from <ns/pod> --to <ns/pod> --port <int> [--protocol tcp|udp]
# python3 k8s_net_troubleshoot.py dns-check --from <ns/pod> --domain <fqdn>
# python3 k8s_net_troubleshoot.py trace-flow --from <ns/pod> --to <ns/pod> [--port <int>]

import argparse
import json
import subprocess
import sys
from typing import List, Tuple, Optional

def run_cmd(cmd: List[str], capture_output=True) -> Tuple[int, str, str]:
    """Run a command and return (rc, stdout, stderr)."""
    proc = subprocess.run(
        cmd,
        text=True,
        capture_output=capture_output,
    )
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()

class KubeHelper:
    def __init__(self, kubeconfig: Optional[str] = None, context: Optional[str] = None):
        self.base_cmd = ["kubectl"]
        if kubeconfig:
            self.base_cmd += ["--kubeconfig", kubeconfig]
        if context:
            self.base_cmd += ["--context", context]

    def kubectl(self, *args) -> Tuple[int, str, str]:
        cmd = self.base_cmd + list(args)
        return run_cmd(cmd)

    def get_pod_ip(self, ns: str, pod: str) -> Optional[str]:
        rc, out, err = self.kubectl(
            "get", "pod", pod, "-n", ns, "-o", "jsonpath={.status.podIP}"
        )
        if rc != 0:
            print(f"[ERROR] Failed to get pod IP for {ns}/{pod}: {err}", file=sys.stderr)
            return None
        return out or None

    def exec_in_pod(self, ns: str, pod: str, command: List[str]) -> Tuple[int, str, str]:
        cmd = ["exec", "-n", ns, pod, "--"] + command
        return self.kubectl(*cmd)

    def get_cilium_pods(self) -> List[Tuple[str, str]]:
        rc, out, err = self.kubectl(
            "get", "pods", "-n", "kube-system",
            "-l", "k8s-app=cilium",
            "-o", "jsonpath={range .items[*]}{.metadata.name}{\" \"}{.metadata.namespace}{\"\\n\"}{end}",
        )
        if rc != 0:
            print("[WARN] Unable to list Cilium pods:", err, file=sys.stderr)
            return []
        pods = []
        for line in out.splitlines():
            name, ns = line.split()
            pods.append((ns, name))
        return pods

def cmd_health(args):
    kube = KubeHelper(args.kubeconfig, args.context)

    print("== Cluster node status ==")
    rc, out, err = kube.kubectl("get", "nodes", "-o", "wide")
    print(out if rc == 0 else err)

    print("\n== Cilium pods ==")
    rc, out, err = kube.kubectl(
        "get", "pods", "-n", "kube-system", "-l", "k8s-app=cilium", "-o", "wide"
    )
    print(out if rc == 0 else err)

    print("\n== Cilium status (per pod) ==")
    for ns, pod in kube.get_cilium_pods():
        print(f"\n--- {ns}/{pod} ---")
        rc, out, err = kube.exec_in_pod(ns, pod, ["cilium", "status", "--verbose"])
        if rc == 0:
            print(out)
        else:
            print(f"[ERROR] {err}", file=sys.stderr)

def parse_ns_name(s: str) -> Tuple[str, str]:
    if "/" not in s:
        raise ValueError(f"Expected '<namespace>/<name>', got '{s}'")
    ns, name = s.split("/", 1)
    return ns, name

def cmd_connectivity(args):
    kube = KubeHelper(args.kubeconfig, args.context)
    src_ns, src_pod = parse_ns_name(args.source)
    dst_ns, dst_pod = parse_ns_name(args.target)

    print("== Resolving pod IPs ==")
    src_ip = kube.get_pod_ip(src_ns, src_pod)
    dst_ip = kube.get_pod_ip(dst_ns, dst_pod)
    print(f"Source: {args.source} -> {src_ip}")
    print(f"Target: {args.target} -> {dst_ip}")
    if not src_ip or not dst_ip:
        print("[FATAL] Could not resolve pod IPs, aborting.")
        return

    print("\n== Pinging target from source pod ==")
    rc, out, err = kube.exec_in_pod(src_ns, src_pod, ["ping", "-c", "3", dst_ip])
    print(out if rc == 0 else err)

    print(f"\n== Testing {args.protocol.upper()} connectivity to {dst_ip}:{args.port} ==")
    if args.protocol.lower() == "tcp":
        test_cmd = ["bash", "-c", f"timeout 5 bash -c '</dev/tcp/{dst_ip}/{args.port}' && echo OK || echo FAIL"]
    else:
        test_cmd = ["nc", "-vz", dst_ip, str(args.port)]
    rc, out, err = kube.exec_in_pod(src_ns, src_pod, test_cmd)
    print(out if out else err)

def cmd_dns_check(args):
    kube = KubeHelper(args.kubeconfig, args.context)
    src_ns, src_pod = parse_ns_name(args.source)

    print("== CoreDNS / kube-dns pods ==")
    rc, out, err = kube.kubectl(
        "get", "pods", "-n", "kube-system",
        "-l", "k8s-app=kube-dns", "-o", "wide"
    )
    if rc != 0:
        print("[WARN] Could not list kube-dns pods, trying coredns label...")
        rc, out, err = kube.kubectl(
            "get", "pods", "-n", "kube-system",
            "-l", "k8s-app=kube-dns,app=coredns", "-o", "wide"
        )
    print(out if rc == 0 else err)

    print(f"\n== /etc/resolv.conf in {args.source} ==")
    rc, out, err = kube.exec_in_pod(src_ns, src_pod, ["cat", "/etc/resolv.conf"])
    print(out if rc == 0 else err)

    print(f"\n== nslookup {args.domain} from {args.source} ==")
    rc, out, err = kube.exec_in_pod(src_ns, src_pod, ["nslookup", args.domain])
    print(out if rc == 0 else err)


def cmd_trace_flow(args):
    kube = KubeHelper(args.kubeconfig, args.context)
    src_ns, src_pod = parse_ns_name(args.source)
    dst_ns, dst_pod = parse_ns_name(args.target)

    cilium_pods = kube.get_cilium_pods()
    if not cilium_pods:
        print("[FATAL] No Cilium pods found; cannot run hubble observe")
        return

    c_ns, c_pod = cilium_pods[0]
    print(f"== Using {c_ns}/{c_pod} to run hubble observe ==")

    base_cmd = [
        "hubble", "observe",
        "--from-pod", f"{src_ns}/{src_pod}",
        "--to-pod", f"{dst_ns}/{dst_pod}",
        "--last", "20",
        "--json",
    ]
    if args.port:
        base_cmd += ["--port", str(args.port)]

    rc, out, err = kube.exec_in_pod(c_ns, c_pod, base_cmd)
    if rc != 0:
        print("[ERROR] hubble observe failed:", err, file=sys.stderr)
        return

    print("== Hubble flows (summary) ==")
    for line in out.splitlines():
        try:
            evt = json.loads(line)
        except json.JSONDecodeError:
            continue
        verdict = evt.get("verdict")
        src = evt.get("source", {}).get("identity")
        dst = evt.get("destination", {}).get("identity")
        summary = evt.get("summary", "")
        print(f"{verdict:<10} src={src} dst={dst} {summary}")

def main():
    parser = argparse.ArgumentParser(
        description="Kubernetes + Cilium network troubleshooter"
    )
    parser.add_argument("--kubeconfig", help="Path to kubeconfig", default=None)
    parser.add_argument("--context", help="Kube context", default=None)

    subparsers = parser.add_subparsers(dest="command", required=True)

    p_health = subparsers.add_parser("health", help="Check cluster & Cilium health")
    p_health.set_defaults(func=cmd_health)

    p_conn = subparsers.add_parser("connectivity", help="Test pod-to-pod connectivity")
    p_conn.add_argument("--from", dest="source", required=True, help="source ns/pod")
    p_conn.add_argument("--to", dest="target", required=True, help="target ns/pod")
    p_conn.add_argument("--port", type=int, required=True)
    p_conn.add_argument("--protocol", choices=["tcp", "udp"], default="tcp")
    p_conn.set_defaults(func=cmd_connectivity)

    p_dns = subparsers.add_parser("dns-check", help="Check DNS from a pod")
    p_dns.add_argument("--from", dest="source", required=True, help="source ns/pod")
    p_dns.add_argument("--domain", required=True)
    p_dns.set_defaults(func=cmd_dns_check)

    p_tf = subparsers.add_parser("trace-flow", help="Use Hubble to trace flows")
    p_tf.add_argument("--from", dest="source", required=True, help="source ns/pod")
    p_tf.add_argument("--to", dest="target", required=True, help="target ns/pod")
    p_tf.add_argument("--port", type=int, required=False)
    p_tf.set_defaults(func=cmd_trace_flow)

    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
