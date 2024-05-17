import subprocess
import json
import datetime as dt

def execute_kube_command_json(command):
    kube_command = subprocess.run(command, stdout=subprocess.PIPE, shell=True)
    json_output = str(kube_command.stdout.decode("utf-8"))
    json_object = json.loads(json_output)
    return json_object

def process_namespace(namespace):
    namespace_name = namespace["metadata"]["name"]
    command = f"kubectl get pods -n {namespace_name} -o json"
    json_object = execute_kube_command_json(command)
    audit_report_probes[namespace_name] = {}
    if not json_object["items"]:
        return
    for pod in json_object["items"]:
        audit_report_probes[namespace_name][pod["metadata"]["name"]] = {}
        for container in pod["spec"]["containers"]:
            audit_report_probes[namespace_name][pod["metadata"]["name"]][container["name"]] = {
                "livenessProbe": "present" if "livenessProbe" in container else "not present",
                "readinessProbe": "present" if "readinessProbe" in container else "not present"
            }

audit_report_probes = {}
command = "kubectl get namespaces -o json"
json_object = execute_kube_command_json(command)
number_of_namespaces = len(json_object["items"])

for processed_namespace_count, namespace in enumerate(json_object["items"], start=1):
    print(f"Processing Namespace {processed_namespace_count} of {number_of_namespaces}")
    process_start = dt.datetime.now()
    process_namespace(namespace)
    process_end = dt.datetime.now()
    how_long_to_finish = float(number_of_namespaces - processed_namespace_count) / (process_end - process_start).total_seconds() / 60
    if how_long_to_finish < 1:
        how_long_to_finish *= 60
        print(f"{how_long_to_finish:.2f} seconds")
    else:
        print(f"{how_long_to_finish:.2f} minutes")

print(audit_report_probes)
