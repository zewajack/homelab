
---
# Traefik needs PVC to persist ACME certs

```yaml values.yaml
persistence:
  enabled: true
```

Hence default storage class is needed.
If storage class can't be installed disable 

```yaml
persistence:
  enabled: false
```

# Go with Longhorn, if not present install local-path (by rancher)

## For a bare‑metal cluster, the easiest is local-path provisioner:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'  

kubectl get storageclass
```

### run in-case pvc is failed
```bash
kubectl -n traefik delete pvc traefik
helm upgrade traefik traefik/traefik -n traefik -f /root/Traefik/values.yaml
```
---

# Helm Install

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm version
```
---
# 📄 Traefik `values.yaml` for Homelab

```yaml
# Traefik Helm values.yaml
# Save as /root/Traefik/values.yaml

# Service exposed via MetalLB
service:
  type: LoadBalancer
  spec:
    loadBalancerIP: 192.168.0.160   # pick one free IP from your MetalLB pool

# Enable dashboard ingress route
ingressRoute:
  dashboard:
    enabled: true
    entryPoints: ["web"]

# Enable Let's Encrypt with HTTP challenge
additionalArguments:
  - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
  - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
  - "--certificatesresolvers.myresolver.acme.email=admin@b13homelab.in"
  - "--certificatesresolvers.myresolver.acme.storage=/data/acme.json"

# Persistence for ACME certs
persistence:
  enabled: true
  path: /data
  size: 1Gi
  accessModes:
    - ReadWriteOnce

# RBAC
rbac:
  enabled: true

# Logging
logs:
  general:
    level: INFO
  access:
    enabled: true

# initContainer to reset permissions
# Traefik stores Let’s Encrypt certificates in /data/acme.json.

deployment:
  initContainers:
    - name: volume-permissions
      image: busybox:1.36
      command: ["sh", "-c", "chmod 600 /data/acme.json || true"]
      volumeMounts:
        - name: data
          mountPath: /data    
```

---

# 🚀 Install Traefik with Helm

```bash
kubectl create namespace traefik
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik --wait \
  --namespace=traefik \
  -f /root/Traefik/values.yaml
```

---

You should see the Traefik service with an external IP from your MetalLB pool (e.g. `192.168.0.165`).

In Pihole:
```yaml
traefik-lap-k8s 192.168.0.165 (traefik ip assinged by metallb)

dashboard.b13homelab.in/dashboard/ traefik-lap-k8s
```

Access:
- Dashboard: `http://192.168.0.160/dashboard/`
- HTTP entrypoint: `http://192.168.0.160`
- HTTPS entrypoint: `https://192.168.0.160`

---
#
#
#
# Delete old nginx deployment and service

Here’s a clean example of deploying **nginx** in Kubernetes with an **Ingress** (using Traefik as your ingress controller). This will spin up an nginx pod, expose it via a Service, and route traffic through Traefik using an Ingress resource.

---

## 📄 nginx Deployment + Service + Ingress

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: default
spec:
  ingressClassName: traefik
  rules:
  - host: nginx.b13homelab.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
```

---

## 🚀 Steps

1. Save the manifest as `nginx-ingress.yaml`.
2. Apply it:
   ```bash
   kubectl apply -f nginx-ingress.yaml
   ```
3. Verify:
   ```bash
   kubectl get pods
   kubectl get svc
   kubectl get ingress
   ```
4. Update your DNS(Pi-Hole) or `/etc/hosts` to point `nginx.b13homelab.in` to the MetalLB IP assigned to Traefik.

Pi-Hole:

traefik-lap-k8s 192.168.0.160

nginx.b13homelab.in traefik-lap-k8s
---

---

## 📄 Nginx Deployment + Service + Ingress (with TLS)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: myresolver
spec:
  ingressClassName: traefik
  rules:
  - host: nginx.b13homelab.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
  tls:
  - hosts:
    - nginx.b13homelab.in
```

---

## 🔎 Explanation
- **Ingress annotations** tell Traefik to use the `websecure` entrypoint (port 443) and enable TLS.
- **`certresolver: myresolver`** → matches the ACME resolver you configured in your Traefik `values.yaml`.
- **`tls.hosts`** ensures the certificate is requested for `nginx.b13homelab.in`.

---

## 🚀 Steps
1. Save this as `nginx-ingress-tls.yaml`.
2. Apply:
   ```bash
   kubectl apply -f nginx-ingress-tls.yaml
   ```
3. Ensure DNS or `/etc/hosts` points `nginx.b13homelab.in` to your MetalLB IP (e.g. `192.168.0.165`).
4. Test:
   ```bash
   curl -I -k https://nginx.b13homelab.in
   ```
   You should see a valid HTTPS response with a Let’s Encrypt certificate.

---

**Traefik IngressRoute CRD version** of the nginx manifest.
This uses Traefik’s native custom resource (`IngressRoute`) instead of the standard Kubernetes `Ingress`.
It gives you more Traefik‑specific features like fine‑grained TLS control.

---

## 📄 Nginx Deployment + Service + IngressRoute (with TLS)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-ingressroute
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`nginx.b13homelab.in`)
    kind: Rule
    services:
    - name: nginx
      port: 80
  tls:
    certResolver: myresolver
```

---

## 🔎 Explanation
- **`IngressRoute`** is Traefik’s CRD, giving you more control than standard `Ingress`.
- **`entryPoints: websecure`** → routes traffic through HTTPS (port 443).
- **`tls.certResolver: myresolver`** → uses the ACME resolver you configured in your Traefik `values.yaml` for Let’s Encrypt.
- No need for annotations — everything is expressed natively in the CRD.

---

## 🚀 Steps
1. Save this as `nginx-ingressroute.yaml`.
2. Apply:
   ```bash
   kubectl apply -f nginx-ingressroute.yaml
   ```
3. Ensure DNS or `/etc/hosts` points `nginx.b13homelab.in` to your MetalLB IP.
4. Test:
   ```bash
   curl -I -k https://nginx.b13homelab.in
   ```
   You should see a valid HTTPS response with a Let’s Encrypt certificate.

---
