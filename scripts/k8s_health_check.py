#!/usr/bin/env python3

"""
Simple Kubernetes health check script.

Features:
- Auto-detects config.
- Lets the user scan all namespaces or a specific namespace.
- Checks:
  * Pod status issues
  * Containers running as root
  * Missing liveness/readiness probes
  * Pods missing resource requests/limits
  * Node condition problems
  * Recent warning Events for failures

"""

import sys
import datetime
from typing import List, Optional, Tuple

from kubernetes import client, config
from kubernetes.config.config_exception import ConfigException

try:
    from colorama import Fore, Style, init as colorama_init

    colorama_init()
    COLOR_OK = Fore.GREEN
    COLOR_WARN = Fore.YELLOW
    COLOR_FAIL = Fore.RED
    COLOR_HEADER = Fore.CYAN
    COLOR_RESET = Style.RESET_ALL
except ImportError:
    COLOR_OK = "\033[92m"
    COLOR_WARN = "\033[93m"
    COLOR_FAIL = "\033[91m"
    COLOR_HEADER = "\033[96m"
    COLOR_RESET = "\033[0m"

def load_kube_config() -> None:
    try:
        config.load_incluster_config()
        return
    except ConfigException:
        pass

    try:
        config.load_kube_config()
        return
    except ConfigException as exc:
        print(
            f"{COLOR_FAIL}[FAIL]{COLOR_RESET} "
            f"Could not load Kubernetes configuration: {exc}"
        )
        sys.exit(1)

def get_core_v1_api() -> client.CoreV1Api:
    return client.CoreV1Api()

def list_namespaces(v1: client.CoreV1Api) -> List[str]:
    ns_list = v1.list_namespace()
    return [ns.metadata.name for ns in ns_list.items]

def get_pods(v1: client.CoreV1Api, namespace: Optional[str]) -> List[client.V1Pod]:
    if namespace is None:
        pods = v1.list_pod_for_all_namespaces()
    else:
        pods = v1.list_namespaced_pod(namespace=namespace)
    return pods.items

def get_nodes(v1: client.CoreV1Api) -> List[client.V1Node]:
    nodes = v1.list_node()
    return nodes.items

def get_events(
    v1: client.CoreV1Api, namespace: Optional[str]
) -> List[client.CoreV1Event]:
    if namespace is None:
        ev = v1.list_event_for_all_namespaces()
    else:
        ev = v1.list_namespaced_event(namespace=namespace)
    return ev.items

def print_header(title: str) -> None:
    print(f"\n{COLOR_HEADER}=== {title} ==={COLOR_RESET}")

def print_result(severity: str, message: str) -> None:
    sev = severity.upper()
    if sev == "OK":
        color = COLOR_OK
    elif sev == "WARN":
        color = COLOR_WARN
    elif sev == "FAIL":
        color = COLOR_FAIL
    else:
        color = COLOR_RESET

    print(f"{color}[{sev}]{COLOR_RESET} {message}")

def check_pod_status_issues(pods: List[client.V1Pod]) -> bool:
    print_header("Pod Status Issues")
    fail_found = False
    issues_found = False

    RESTART_THRESHOLD = 5

    for pod in pods:
        ns = pod.metadata.namespace
        name = pod.metadata.name
        phase = (pod.status.phase or "Unknown").upper()

        if phase in ("FAILED", "UNKNOWN"):
            issues_found = True
            fail_found = True
            print_result(
                "FAIL",
                f"Pod {ns}/{name} is in phase {phase}."
            )

        cstatus_list = pod.status.container_statuses or []
        for cstatus in cstatus_list:
            cname = cstatus.name

            state = cstatus.state
            if state and state.waiting:
                reason = state.waiting.reason or ""
                reason_upper = reason.upper()
                if reason_upper in ("CRASHLOOPBACKOFF", "IMAGEPULLBACKOFF"):
                    issues_found = True
                    fail_found = True
                    print_result(
                        "FAIL",
                        f"Container {ns}/{name}:{cname} in state {reason} "
                        f"({state.waiting.message or ''})"
                    )

            restarts = cstatus.restart_count or 0
            if restarts > RESTART_THRESHOLD:
                issues_found = True
                print_result(
                    "WARN",
                    f"Container {ns}/{name}:{cname} has restarted {restarts} times "
                    f"(threshold {RESTART_THRESHOLD})."
                )

    if not issues_found:
        print_result("OK", "No problematic pod statuses found.")
    return fail_found

def check_containers_running_as_root(pods: List[client.V1Pod]) -> bool:
    print_header("Containers Running as Root")
    fail_found = False
    issues_found = False

    for pod in pods:
        ns = pod.metadata.namespace
        name = pod.metadata.name
        pod_sc = pod.spec.security_context

        pod_run_as_user = getattr(pod_sc, "run_as_user", None) if pod_sc else None

        for container in (pod.spec.containers or []):
            csc = container.security_context
            c_run_as_user = getattr(csc, "run_as_user", None) if csc else None

            effective_run_as_user = c_run_as_user
            if effective_run_as_user is None:
                effective_run_as_user = pod_run_as_user

            if effective_run_as_user == 0:
                issues_found = True
                print_result(
                    "WARN",
                    f"Container {ns}/{name}:{container.name} is explicitly running as root (runAsUser=0)."
                )
            elif effective_run_as_user is None:
                issues_found = True
                print_result(
                    "WARN",
                    f"Container {ns}/{name}:{container.name} has no runAsUser set "
                    f"(may default to root depending on image)."
                )

    if not issues_found:
        print_result("OK", "No containers found that obviously run as root or lack runAsUser.")
    return fail_found

def check_missing_probes(pods: List[client.V1Pod]) -> bool:
    print_header("Missing Liveness / Readiness Probes")
    fail_found = False
    issues_found = False

    for pod in pods:
        ns = pod.metadata.namespace
        name = pod.metadata.name

        for container in (pod.spec.containers or []):
            cname = container.name
            has_liveness = container.liveness_probe is not None
            has_readiness = container.readiness_probe is not None

            if not has_liveness or not has_readiness:
                issues_found = True
                missing = []
                if not has_liveness:
                    missing.append("liveness")
                if not has_readiness:
                    missing.append("readiness")
                missing_str = " and ".join(missing)
                print_result(
                    "WARN",
                    f"Container {ns}/{name}:{cname} is missing {missing_str} probe(s)."
                )

    if not issues_found:
        print_result("OK", "All containers have both liveness and readiness probes.")
    return fail_found

def check_pods_resource_requests_limits(pods: List[client.V1Pod]) -> bool:
    print_header("Resource Requests / Limits")
    fail_found = False
    issues_found = False

    for pod in pods:
        ns = pod.metadata.namespace
        name = pod.metadata.name

        for container in (pod.spec.containers or []):
            cname = container.name
            res = container.resources

            requests = getattr(res, "requests", None) if res else None
            limits = getattr(res, "limits", None) if res else None

            if not requests or not limits:
                issues_found = True
                missing = []
                if not requests:
                    missing.append("requests")
                if not limits:
                    missing.append("limits")
                missing_str = " and ".join(missing)
                print_result(
                    "WARN",
                    f"Container {ns}/{name}:{cname} has missing resource {missing_str}."
                )

    if not issues_found:
        print_result("OK", "All containers have resource requests and limits defined.")
    return fail_found

def check_node_conditions(nodes: List[client.V1Node]) -> bool:
    print_header("Node Conditions")
    fail_found = False
    issues_found = False

    for node in nodes:
        name = node.metadata.name
        conds = node.status.conditions or []

        ready_status = None
        disk_pressure = None
        mem_pressure = None

        for cond in conds:
            ctype = cond.type
            if ctype == "Ready":
                ready_status = cond.status
                if cond.status != "True":
                    issues_found = True
                    fail_found = True
                    print_result(
                        "FAIL",
                        f"Node {name} is NotReady (status={cond.status}, reason={cond.reason}, message={cond.message})."
                    )
            elif ctype == "DiskPressure":
                disk_pressure = cond.status
                if cond.status == "True":
                    issues_found = True
                    fail_found = True
                    print_result(
                        "FAIL",
                        f"Node {name} has DiskPressure (reason={cond.reason}, message={cond.message})."
                    )
            elif ctype == "MemoryPressure":
                mem_pressure = cond.status
                if cond.status == "True":
                    issues_found = True
                    fail_found = True
                    print_result(
                        "FAIL",
                        f"Node {name} has MemoryPressure (reason={cond.reason}, message={cond.message})."
                    )

        if ready_status is None:
            issues_found = True
            fail_found = True
            print_result(
                "FAIL",
                f"Node {name} has no Ready condition reported."
            )

    if not issues_found:
        print_result("OK", "All nodes are Ready with no DiskPressure or MemoryPressure.")
    return fail_found

def _event_timestamp(ev: client.CoreV1Event) -> Optional[datetime.datetime]:
    for attr in ("event_time", "last_timestamp", "first_timestamp", "metadata"):
        value = getattr(ev, attr, None)
        if not value:
            continue
        if attr == "metadata":
            ts = getattr(value, "creation_timestamp", None)
        else:
            ts = value
        if ts:
            return ts
    return None


def check_recent_events(events: List[client.CoreV1Event]) -> bool:
    print_header("Recent Warning Events")
    fail_found = False
    issues_found = False

    now = datetime.datetime.now(datetime.timezone.utc)
    window_minutes = 60
    cutoff = now - datetime.timedelta(minutes=window_minutes)

    fail_reasons = {
        "FailedScheduling",
        "FailedMount",
        "FailedAttachVolume",
        "FailedCreatePodSandBox",
        "FailedCreatePodSandbox",
        "SandboxChanged",
    }

    for ev in events:
        ts = _event_timestamp(ev)
        if ts and ts < cutoff:
            continue

        reason = (ev.reason or "").strip()
        ev_type = (ev.type or "").strip()
        involved = ev.involved_object
        ns = getattr(involved, "namespace", None)
        name = getattr(involved, "name", None)
        kind = getattr(involved, "kind", None)

        is_failure_reason = (
            reason in fail_reasons or
            reason.startswith("Failed")
        )

        if ev_type == "Warning" or is_failure_reason:
            issues_found = True
            message = ev.message or ""
            target = f"{kind} {ns}/{name}" if ns else f"{kind} {name}"
            if is_failure_reason:
                fail_found = True
                print_result(
                    "FAIL",
                    f"Recent event [{reason}] on {target}: {message}"
                )
            else:
                print_result(
                    "WARN",
                    f"Recent warning event [{reason}] on {target}: {message}"
                )

    if not issues_found:
        print_result("OK", f"No recent problematic events in the last {window_minutes} minutes.")
    return fail_found

def ask_namespace_choice(v1: client.CoreV1Api) -> Tuple[Optional[str], str]:
    print_header("Namespace Selection")

    while True:
        choice = input(
            "Do you want to scan ALL namespaces or choose a specific namespace? "
            "[all/specific]: "
        ).strip().lower()

        if choice in ("all", "a"):
            print_result("OK", "Scanning ALL namespaces.")
            return None, "all namespaces"

        if choice in ("specific", "s"):
            namespaces = list_namespaces(v1)
            if not namespaces:
                print_result("FAIL", "No namespaces found in the cluster.")
                sys.exit(1)

            print("Available namespaces:")
            for idx, ns in enumerate(namespaces, start=1):
                print(f"  {idx}. {ns}")

            while True:
                sel = input(
                    "Enter the namespace number or name (or 'back' to choose again): "
                ).strip()

                if sel.lower() == "back":
                    break

                if sel.isdigit():
                    idx = int(sel)
                    if 1 <= idx <= len(namespaces):
                        ns = namespaces[idx - 1]
                        print_result("OK", f"Scanning namespace: {ns}")
                        return ns, f"namespace '{ns}'"
                    else:
                        print_result("WARN", "Invalid number, please try again.")
                        continue

                if sel in namespaces:
                    print_result("OK", f"Scanning namespace: {sel}")
                    return sel, f"namespace '{sel}'"

                print_result(
                    "WARN",
                    "Namespace not found. Please enter a valid number or name."
                )
            continue

        print_result("WARN", "Please type 'all' or 'specific'.")

def main() -> None:
    load_kube_config()
    v1 = get_core_v1_api()

    namespace, ns_desc = ask_namespace_choice(v1)

    print_header("Fetching Cluster Data")
    try:
        pods = get_pods(v1, namespace)
        nodes = get_nodes(v1)
        events = get_events(v1, namespace)
        print_result("OK", f"Fetched {len(pods)} pods, {len(nodes)} nodes, "
                           f"and {len(events)} events from {ns_desc}.")
    except Exception as exc:
        print_result("FAIL", f"Error fetching data from cluster: {exc}")
        sys.exit(1)

    any_fail = False

    if check_pod_status_issues(pods):
        any_fail = True

    if check_containers_running_as_root(pods):
        any_fail = True

    if check_missing_probes(pods):
        any_fail = True

    if check_pods_resource_requests_limits(pods):
        any_fail = True

    if check_node_conditions(nodes):
        any_fail = True

    if check_recent_events(events):
        any_fail = True

    print_header("Summary")
    if any_fail:
        print_result(
            "FAIL",
            "One or more FAIL-level issues were detected."
        )
        sys.exit(1)
    else:
        print_result(
            "OK",
            "No FAIL-level issues detected. Cluster looks healthy according to these checks."
        )
        sys.exit(0)

if __name__ == "__main__":
    main()
