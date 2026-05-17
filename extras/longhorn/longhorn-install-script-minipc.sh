#!/bin/bash

clush -g k8sphylocal "modprobe iscsi_tcp && modprobe nbd"

clush -g k8sphylocal "echo -e "iscsi_tcp\nnbd" | tee /etc/modules-load.d/longhorn.conf"
clush -g k8sphylocal "apt upgrade && apt update && apt install -y open-iscsi"
clush -g k8sphylocal "systemctl enable --now iscsid"

clush -g k8sphylocal "systemctl status iscsid"

clush -w 192.168.0.200 'helm repo add longhorn https://charts.longhorn.io'
clush -w 192.168.0.200 'helm repo update'

clush -w 192.168.0.200 'kubectl create namespace longhorn-system'

clush -w 192.168.0.200 'mkdir /root/longhorn'

scp ingress-traefik.yaml ingress-nginx.yaml longhorn-values.yaml longhorn-persistence-test.sh 192.168.0.200:/root/longhorn/

clush -w 192.168.0.200 'helm install longhorn longhorn/longhorn \
  -n longhorn-system \
  -f /root/longhorn/longhorn-values.yaml'

# helm uninstall longhorn -n longhorn-system

# Nginx

# clush -w 192.168.0.200 "cat <<'EOF' | kubectl apply -f -
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: longhorn-ui
#   namespace: longhorn-system
#   annotations:
#     kubernetes.io/ingress.class: nginx
#     nginx.ingress.kubernetes.io/rewrite-target: /
#     nginx.ingress.kubernetes.io/ssl-redirect: \"true\"
# spec:
#   ingressClassName: nginx
#   rules:
#   - host: longhorn-lap-k8s.b13homelab.in
#     http:
#       paths:
#       - path: /
#         pathType: Prefix
#         backend:
#           service:
#             name: longhorn-frontend
#             port:
#               number: 80
#   tls:
#   - hosts:
#     - longhorn-lap-k8s.b13homelab.in
#     secretName: longhorn-tls
# EOF"

# Traefik

# clush -w 192.168.0.200 "cat <<'EOF' | kubectl apply -f -
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: longhorn-ui
#   namespace: longhorn-system
#   annotations:
#     traefik.ingress.kubernetes.io/router.entrypoints: websecure
#     traefik.ingress.kubernetes.io/router.tls: \"true\"
#     traefik.ingress.kubernetes.io/router.tls.certresolver: myresolver
# spec:
#   ingressClassName: traefik
#   rules:
#   - host: longhorn-lap-k8s.b13homelab.in
#     http:
#       paths:
#       - path: /
#         pathType: Prefix
#         backend:
#           service:
#             name: longhorn-frontend
#             port:
#               number: 80
#   tls:
#   - hosts:
#     - longhorn-lap-k8s.b13homelab.in
# EOF"