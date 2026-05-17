Calico v3.27+ defaults to eBPF mode on newer Kubernetes (v1.35 in your case).
👉 eBPF mode requires kube-proxy to be DISABLED

kubectl get cm -n kube-system calico-config -o yaml

Look for:

```yaml
calico_backend: bird
```

or

```yaml
calico_backend: none
```

And especially:

```yaml
FELIX_BPFENABLED: "true"
```

If ```BPFENABLED=true``` → kube-proxy must be removed

✅ FIX OPTION 1 (Recommended): Use Calico eBPF (disable kube-proxy)

This is the modern + correct setup for k8s v1.35.

1️⃣ Delete kube-proxy
```bash
kubectl delete daemonset kube-proxy -n kube-system
kubectl delete cm kube-proxy -n kube-system
```

2️⃣ Restart Calico pods
```bash
kubectl rollout restart ds/calico-node -n kube-system
kubectl rollout restart deploy/calico-kube-controllers -n kube-system
```

3️⃣ Verify
```bash
kubectl get pods -n kube-system -o wide
```

✅ FIX OPTION 2: Disable Calico eBPF (keep kube-proxy)

If you want classic iptables kube-proxy, do this instead.

1️⃣ Patch Calico config
```bash
kubectl patch cm calico-config -n kube-system --type merge -p '{
  "data": {
    "FELIX_BPFENABLED": "false"
  }
}'
```

2️⃣ Restart Calico + kube-proxy

```bash
kubectl rollout restart ds/calico-node -n kube-system
kubectl rollout restart ds/kube-proxy -n kube-system
```

## ⚠️ Why calico-node crashes only on worker-01

Notice this:

```
worker-01: calico-node CrashLoop
worker-02: calico-node Running
```

This usually means **kernel / sysctl mismatch**.

Check on `worker-01`:

```bash
lsmod | grep br_netfilter
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
```

They **must be**:

```bash
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

Fix if needed:

```bash
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sysctl --system
reboot
```

---

## 🧪 Final health check

After fixing:

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl get svc -A
```

All nodes should be **Ready**.

## 🚨 Bigger issue still pending: kube-proxy

Even though Calico is now happy, remember:

* You are on **Kubernetes v1.35**
* Calico is running **BGP (BIRD)**, not eBPF
* `kube-proxy` is **crashing on workers**

### kube-proxy is **NOT REQUIRED** when:

* Calico handles routing (BGP)
* You are not explicitly using iptables services

### Strong recommendation (for your setup)

➡ **Remove kube-proxy entirely**

```bash
kubectl delete daemonset kube-proxy -n kube-system
kubectl delete configmap kube-proxy -n kube-system
```

Then:

```bash
kubectl rollout restart ds/calico-node -n kube-system
```

This avoids:

* iptables conflicts
* service routing instability
* random pod restarts

---

# ✅ You must choose ONE of these (no mixing)

## OPTION A (RECOMMENDED for k8s v1.35)

👉 **Calico eBPF + kube-proxy replacement**

## OPTION B (legacy)

👉 **iptables kube-proxy + Calico BGP**

Right now you are in **an invalid middle state**.

---

# 🟢 OPTION A — FIX IT THE RIGHT WAY (Recommended)

This is **best for v1.35**, MetalLB, Istio, and homelab.

## 1️⃣ Enable Calico kube-proxy replacement (eBPF)

Run this **exactly**:

```bash
kubectl patch installation default --type=merge -p '{
  "spec": {
    "calicoNetwork": {
      "linuxDataplane": "BPF"
    }
  }
}'
```

Now enable kube-proxy replacement:

```bash
kubectl patch felixconfiguration default --type=merge -p '{
  "spec": {
    "bpfEnabled": true,
    "kubeProxyReplacement": "Strict"
  }
}'
```

---

## 2️⃣ Make sure kube-proxy is NOT running

```bash
kubectl delete daemonset kube-proxy -n kube-system || true
kubectl delete configmap kube-proxy -n kube-system || true
```

---

## 3️⃣ Restart Calico cleanly

```bash
kubectl rollout restart ds/calico-node -n kube-system
kubectl rollout restart deploy/calico-kube-controllers -n kube-system
```

---

## 4️⃣ Restart CoreDNS

```bash
kubectl rollout restart deploy/coredns -n kube-system
```

---

## 5️⃣ Wait and verify

```bash
kubectl get pods -n kube-system -w
```

### ✅ EXPECTED FINAL STATE

```
calico-node                  Running
calico-kube-controllers      Running
coredns (both pods)          Running
kube-proxy                   NOT PRESENT
```

---

---
🧠 Mental model (remember this)

kubeadm always installs kube-proxy unless told otherwise
Calico BGP does NOT replace kube-proxy
Only eBPF CNIs can replace kube-proxy

✅ Best practice for future installs
If you want classic networking
```bash
kubeadm + Calico (BGP) + kube-proxy
```

If you want modern networking
```bash
kubeadm --skip-phases=addon/kube-proxy
+ Calico eBPF (Strict)
```
---
# 🟢 Stay with BGP → FIX kube-proxy

This keeps:

* Calico install
* BGP mesh
* no reinstall

## 1️⃣ Reinstall kube-proxy cleanly

On the **master**, run:

```bash
kubeadm init phase addon kube-proxy --config /etc/kubernetes/kubeadm-config.yaml
```

If that file does not exist, use:

```bash
kubeadm init phase addon kube-proxy
```

Verify:

```bash
kubectl get ds kube-proxy -n kube-system
```

---

## 2️⃣ Restart everything networking-related

```bash
kubectl rollout restart ds/calico-node -n kube-system
kubectl rollout restart deploy/calico-kube-controllers -n kube-system
kubectl rollout restart deploy/coredns -n kube-system
```

---

## 3️⃣ Verify (this should now go GREEN)

```bash
kubectl get pods -n kube-system
```

### ✅ EXPECTED RESULT

```
calico-node                 Running (all nodes)
calico-kube-controllers     Running
kube-proxy                  Running (all nodes)
coredns                     Running (both pods)
```

---

Here are **clear, reliable steps you can take *during cluster installation* to avoid the kube-proxy / Calico issues you ran into — based on how Kubernetes and Calico work**:

---

## 🚀 1) Pick the *intended networking mode up front*

You must choose **one networking mode** and install accordingly:

### 🅰️ Classic mode (Calico BGP + kube-proxy)

✔ kube-proxy runs (default)
✔ Calico provides Pod networking + BGP route propagation
✔ Service traffic is handled by kube-proxy

This is the *simple default*.

### 🅱️ Modern mode (Calico eBPF *replaces* kube-proxy)

✔ kube-proxy **not installed**
✔ Calico handles both Pod networking and *Service routing* via eBPF
✔ Better performance, fewer iptables conflicts
👉 Must plan for API server connectivity since Calico needs direct access. ([Calico Documentation][1])

Choose one — *don’t mix BGP with missing kube-proxy* (that causes CoreDNS + controller crashes).

---

## 🧱 2) Create the cluster with the right kubeadm flags

### ✅ If you want **classic mode**

Just initialize normally:

```bash
kubeadm init --pod-network-cidr=<your CIDR>
```

Don’t skip installing kube-proxy.
kubeadm will create the kube-proxy DaemonSet automatically.

After that:

```bash
kubectl apply -f <Calico manifest>
```

Calico will work with kube-proxy’s iptables mode.

---

### ✅ If you want **Calico eBPF mode (no kube-proxy)**

This must be done **up front**, because kube-proxy must *not* be installed.

Use:

```bash
kubeadm init \
  --pod-network-cidr=<your CIDR> \
  --skip-phases=addon/kube-proxy
```

This ensures kube-proxy is **not installed by default**. ([Calico Documentation][1])

Then install Calico via the **operator** with eBPF enabled (see next section).

---

## 🧠 3) Install Calico *correctly* for your chosen mode

### 🅰️ Classic BGP mode (keep kube-proxy)

Apply the standard Calico manifests:

```bash
kubectl apply -f https://docs.tigera.io/manifests/calico.yaml
```

This installs Calico in **bird (BGP) + kube-proxy iptables** mode.

---

### 🅱️ eBPF mode (no kube-proxy)

Install Calico via the **Tigera Operator**, customizing it for eBPF:

1. Install the operator:

```bash
kubectl apply -f https://docs.tigera.io/manifests/tigera-operator.yaml
```

2. Create a custom resource enabling eBPF:

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    linuxDataplane: BPF
```

3. Apply it:

```bash
kubectl apply -f custom-resources.yaml
```

This tells Calico to use **eBPF** instead of iptables. ([Calico Documentation][1])

👉 In this mode, kube-proxy must stay disabled — Calico takes over Service routing.

---

## 🔁 4) Ensure API server connectivity for eBPF

In Calico eBPF mode, recommendation is:

✔ Use a *fixed address* (virtual IP / load balancer) for the API server
✔ Configure a ConfigMap with the “real” API server address so Calico can access it directly — since kube-proxy is not in the path. ([Calico Documentation][1])

This step prevents startup failures where Calico can’t talk to the API server.

---

## 🛠 5) Validate during installation

After `kubeadm init`, but *before installing Calico*, confirm:

```bash
kubectl get nodes
kubectl get po -n kube-system
```

Only control plane pods should be running.

Then after installing Calico:

```bash
kubectl get pods -n kube-system -o wide
```

All Calico nodes + controllers should go to **Running** quickly.
If you see CrashLoopBackOff, it’s usually due to:

* kube-proxy missing when Calico expects it
* Calico eBPF misconfigured

---

## 🧯 6) Avoid a mixed state

Do **not**:

❌ Install Calico BGP *then delete kube-proxy*
❌ Enable eBPF without disabling/killing kube-proxy
❌ Apply Calico manifests of one mode while expecting behavior of another

This mismatch is exactly what caused:

* Calico-kube-controllers crash
* CoreDNS crash
* kube-proxy CrashLoopBackOff

---

## 📌 Quick summary (best practices)

| Goal                     | kube-proxy installed? | Calico mode                 |
| ------------------------ | --------------------- | --------------------------- |
| Standard cluster         | Yes                   | BGP / iptables              |
| Modern eBPF cluster      | No                    | eBPF (kubeProxyReplacement) |
| Hybrid (not recommended) | Yes                   | eBPF w/ special configs     |

✔ Decide first
✔ Use `--skip-phases=addon/kube-proxy` if doing eBPF
✔ Configure Calico operator accordingly ([Calico Documentation][1])

---

[1]: https://docs.tigera.io/calico/latest/operations/ebpf/install?utm_source=chatgpt.com "Install in eBPF mode | Calico Documentation"

You can check **kube-proxy mode** (iptables / ipvs / disabled) very easily. Here are the **correct and reliable ways**, in order of usefulness.

---

## ✅ Method 1: Check kube-proxy ConfigMap (MOST IMPORTANT)

This is the **source of truth**.

```bash
kubectl get cm kube-proxy -n kube-system -o yaml
```

Look for this section:

```yaml
mode: "iptables"
```

or

```yaml
mode: "ipvs"
```

### Interpretation

| Value       | Meaning                     |
| ----------- | --------------------------- |
| `iptables`  | Default, classic kube-proxy |
| `ipvs`      | High-performance kube-proxy |
| **missing** | Defaults to `iptables`      |

---

## ✅ Method 2: Check kube-proxy pod arguments

```bash
kubectl get pod -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].spec.containers[0].command}'
```

You’ll see something like:

```text
--proxy-mode=iptables
```

or

```text
--proxy-mode=ipvs
```

---

## ✅ Method 3: Check kube-proxy logs (runtime confirmation)

```bash
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep -i proxy
```

Typical output:

```text
Using iptables proxy
```

or

```text
Using ipvs proxy
```

---

## ✅ Method 4: Node-level verification (IPVS only)

If mode is `ipvs`, on **any node**:

```bash
lsmod | grep ip_vs
```

You should see:

```
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
```

Also:

```bash
ipvsadm -Ln
```

If empty → kube-proxy not managing services.

---

## 🚨 Special case: kube-proxy NOT present

If this returns nothing:

```bash
kubectl get ds kube-proxy -n kube-system
```

Then:

* kube-proxy is **not installed**
* Services **must** be handled by:

  * Calico eBPF, or
  * Cilium, or
  * cluster is broken

---

Check kube-proxy mode.

---

## ✅ What `mode: ""` means (important)

```yaml
mode: ""
```

This means:

➡ **kube-proxy is running in DEFAULT mode = `iptables`**

Kubernetes behavior is:

* `mode: ""` → treated as **iptables**
* Same as explicitly writing:

  ```yaml
  mode: "iptables"
  ```

So there is **nothing wrong** with this ConfigMap.

---

## 🧠 Why Kubernetes does this

kube-proxy defaults to `iptables` to:

* work on all kernels
* avoid IPVS module dependency
* be backward compatible

Only when you **explicitly set**:

```yaml
mode: "ipvs"
```

does it switch.

---

## 🔍 What this means for your cluster

Given:

* `calico_backend: bird`
* kube-proxy mode = **iptables**

✅ This is a **valid and supported combination**
---

## ✅ Recommended next step (stabilize completely)

Let’s **explicitly set iptables mode** so there’s zero ambiguity.

### 1️⃣ Edit kube-proxy ConfigMap

```bash
kubectl edit cm kube-proxy -n kube-system
```

Change:

```yaml
mode: ""
```

To:

```yaml
mode: "iptables"
```

Save & exit.

---

### 2️⃣ Restart kube-proxy

```bash
kubectl rollout restart ds kube-proxy -n kube-system
```

---

### 3️⃣ Restart CoreDNS + Calico controllers

```bash
kubectl rollout restart deploy coredns -n kube-system
kubectl rollout restart deploy calico-kube-controllers -n kube-system
```

---

## 🧪 Verify final state

```bash
kubectl get pods -n kube-system
```

You should now see:

```
kube-proxy               Running (all nodes)
calico-node              Running
calico-kube-controllers  Running
coredns                  Running
```
---

