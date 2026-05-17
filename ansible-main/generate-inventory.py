#!/usr/bin/env python3
"""
Generate Ansible inventory and group_vars from cluster-config.yml.

Usage:
    python3 generate-inventory.py                     # uses ./cluster-config.yml
    python3 generate-inventory.py my-cluster.yml      # uses custom config file
"""

import sys
import os

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)


def load_config(config_path):
    with open(config_path) as f:
        return yaml.safe_load(f)


def generate_inventory(config):
    ssh_user = config.get("ssh_user", "root")
    ssh_password = config.get("ssh_password")
    ssh_key_file = config.get("ssh_key_file")

    # Build auth vars
    auth_vars = f"    ansible_user: {ssh_user}\n"
    if ssh_key_file:
        auth_vars += f"    ansible_ssh_private_key_file: {ssh_key_file}\n"
    elif ssh_password:
        auth_vars += f"    ansible_password: {ssh_password}\n"
    auth_vars += "    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'\n"

    # Build master hosts
    master_hosts = ""
    for node in config["masters"]:
        master_hosts += f"        {node['hostname']}:\n"
        master_hosts += f"          ansible_host: {node['ip']}\n"

    # Build worker hosts
    worker_hosts = ""
    for node in config.get("workers", []):
        worker_hosts += f"        {node['hostname']}:\n"
        worker_hosts += f"          ansible_host: {node['ip']}\n"

    inventory = f"""all:
  vars:
{auth_vars}  children:
    masters:
      hosts:
{master_hosts}    workers:
      hosts:
{worker_hosts}    k8s_cluster:
      children:
        masters:
        workers:
"""
    return inventory


def generate_group_vars(config):
    components = config.get("components", {})
    master_ip = config["masters"][0]["ip"]

    calico = components.get("calico", {})
    metallb = components.get("metallb", {})
    istio = components.get("istio", {})
    longhorn = components.get("longhorn", {})

    group_vars = f"""---
# Auto-generated from cluster-config.yml — do not edit manually
# Regenerate with: python3 generate-inventory.py

# Kubernetes
k8s_version: "{config.get('k8s_version', '1.35')}"
k8s_full_version: "{config.get('k8s_full_version', 'v1.35.0')}"
pod_network_cidr: "{config.get('pod_network_cidr', '10.244.0.0/16')}"
service_cidr: "{config.get('service_cidr', '10.96.0.0/12')}"
master_ip: "{master_ip}"

# Container runtime
pause_image: "{config.get('pause_image', 'registry.k8s.io/pause:3.10.1')}"

# Component toggles
install_calico: {str(calico.get('enabled', True)).lower()}
install_metallb: {str(metallb.get('enabled', True)).lower()}
install_istio: {str(istio.get('enabled', False)).lower()}
install_longhorn: {str(longhorn.get('enabled', False)).lower()}

# CNI - Calico
calico_version: "{calico.get('version', 'v3.29.0')}"

# MetalLB
metallb_version: "{metallb.get('version', 'v0.14.5')}"
metallb_ip_range: "{metallb.get('ip_range', '192.168.0.160-192.168.0.199')}"

# Istio
istio_version: "{istio.get('version', '1.28.2')}"

# Longhorn
longhorn_namespace: "longhorn-system"
"""
    return group_vars


def main():
    config_path = sys.argv[1] if len(sys.argv) > 1 else "cluster-config.yml"

    if not os.path.exists(config_path):
        print(f"ERROR: Config file not found: {config_path}")
        sys.exit(1)

    config = load_config(config_path)
    cluster_name = config.get("cluster_name", "k8s-cluster")

    # Ensure output directories exist
    os.makedirs("inventory", exist_ok=True)
    os.makedirs("inventory/group_vars", exist_ok=True)

    # Generate files
    inventory = generate_inventory(config)
    group_vars = generate_group_vars(config)

    with open("inventory/hosts.yml", "w") as f:
        f.write(inventory)

    with open("inventory/group_vars/all.yml", "w") as f:
        f.write(group_vars)

    print(f"✅ Generated inventory for cluster: {cluster_name}")
    print(f"   Masters: {len(config['masters'])}")
    print(f"   Workers: {len(config.get('workers', []))}")
    print(f"   Components: ", end="")
    components = config.get("components", {})
    enabled = [k for k, v in components.items() if v.get("enabled", False)]
    print(", ".join(enabled) if enabled else "none")
    print(f"\n   Files written:")
    print(f"     inventory/hosts.yml")
    print(f"     inventory/group_vars/all.yml")


if __name__ == "__main__":
    main()
