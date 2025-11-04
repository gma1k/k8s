#!/usr/bin/env python3

from kubernetes import client, config
import yaml
import json
from datetime import datetime

def load_kube_config():
    try:
        config.load_kube_config()
    except Exception:
        config.load_incluster_config()

def fetch_cilium_policies(api):
    policies = []
    try:
        cnps = api.list_cluster_custom_object(
            group="cilium.io",
            version="v2",
            plural="ciliumnetworkpolicies"
        )
        for p in cnps.get("items", []):
            policies.append(("CNP", p))

        ccnps = api.list_cluster_custom_object(
            group="cilium.io",
            version="v2",
            plural="ciliumclusterwidenetworkpolicies"
        )
        for p in ccnps.get("items", []):
            policies.append(("CCNP", p))

    except client.exceptions.ApiException as e:
        print(f"Error fetching policies: {e}")
    return policies

def parse_policy(policy_type, policy):
    meta = policy.get("metadata", {})
    spec = policy.get("spec", {})

    name = meta.get("name", "<unknown>")
    namespace = meta.get("namespace", "<clusterwide>")
    summary = {
        "type": policy_type,
        "name": name,
        "namespace": namespace,
        "ingress": [],
        "egress": []
    }

    for direction in ["ingress", "egress"]:
        rules = spec.get(direction, [])
        for rule in rules:
            entry = {}
            if "fromEndpoints" in rule:
                entry["fromEndpoints"] = [
                    r.get("matchLabels") for r in rule["fromEndpoints"]
                ]
            if "toEndpoints" in rule:
                entry["toEndpoints"] = [
                    r.get("matchLabels") for r in rule["toEndpoints"]
                ]
            if "toPorts" in rule:
                entry["ports"] = [
                    p.get("ports") for p in rule["toPorts"] if p.get("ports")
                ]
            if "toEntities" in rule:
                entry["entities"] = rule["toEntities"]

            summary[direction].append(entry)

    return summary

def main():
    load_kube_config()
    api = client.CustomObjectsApi()
    policies = fetch_cilium_policies(api)

    print(f"\nFound {len(policies)} Cilium policies\n")
    summaries = []
    for ptype, policy in policies:
        parsed = parse_policy(ptype, policy)
        summaries.append(parsed)

        print(f"🔹 {ptype}: {parsed['name']} (ns={parsed['namespace']})")
        if parsed["ingress"]:
            print("  ↳ Ingress rules:")
            for r in parsed["ingress"]:
                print(f"    - {yaml.safe_dump(r, sort_keys=False).strip()}")
        if parsed["egress"]:
            print("  ↳ Egress rules:")
            for r in parsed["egress"]:
                print(f"    - {yaml.safe_dump(r, sort_keys=False).strip()}")
        print()

    filename = f"cilium_policy_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(filename, "w") as f:
        json.dump(summaries, f, indent=2)
    print(f"Saved summary to {filename}")

if __name__ == "__main__":
    main()
