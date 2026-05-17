# System preparation on all nodes
```bash
clush -g k8svmlocal "apt update && apt upgrade -y && apt install -y apt-transport-https ca-certificates curl gpg"

clush -g k8svmlocal "swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab"

clush -g k8svmlocal "modprobe overlay && modprobe br_netfilter"

clush -g k8svmlocal "sudo bash -c 'cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF'"

clush -g k8svmlocal 'cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF
sysctl --system'
```
# Install and configure containerd v1.7
```bash
clush -g k8svmlocal "apt install -y containerd containernetworking-plugins && mkdir -p /etc/containerd && containerd config default > /etc/containerd/config.toml"
```
# Set CRI sandbox image to match kubeadm recommendation
```bash
clush -g k8svmlocal "sed -i 's|sandbox_image = .*|sandbox_image = \"registry.k8s.io/pause:3.10.1\"|' /etc/containerd/config.toml"
```
# Use systemd cgroups for kubelet compatibility
```bash
clush -g k8svmlocal "sed -ri 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"

clush -g k8svmlocal "systemctl restart containerd && systemctl enable containerd"
```
# Install kubeadm, kubelet, kubectl
```bash
clush -g k8svmlocal "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg"
clush -g k8svmlocal "echo 'deb https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' > /etc/apt/sources.list.d/kubernetes.list"

clush -g k8svmlocal "apt update && apt install -y kubelet kubeadm kubectl && apt-mark hold kubelet kubeadm kubectl"
```
# Initialize the master (kubeadm init)
```bash
kubeadm config images pull
kubeadm init \
  --apiserver-advertise-address=192.168.0.150 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=v1.35.0
```
## Configure kubectl on the master:
```bash
mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config
```
# Install Calico (bird/BGP) CNI
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml
```
# Get the join command from the master (copy the printed line)
```bash
kubeadm token create --print-join-command
```
# Install MetalLB (L2) and configure IP pool

# Install MetalLB
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
```

## Create missing secret
```
kubectl create secret generic -n metallb-system memberlist \
  --from-literal=secretkey="$(openssl rand -base64 128)"
```
### If needed, restart the speaker pods
They will restart automatically because it’s a DaemonSet, but to be sure:
```bash
kubectl -n metallb-system rollout restart ds speaker
```

# Create the IPAddressPool and L2Advertisement
```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.160-192.168.0.199
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
```


# Test: metallb

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lb-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lb-test
  template:
    metadata:
      labels:
        app: lb-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: lb-test
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: lb-test
  ports:
  - name: http
    port: 80
    targetPort: 80
EOF
```
```zsh
curl -I http://$(kubectl get svc lb-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```
```bash
krmsvc lb-test && krmdep lb-test
```