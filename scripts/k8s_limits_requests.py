import subprocess
import json
import datetime as dt
import shlex

def execute_kube_command_json(command):
    # Split command safely instead of using shell=True
    command_parts = shlex.split(command)
    kube_command = subprocess.run(
        command_parts,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        shell=False
    )
    if kube_command.returncode != 0:
        raise RuntimeError(f"Command failed: {command}\nError: {kube_command.stderr.decode('utf-8')}")
    json_output = kube_command.stdout.decode("utf-8")
    json_object = json.loads(json_output)
    return json_object

audit_report = {}
command = "kubectl get namespaces -o json"
json_object = execute_kube_command_json(command)
number_of_namespaces = len(json_object["items"])
processed_namespace_count = 1

for namespace in json_object["items"]:
    process_start = dt.datetime.now()
    print("Processing Namespace", processed_namespace_count, "of", number_of_namespaces)
    namespace_name=namespace["metadata"]["name"]
    command = "kubectl get pods -n {namespace} -o json".format(namespace=namespace_name)
    json_object = execute_kube_command_json(command)
    audit_report[namespace_name] = {}
    if not json_object["items"]:
        processed_namespace_count += 1
        process_end = dt.datetime.now()
        if (process_end - process_start).total_seconds() > 0:
            how_long_to_finish = float(number_of_namespaces - processed_namespace_count) / (process_end - process_start).total_seconds() / 60
            if how_long_to_finish < 1:
                how_long_to_finish = how_long_to_finish * 60
                print(how_long_to_finish, "seconds")
            else:
                print(how_long_to_finish, "minutes")
        else:
            print("Calculating time remaining...")
        continue
    else:
        for pod in json_object["items"]:
            audit_report[namespace_name][pod["metadata"]["name"]] = {}
            for container in pod["spec"]["containers"]:
                audit_report[namespace_name][pod["metadata"]["name"]][container["name"]] = {}
                if "resources" in container:
                    if "requests" in container["resources"] and "limits" in container["resources"]:
                        audit_report[namespace_name][pod["metadata"]["name"]][container["name"]] = {
                            "requests": "present",
                            "limits": "present"
                        }
                    elif "limits" in container["resources"] and "requests" not in container["resources"]:
                        audit_report[namespace_name][pod["metadata"]["name"]][container["name"]] = {
                            "requests": "not present",
                            "limits": "present"
                        }
                    elif "limits" not in container["resources"] and "requests" in container["resources"]:
                        audit_report[namespace_name][pod["metadata"]["name"]][container["name"]] = {
                            "requests": "present",
                            "limits": "not present"
                        }
                    else:
                        audit_report[namespace_name][pod["metadata"]["name"]][container["name"]] = {
                            "requests": "not present",
                            "limits": "not present"
                        }
                else:
                    audit_report[namespace_name][pod["metadata"]["name"]][container["name"]] = {
                        "requests": "not present",
                        "limits": "not present"
                    }
    processed_namespace_count += 1
    process_end = dt.datetime.now()
    if (process_end - process_start).total_seconds() > 0:
        how_long_to_finish = float(number_of_namespaces - processed_namespace_count) / (process_end - process_start).total_seconds() / 60
        if how_long_to_finish < 1:
            how_long_to_finish = how_long_to_finish * 60
            print(how_long_to_finish, "seconds")
        else:
            print(how_long_to_finish, "minutes")
    else:
        print("Calculating time remaining...")

print(audit_report)
