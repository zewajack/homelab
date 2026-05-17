# Ansible K8s Cluster Installer

Reusable Ansible automation for Kubernetes cluster installation. Supports different clusters, IP ranges, and optional components via a single config file.

## Quick Start

```bash
# 1. Copy to control node and set up (one-time)
scp -r ansible/ root@nexus.b13homelab.io:/root/ansible/
ssh root@nexus.b13homelab.io
chmod 755 /root/ansible
cd /root/ansible
bash setup.sh

# 2. Activate the environment
source .venv/bin/activate

# 3. Edit cluster config
vim cluster-config.yml

# 4. Generate inventory from config
python3 generate-inventory.py

# 5. Verify connectivity
ansible all -m ping

# 6. Install cluster
ansible-playbook playbooks/site.yml

# 7. Done — deactivate when finished
deactivate
```

## Stack

- **Kubernetes** v1.35 (kubeadm)
- **Container Runtime**: containerd (apt, SystemdCgroup)
- **CNI**: Calico (BGP/Bird) — required
- **Load Balancer**: MetalLB (L2 mode) — required
- **Service Mesh**: Istio — *optional*
- **Storage**: Longhorn (Helm) — *optional*

## Cluster Configuration

All cluster-specific settings live in **`cluster-config.yml`**. Edit this one file, then regenerate:

```yaml
cluster_name: my-cluster

ssh_user: root
ssh_password: toor

masters:
  - hostname: master-01
    ip: 10.0.0.10

workers:
  - hostname: worker-01
    ip: 10.0.0.11
  - hostname: worker-02
    ip: 10.0.0.12

k8s_version: "1.35"
k8s_full_version: "v1.35.0"
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"

components:
  calico:
    enabled: true
    version: "v3.29.0"
  metallb:
    enabled: true
    version: "v0.14.5"
    ip_range: "10.0.0.100-10.0.0.150"
  istio:
    enabled: false          # set true to install
    version: "1.28.2"
  longhorn:
    enabled: false          # set true to install
```

### Generate inventory

```bash
python3 generate-inventory.py                       # reads ./cluster-config.yml
python3 generate-inventory.py examples/mini-k8s-cluster.yml  # or a custom config
```

This generates `inventory/hosts.yml` and `inventory/group_vars/all.yml`. Do **not** edit those files directly.

### Example configs

See `examples/` for ready-to-use configs:
- `lap-k8s-cluster.yml` — Full stack (Calico + MetalLB + Istio + Longhorn)
- `mini-k8s-cluster.yml` — Minimal (Calico + MetalLB only, no Istio/Longhorn)

## Prerequisites

- **Control node**: Any Linux machine with Python 3 and SSH access to target VMs
- **Target VMs**: Ubuntu 24.04 with SSH (password or key-based)
- **Network**: All nodes reachable from the control node

## Setup

Run the setup script once on the control node. It creates a Python venv inside the project directory and installs Ansible + dependencies:

```bash
cd /root/ansible    # or wherever you placed the project
bash setup.sh
```

This creates `.venv/` with Ansible ready to use. No system-wide Python packages needed.

## Usage

Always activate the venv first:

```bash
source .venv/bin/activate
```

### Full cluster install

```bash
# Optional: reset existing cluster first
ansible-playbook playbooks/00-reset-cluster.yml

# Full install
ansible-playbook playbooks/site.yml
```

### Run individual phases

```bash
ansible-playbook playbooks/01-system-prep.yml
ansible-playbook playbooks/02-containerd.yml
ansible-playbook playbooks/03-k8s-packages.yml
ansible-playbook playbooks/04-init-master.yml
ansible-playbook playbooks/05-join-workers.yml
ansible-playbook playbooks/06-calico.yml
ansible-playbook playbooks/07-metallb.yml
ansible-playbook playbooks/08-istio.yml      # skipped if install_istio=false
ansible-playbook playbooks/09-longhorn.yml   # skipped if install_longhorn=false
```

### Test connectivity

```bash
ansible all -m ping
```

### Reset cluster (tear down)

```bash
ansible-playbook playbooks/00-reset-cluster.yml
```

### Deactivate when done

```bash
deactivate
```

## Project Structure

```
ansible/
├── setup.sh                 # One-time setup (creates .venv, installs Ansible)
├── cluster-config.yml       # ← Edit this (IPs, components, toggles)
├── generate-inventory.py    # Generates inventory from config
├── ansible.cfg              # Ansible settings
├── .venv/                   # Python venv (created by setup.sh, gitignored)
├── inventory/
│   ├── hosts.yml            # Generated — do not edit directly
│   └── group_vars/all.yml   # Generated — do not edit directly
├── playbooks/
│   ├── site.yml             # Full orchestration
│   ├── 00-reset-cluster.yml
│   ├── 01-system-prep.yml
│   └── ...
├── roles/
│   ├── system-prep/
│   ├── containerd/
│   ├── k8s-packages/
│   ├── k8s-master/
│   ├── k8s-worker/
│   ├── calico/
│   ├── metallb/
│   ├── istio/
│   ├── longhorn/
│   └── reset/
└── examples/
    ├── lap-k8s-cluster.yml  # Full stack example
    └── mini-k8s-cluster.yml # Minimal example
```

> **Note:** If running from WSL, `ANSIBLE_CONFIG=./ansible.cfg` may be needed because WSL mounts are world-writable, causing Ansible to ignore `ansible.cfg` by default. On a native Linux control node this is not needed.
