---

## 🚀 K3s + Flannel (host-gw) + MetalLB Setup Guide

> ✅ Uses **Flannel host-gw** (instead of VXLAN)
> ✅ Uses **MetalLB (L2 / native mode)** for LoadBalancer IPs
> ✅ Perfect for **bare-metal & VMware homelabs**

---

## 🔁 Change Flannel Default Backend (VXLAN ➜ host-gw)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --flannel-backend=host-gw \
  --token b13homelab.in
```

---

# ============================================================
# 🧱 K3s + Flannel (host-gw) + MetalLB Installation
# ============================================================

## 🟢 Step 1: Install K3s (Server Node)

🔧 Configuration:

* ❌ Disable built-in ServiceLB
* 🌐 Use Flannel **host-gw**
* 🔑 Define cluster token

```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="--disable servicelb --flannel-backend=host-gw" \
  K3S_TOKEN="b13homelab.in" sh -
```

---

## 🟦 Step 2: Install MetalLB

📦 MetalLB runs in **native (L2) mode**

```bash
kubectl create namespace metallb-system; sleep 5
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

---

## 🌈 Step 3: Configure MetalLB IP Address Pool

> ⚠️ Choose **ONE** IP range that fits your LAN
> ⚠️ Make sure these IPs are **free / unused**

---

### 🖥️ Option A: VMware / VM Lab

📍 IP Range: `192.168.0.110 – 192.168.0.149`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.110 - 192.168.0.149
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
```

cat <<'EOF' | kubectl delete -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF

---

### 🧱 Option B: Bare-Metal Lab

📍 IP Range: `192.168.1.50 – 192.168.1.99`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.110 - 192.168.0.149
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
```

---

### 📝 Option C: Save Config to File (Recommended)

📍 IP Range: `192.168.1.70 – 192.168.1.99`

```bash
cat <<EOF > metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.70-192.168.1.99
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF

kubectl apply -f metallb-config.yaml
```

---

# ============================================================

# 🧹 Cleanup / Uninstall (Reverse Order)

# ============================================================

## ❌ Uninstall K3s Server

```bash
/usr/local/bin/k3s-uninstall.sh

rm -f metallb-config.yaml
rm -rf /var/lib/rancher/k3s
rm -rf /etc/rancher/k3s
rm -rf /var/lib/cni
rm -rf /var/lib/kubelet
rm -rf /etc/cni
```

---

## ❌ Uninstall K3s Agent (Worker)

```bash
/usr/local/bin/k3s-agent-uninstall.sh

rm -rf /var/lib/rancher/k3s
rm -rf /etc/rancher/k3s
rm -rf /var/lib/cni
rm -rf /var/lib/kubelet
rm -rf /etc/cni
```

---

# ============================================================

# 🧭 Kubectl Context Naming

# ============================================================

```bash
kubectl config rename-context default k3s-lap-cluster
kubectl config rename-context default k3s-miniPC-cluster
```
---

# ============================================================

# 👷 Add Worker Node to Cluster

# ============================================================

### 🧠 Token Format Explained

```
<prefix><cluster-CA-hash>::<credentials>
```

* 🔐 **Prefix** – K3s token identifier
* 🧾 **Cluster CA hash** – Validates server identity
* 👤 **Credentials** – Token used by joining node

---

## 🔌 Important Notes

* 🔓 **Port 6443 MUST be open**
* 🔁 Both token formats work

---

## ✅ Join Worker Node (Simple Token)

```bash VMWare VM
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.0.100:6443" \
  K3S_TOKEN="b13homelab.in" \
  INSTALL_K3S_EXEC="agent" sh -
```

```bash miniPC
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.0.200:6443" \
  K3S_TOKEN="b13homelab.in" \
  INSTALL_K3S_EXEC="agent" sh -
```

---

## 🔑 Get Node Token (from Server)

```bash
cat /var/lib/rancher/k3s/server/node-token
```

## ✅ Join Worker Node (Full Token)

```bash VMWare VM
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.0.100:6443" \
  K3S_TOKEN="K105caf44ecc87f557ab3660c9d357ab974915aeec285985ba179f4d23aafb2a6b0::server:b13homelab.in" \
  INSTALL_K3S_EXEC="agent" sh -
```
```bash miniPC
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.0.200:6443" \
  K3S_TOKEN="K105caf44ecc87f557ab3660c9d357ab974915aeec285985ba179f4d23aafb2a6b0::server:b13homelab.in" \
  INSTALL_K3S_EXEC="agent" sh -
```
---

✨ **You now have a clean K3s cluster with host-gw networking and MetalLB LoadBalancers!**