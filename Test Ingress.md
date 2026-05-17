## 1️⃣ Basic Traefik Reachability Test

This confirms **MetalLB + Traefik** are working.

```bash
curl -v http://192.168.0.110
```

### Expected

```text
HTTP/1.1 404 Not Found
```

✅ **Good** → Traefik is reachable

---

## 2️⃣ Correct Ingress Test (MOST IMPORTANT)

Since you’re using **host-based routing**, you **must** send the Host header.

```bash
curl -v \
  -H "Host: whoami.b13home.io" \
  http://192.168.0.110
```

### Expected output (whoami app)

```text
Hostname: whoami-deployment-xxxx
IP: 127.0.0.1
IP: 10.42.x.x
GET / HTTP/1.1
Host: whoami.b13home.io
```

✅ This means:

```
curl → MetalLB IP → Traefik → Ingress → Service → Pod
```

---

## 3️⃣ Test via DNS (If DNS is Configured)

If `whoami.b13home.io` resolves to `192.168.0.110`:

```bash
curl -v http://whoami.b13home.io
```

If DNS is **not** set, test using `--resolve`:

```bash
curl -v \
  --resolve whoami.b13home.io:80:192.168.0.110 \
  http://whoami.b13home.io
```

---

## 4️⃣ HTTPS Test (If You Add TLS Later)

```bash
curl -vk \
  -H "Host: whoami.b13home.io" \
  https://192.168.0.110
```

(You’ll get cert warnings unless TLS is configured)

---

## 5️⃣ Backend Service Sanity Check

Make sure the app works **without ingress**.

```bash
kubectl port-forward svc/whoami-service 8080:80
```

```bash
curl http://localhost:8080
```

If this works but ingress doesn’t → ingress issue
If this fails → pod/service issue

---

## 6️⃣ Traefik Router Debug (Very Helpful)

If you don’t get expected output:

```bash
kubectl logs -n kube-system deploy/traefik | grep whoami
```

You should see router/service creation logs.

---


---

# 1️⃣ DNS Layer Tests (Pi-hole + Unbound)

### 🔹 1.1 Verify DNS resolution path

From the **master node**:

```bash
dig whoami.b13home.io
```

Expected:

```text
whoami.b13home.io.  IN A 192.168.0.110
```

If you want to **force Pi-hole**:

```bash
dig @192.168.0.2 whoami.b13home.io
```

✔ Confirms Pi-hole → Unbound → correct record

---

### 🔹 1.2 Check reverse DNS (optional but pro)

```bash
dig -x 192.168.0.110
```

Useful to detect bad local DNS configs.

---

### 🔹 1.3 Validate Unbound recursion

```bash
dig @192.168.0.2 google.com +trace
```

✔ Confirms Unbound is resolving externally

---

### 🔹 1.4 Confirm no DNS leakage

```bash
resolvectl status
```

Make sure:

* Primary DNS → `192.168.0.2`
* No fallback to ISP router unless intentional

---

# 2️⃣ Ingress + DNS Combined Test (Real Client Simulation)

This simulates a **real browser** request:

```bash
curl -v http://whoami.b13home.io
```

Expected:

* No `--resolve`
* No `Host` header needed
* Should work exactly like a browser

If this works → **DNS + ingress are perfect**

---

# 3️⃣ Network Path Validation (L2 / MetalLB)

### 🔹 3.1 ARP ownership check (MetalLB L2 mode)

From another LAN machine:

```bash
arp -an | grep 192.168.0.110
```

Expected:

* MAC address of **one k3s node**

This proves MetalLB is correctly advertising the IP.

---

### 🔹 3.2 Ping test

```bash
ping 192.168.0.110
```

✔ Confirms L2 reachability

---

# 4️⃣ Kubernetes Service & Endpoint Integrity

### 🔹 4.1 Verify endpoints are synced

```bash
kubectl get endpoints whoami-service
```

Expected:

```text
10.42.x.x:80
```

If empty → selector mismatch (not your case)

---

### 🔹 4.2 Pod → DNS resolution

Exec into pod:

```bash
kubectl exec -it deploy/whoami-deployment -- sh
```

Inside pod:

```sh
nslookup whoami.b13home.io
nslookup google.com
```

✔ Confirms CoreDNS + upstream DNS works

---

# 5️⃣ Traefik-Specific Deep Tests

### 🔹 5.1 Confirm router creation

```bash
kubectl logs -n kube-system deploy/traefik | grep whoami
```

You should see router/service binding logs.

---

### 🔹 5.2 Expose Traefik dashboard (temporary)

```bash
kubectl -n kube-system port-forward svc/traefik 9000:9000
```

Then open:

```
http://localhost:9000/dashboard/
```

Check:

* Router: `whoami@kubernetes`
* Service healthy

(Disable afterward if not needed)

---

# 6️⃣ Load Balancing Test (Very Important)

Scale the deployment:

```bash
kubectl scale deploy whoami-deployment --replicas=3
```

Now run:

```bash
watch -n1 curl -s http://whoami.b13home.io
```

Expected:

* `Hostname:` changes between pods
  ✔ Confirms **service load balancing works**

---

# 7️⃣ Failure & Recovery Tests (Production-Grade)

### 🔹 7.1 Kill a pod

```bash
kubectl delete pod -l app=whoami
```

Traffic should continue without interruption.

---

### 🔹 7.2 Restart Traefik

```bash
kubectl rollout restart deploy/traefik -n kube-system
```

Ingress should recover automatically.

---

### 🔹 7.3 Node failure test (if you have workers)

Shutdown a worker node:

```bash
shutdown now
```

MetalLB should reassign IP if needed.

---

# 8️⃣ TLS Readiness Check (Before cert-manager)

```bash
openssl s_client -connect whoami.b13home.io:443
```

You’ll see cert errors (expected), but connection should succeed.

---

# 9️⃣ Security & Hygiene Checks

```bash
kubectl get ingressclass
kubectl get ingress --all-namespaces
kubectl get svc -A | grep LoadBalancer
```

Ensures:

* No accidental public exposure
* Single ingress controller

---