# 🏠 b13homelab.in — Kubernetes Homelab Infrastructure

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![k3s](https://img.shields.io/badge/k3s-latest-FFC61C?logo=k3s&logoColor=white)](https://k3s.io/)
[![Calico](https://img.shields.io/badge/CNI-Calico_BGP-E8710A)](https://www.tigera.io/project-calico/)
[![MetalLB](https://img.shields.io/badge/LB-MetalLB_L2-blue)](https://metallb.universe.tf/)
[![Traefik](https://img.shields.io/badge/Ingress-Traefik-24A1C1?logo=traefikproxy&logoColor=white)](https://traefik.io/)
[![Istio](https://img.shields.io/badge/Mesh-Istio-466BB0?logo=istio&logoColor=white)](https://istio.io/)

A production-style multi-cluster Kubernetes homelab running across **VMware VMs** and **bare-metal Mini PCs** on a `/23` network — complete with BGP networking, service mesh, distributed storage, TLS ingress, and local DNS.

---

## 🌐 Network Architecture

```
                        ┌─────────────────────────────────────────┐
                        │        192.168.0.0/23 (510 IPs)         │
                        └─────────────────────────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
         ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
         │  k3s Cluster     │  │  k8s Cluster     │  │  k8s Cluster     │
         │  (VMware)        │  │  (VMware)        │  │  (Bare Metal)    │
         │                  │  │                  │  │                  │
         │  3 nodes         │  │  3 nodes         │  │  3 Mini PCs      │
         │  .100-.102       │  │  .150-.152       │  │  .200-.202       │
         │                  │  │                  │  │                  │
         │  MetalLB Pool:   │  │  MetalLB Pool:   │  │  MetalLB Pool:   │
         │  .110-.149       │  │  .160-.199       │  │  .210-.255       │
         └──────────────────┘  └──────────────────┘  └──────────────────┘
                    │                     │                     │
         ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
         │ Flannel host-gw  │  │ Calico BGP       │  │ Calico BGP       │
         │ Traefik Ingress  │  │ Traefik + Helm   │  │ Istio Mesh       │
         │ MetalLB L2       │  │ MetalLB L2       │  │ MetalLB L2       │
         └──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## 🧱 Cluster Details

| Cluster | Platform | Nodes | CNI | Ingress | LB | Provisioning |
|---------|----------|-------|-----|---------|-----|--------------|
| k3s-lap | VMware (Dell Laptop) | 1 master + 2 workers | Flannel (host-gw) | Traefik (built-in) | MetalLB L2 | k3s installer |
| k8s-lap | VMware (Dell Laptop) | 1 master + 2 workers | Calico BGP | Traefik (Helm) + nginx | MetalLB L2 | Kubespray |
| k8s-mini | Bare Metal (Mini PCs) | 1 master + 2 workers | Calico BGP | Istio Gateway API | MetalLB L2 | Kubespray |

---

## 🛠️ Tech Stack

<table>
<tr><td><b>Category</b></td><td><b>Technologies</b></td></tr>
<tr><td>🐳 Container Runtime</td><td>containerd (systemd cgroups)</td></tr>
<tr><td>☸️ Orchestration</td><td>Kubernetes v1.35, k3s, kubeadm, Kubespray</td></tr>
<tr><td>🌐 CNI</td><td>Calico (BGP/eBPF), Flannel (host-gw)</td></tr>
<tr><td>⚖️ Load Balancer</td><td>MetalLB (Layer 2)</td></tr>
<tr><td>🚪 Ingress</td><td>Traefik (Helm + ACME TLS), nginx Ingress Controller</td></tr>
<tr><td>🕸️ Service Mesh</td><td>Istio + Gateway API CRDs</td></tr>
<tr><td>💾 Storage</td><td>Longhorn (distributed block storage)</td></tr>
<tr><td>🔒 TLS</td><td>Let's Encrypt via Traefik ACME resolver</td></tr>
<tr><td>📡 DNS</td><td>Pi-hole + Unbound (recursive), CoreDNS</td></tr>
<tr><td>🖥️ Hypervisor</td><td>Proxmox, VMware Workstation</td></tr>
<tr><td>⚙️ Automation</td><td>Ansible (Kubespray), ClusterShell (clush), Bash</td></tr>
<tr><td>📦 Package Manager</td><td>Helm 3</td></tr>
</table>

---

## 📁 Repository Structure

```
homelab/
├── Router-Homelab.md                          # Network layout & IP allocation
├── ansible-ubuntu24.10.sh                     # Ansible installation script
├── install-zsh-posh.sh                        # Zsh + Oh My Posh setup
├── calico+kube-proxy+metallb.md               # CNI compatibility guide
├── calico+kube-proxy-CNI-Troubleshooting.md   # Troubleshooting & recovery
├── Test Ingress.md                            # Ingress & DNS validation tests
│
├── k3s-ubuntu24.10-fannel-metallb/
│   └── k3s-installation.md                    # k3s + Flannel + MetalLB setup
│
├── k8s-ubuntu24.10-calico-kube-proxy-metallb-traefik/
│   ├── kubespray-k8s.md                       # Kubespray install (VMware)
│   ├── kubespray-k8s-minipc.md                # Kubespray install (Mini PCs)
│   ├── k8s-metallb-istio-calico-kube-proxy.md # kubeadm + Calico + MetalLB
│   ├── Traefik+4+k8s.md                       # Traefik Helm install + configs
│   └── Traefik+dashboard+https.md             # Dashboard HTTPS + auth
│
├── Istio/
│   └── Istio-Installation.md                  # Istio + Gateway API setup
│
├── extras/
│   ├── Traefik/                               # Dashboard YAMLs + Helm values
│   ├── longhorn/                              # Longhorn install + test scripts
│   └── yamls/                                 # nginx ingress variants
│
├── yamls/
│   ├── k3s/                                   # k3s deployment manifests
│   └── k8s/                                   # k8s deployment manifests
│
├── known-issues/
│   └── metallb-memberlist-secret.md           # MetalLB secret fix
│
├── ssh-keys/                                  # Node SSH keys
├── posh-fonts/                                # Terminal fonts
└── CV/                                        # Resume
```

---

## 🚀 Quick Start Guides

### k3s Cluster (Flannel + MetalLB)
```bash
# Master node
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="--disable servicelb --flannel-backend=host-gw" \
  K3S_TOKEN="<your-token>" sh -

# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

### k8s Cluster (Kubespray + Calico BGP)
```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v
```

### Traefik Ingress (Helm)
```bash
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -n traefik -f values.yaml
```

---

## 🧪 Validation

The repo includes comprehensive tests for the full stack:

- ✅ MetalLB L2 advertisement & ARP verification
- ✅ Traefik ingress routing (Host-based + TLS)
- ✅ DNS resolution chain (Pi-hole → Unbound → authoritative)
- ✅ Longhorn persistence (write → delete pod → read from new pod)
- ✅ Load balancing across replicas
- ✅ Failure & recovery (pod kill, Traefik restart, node shutdown)

---

## 📊 Lessons Learned

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Calico + kube-proxy CrashLoop | Mixed eBPF/BGP state | Choose one mode; use `--skip-phases=addon/kube-proxy` for eBPF |
| MetalLB speaker FailedMount | Missing `memberlist` secret | `kubectl create secret generic memberlist ...` |
| CoreDNS crash | kube-proxy deleted while Calico BGP active | Reinstall kube-proxy or switch to Calico eBPF |
| Traefik PVC pending | No default StorageClass | Install local-path-provisioner or Longhorn |

---

## 📜 License

This is a personal homelab documentation repository. Feel free to reference it for your own setups.

---

<p align="center">
  <i>Built with ☕ and curiosity by <a href="https://linkedin.com/in/awez-shaikh-544b1243">Awez Shaikh</a></i>
</p>
