# Traefik dashboard to HTTPS**.
---

# HTTPS via Traefik itself (IngressRoute)

This is the **proper Kubernetes way**.

You will access the dashboard like:

```
https://traefik.b13homelab.in/dashboard/
```

instead of:

```
http://<DNS Name in PiHole>>/dashboard/
```

---

## Create HTTPS IngressRoute for dashboard

Create a file `traefik-dashboard.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.b13homelab.in`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
  tls:
    certResolver: default
```

Apply:

```bash
kubectl apply -f traefik-dashboard.yaml
```

---

## DNS entry (important)

Make sure DNS resolves:

```
traefik.b13homelab.in → 192.168.0.165
```

(Pi-hole local DNS is perfect for this.)

---

## Result

Open:

```
https://traefik.b13homelab.in/dashboard/
```

✅ HTTPS
✅ Uses Traefik TLS
✅ Works perfectly with MetalLB
❌ Dashboard not exposed on raw IP anymore (good)

---

# Strongly Recommended Security Step (DO THIS)

Add **basic auth/username and password** so dashboard isn’t open.

### Create auth secret

```bash
htpasswd -nb admin strongpassword # this is just encrypting the passowrd i.e. strongpassword, at login you need to give admin & strongpassword as username and password
```

```bash
kubectl create secret generic traefik-dashboard-auth \
  -n traefik \
  --from-literal=users='admin:$apr1$NyjghOEn$NFRaG8jNoGJxnXcGvhdl50'
```

### Add middleware

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth
```

Attach middleware to the IngressRoute:

```yaml
middlewares:
  - name: dashboard-auth
```