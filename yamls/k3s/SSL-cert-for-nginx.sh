🔐 Step 1: Generate a Self‑Signed Certificate

On your K3s server, run:


openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./nginx.key \
  -out ./nginx.crt \
  -subj "/CN=nginx.b13homelab.in/O=nginx.b13homelab.in"


This creates:
- nginx.crt → certificate
- nginx.key → private key

📦 Step 2: Create a Kubernetes TLS Secret

kubectl create secret tls nginx-tls \
  --cert=./nginx.crt \
  --key=./nginx.key \
  -n default



📄 Step 3: Update the Ingress Manifest

Replace your current Ingress with this TLS‑enabled version:

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: default
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - nginx.local
    secretName: nginx-tls
  rules:
  - host: nginx.b13homelab.in
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80

Apply it:

kubectl apply -f nginx.yaml