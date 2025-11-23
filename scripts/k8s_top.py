#!/usr/bin/env python3

from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, DataTable, Static, TextLog, Select
from textual.containers import Horizontal, Vertical
from textual.reactive import reactive

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from kubernetes import client, config
from kubernetes.client import ApiException


@dataclass
class PodInfo:
    name: str
    namespace: str
    node: str
    status: str
    restarts: int
    age: str
    cpu: str
    memory: str


@dataclass
class NodeInfo:
    name: str
    status: str
    cpu_usage: str
    mem_usage: str


def parse_quantity(q: str) -> float:
    if q is None:
        return 0.0
    q = str(q).strip()
    if not q:
        return 0.0

    if q.endswith("n"):
        return float(q[:-1]) / 1e9
    if q.endswith("u"):
        return float(q[:-1]) / 1e6
    if q.endswith("m"):
        return float(q[:-1]) / 1000.0

    factors = {
        "Ki": 1024,
        "Mi": 1024**2,
        "Gi": 1024**3,
        "Ti": 1024**4,
        "Pi": 1024**5,
        "Ei": 1024**6,
        "K": 1000,
        "M": 1000**2,
        "G": 1000**3,
    }
    for suffix, factor in factors.items():
        if q.endswith(suffix):
            return float(q[:-len(suffix)]) * factor

    return float(q)


class KubernetesBackend:
    def __init__(self):
        try:
            config.load_incluster_config()
        except config.ConfigException:
            config.load_kube_config()

        self.core = client.CoreV1Api()
        self.custom = client.CustomObjectsApi()

    def list_namespaces(self) -> List[str]:
        ns_list = self.core.list_namespace()
        return sorted([i.metadata.name for i in ns_list.items])

    def _pod_metrics_by_ns(self) -> Dict[Tuple[str, str], Dict]:
        metrics = {}
        try:
            pod_metrics = self.custom.list_cluster_custom_object(
                group="metrics.k8s.io",
                version="v1beta1",
                plural="pods",
            )
        except ApiException:
            return metrics

        for item in pod_metrics.get("items", []):
            ns = item["metadata"]["namespace"]
            name = item["metadata"]["name"]
            metrics[(ns, name)] = item
        return metrics

    def _node_metrics_by_name(self) -> Dict[str, Dict]:
        metrics = {}
        try:
            node_metrics = self.custom.list_cluster_custom_object(
                group="metrics.k8s.io",
                version="v1beta1",
                plural="nodes",
            )
        except ApiException:
            return metrics

        for item in node_metrics.get("items", []):
            name = item["metadata"]["name"]
            metrics[name] = item
        return metrics

    def list_pods_for_namespace(self, namespace: str) -> List[PodInfo]:
        now = datetime.now(timezone.utc)
        pod_list = self.core.list_namespaced_pod(namespace=namespace)
        metrics = self._pod_metrics_by_ns()
        pods: List[PodInfo] = []

        for pod in pod_list.items:
            name = pod.metadata.name
            node = pod.spec.node_name or "N/A"
            status = pod.status.phase or "Unknown"
            restarts = 0
            if pod.status.container_statuses:
                restarts = sum(cs.restart_count for cs in pod.status.container_statuses)

            start_time = pod.status.start_time or now
            age_delta = now - start_time
            days = age_delta.days
            hours = age_delta.seconds // 3600
            if days > 0:
                age = f"{days}d{hours}h"
            else:
                mins = (age_delta.seconds % 3600) // 60
                age = f"{hours}h{mins}m"

            cpu_str = "-"
            mem_str = "-"

            m = metrics.get((namespace, name))
            if m:
                total_cpu_cores = 0.0
                total_mem_bytes = 0.0
                for c in m.get("containers", []):
                    usage = c.get("usage", {})
                    cpu_q = usage.get("cpu")
                    mem_q = usage.get("memory")
                    if cpu_q:
                        total_cpu_cores += parse_quantity(cpu_q)
                    if mem_q:
                        total_mem_bytes += parse_quantity(mem_q)

                cpu_m = int(total_cpu_cores * 1000)
                if total_mem_bytes > 0:
                    mem_mib = int(total_mem_bytes / (1024**2))
                else:
                    mem_mib = 0
                cpu_str = f"{cpu_m}m"
                mem_str = f"{mem_mib}Mi"

            pods.append(
                PodInfo(
                    name=name,
                    namespace=namespace,
                    node=node,
                    status=status,
                    restarts=restarts,
                    age=age,
                    cpu=cpu_str,
                    memory=mem_str,
                )
            )
        return pods

    def list_nodes(self) -> List[NodeInfo]:
        node_list = self.core.list_node()
        metrics = self._node_metrics_by_name()
        nodes: List[NodeInfo] = []

        for node in node_list.items:
            name = node.metadata.name
            conditions = {c.type: c.status for c in node.status.conditions or []}
            ready = conditions.get("Ready", "Unknown")
            status = "Ready" if ready == "True" else "NotReady"

            cpu_capacity_cores = parse_quantity(node.status.capacity.get("cpu", "0"))
            mem_capacity_bytes = parse_quantity(node.status.capacity.get("memory", "0"))

            cpu_usage_pct = "-"
            mem_usage_pct = "-"

            m = metrics.get(name)
            if m:
                usage = m.get("usage", {})
                cpu_used = parse_quantity(usage.get("cpu", "0"))
                mem_used = parse_quantity(usage.get("memory", "0"))

                if cpu_capacity_cores > 0:
                    cpu_pct = cpu_used / cpu_capacity_cores * 100.0
                    cpu_usage_pct = f"{cpu_pct:.1f}%"
                if mem_capacity_bytes > 0:
                    mem_pct = mem_used / mem_capacity_bytes * 100.0
                    mem_usage_pct = f"{mem_pct:.1f}%"

            nodes.append(
                NodeInfo(
                    name=name,
                    status=status,
                    cpu_usage=cpu_usage_pct,
                    mem_usage=mem_usage_pct,
                )
            )

        return nodes

    def get_pod_logs(
        self,
        namespace: str,
        pod: str,
        container: Optional[str] = None,
        tail_lines: int = 200,
    ) -> str:
        try:
            return self.core.read_namespaced_pod_log(
                name=pod,
                namespace=namespace,
                container=container,
                tail_lines=tail_lines,
                timestamps=True,
            )
        except ApiException as e:
            return f"Error fetching logs: {e}\n"


class NodesTable(Static):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.table = DataTable(zebra_stripes=True)

    def compose(self) -> ComposeResult:
        yield self.table

    def on_mount(self) -> None:
        self.table.cursor_type = "row"
        self.table.add_columns("Node", "Status", "CPU", "Memory")

    def update_nodes(self, nodes: List[NodeInfo]) -> None:
        self.table.clear()
        for n in nodes:
            self.table.add_row(n.name, n.status, n.cpu_usage, n.mem_usage)


class PodsTable(Static):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.table = DataTable(zebra_stripes=True)
        self._pods: List[PodInfo] = []

    def compose(self) -> ComposeResult:
        yield self.table

    def on_mount(self) -> None:
        self.table.cursor_type = "row"
        self.table.add_columns(
            "Pod",
            "Status",
            "CPU",
            "Memory",
            "Restarts",
            "Node",
            "Age",
        )

    def update_pods(self, pods: List[PodInfo]) -> None:
        self._pods = pods
        self.table.clear()
        for p in pods:
            self.table.add_row(
                p.name,
                p.status,
                p.cpu,
                p.memory,
                str(p.restarts),
                p.node,
                p.age,
            )

    def get_selected_pod(self) -> Optional[PodInfo]:
        if not self._pods:
            return None
        if self.table.cursor_row is None:
            return None
        idx = self.table.cursor_row
        if 0 <= idx < len(self._pods):
            return self._pods[idx]
        return None


class K8sTopApp(App):

    CSS_PATH = None
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh now"),
    ]

    namespaces: reactive[List[str]] = reactive(list)
    selected_namespace: reactive[Optional[str]] = reactive(None)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.backend = KubernetesBackend()

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical():
                self.ns_select = Select(prompt="Namespace", options=[])
                yield self.ns_select
                self.nodes_table = NodesTable()
                yield self.nodes_table
            with Vertical():
                self.pods_table = PodsTable()
                yield self.pods_table
                self.logs = TextLog(highlight=True)
                self.logs.write("Select a pod to view logs...")
                yield self.logs
        yield Footer()

    async def on_mount(self) -> None:
        await self.refresh_all()
        self.set_interval(5.0, self.refresh_all)
        self.set_interval(3.0, self.refresh_logs)

    async def action_refresh(self) -> None:
        await self.refresh_all()

    async def refresh_all(self) -> None:
        ns_list = self.backend.list_namespaces()
        if ns_list != self.namespaces:
            self.namespaces = ns_list
            options = [(ns, ns) for ns in ns_list]
            self.ns_select.options = options
            if not self.selected_namespace and ns_list:
                self.selected_namespace = (
                    "default" if "default" in ns_list else ns_list[0]
                )
                self.ns_select.value = self.selected_namespace

        nodes = self.backend.list_nodes()
        self.nodes_table.update_nodes(nodes)

        if self.selected_namespace:
            pods = self.backend.list_pods_for_namespace(self.selected_namespace)
            self.pods_table.update_pods(pods)

    async def refresh_logs(self) -> None:
        pod = self.pods_table.get_selected_pod()
        if not pod:
            return
        logs = self.backend.get_pod_logs(pod.namespace, pod.name, tail_lines=200)
        self.logs.clear()
        if not logs:
            self.logs.write("No logs.")
            return
        for line in logs.splitlines():
            self.logs.write(line)

    async def on_select_changed(self, event: Select.Changed) -> None:
        if event.select is self.ns_select:
            self.selected_namespace = event.value
            await self.refresh_all()

    async def on_data_table_row_highlighted(
        self, event: DataTable.RowHighlighted
    ) -> None:
        await self.refresh_logs()


if __name__ == "__main__":
    K8sTopApp().run()
