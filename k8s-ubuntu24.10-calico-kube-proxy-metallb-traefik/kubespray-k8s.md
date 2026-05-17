---
# What is installed?

- Calico: BGP
- Metallb: L2
- helm
- nginx ingress 

## ssh keys are copied from nexus to all the k8s nodes

```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray


apt update
apt install -y \
  python3 \
  python3-venv \
  python3-pip \
  sshpass \
  git

python3 -m venv k8s-calicobgp #<give the name you want>

source k8s-calicobgp/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

ansible --version
```
---


cp -rfp inventory/sample inventory/mycluster

```inventory.ini:

[all]
lap-k8s-master-01 ansible_host=192.168.0.150 ip=192.168.0.150 access_ip=192.168.0.150
lap-k8s-worker-01 ansible_host=192.168.0.151 ip=192.168.0.151 access_ip=192.168.0.151
lap-k8s-worker-02 ansible_host=192.168.0.152 ip=192.168.0.152 access_ip=192.168.0.152

[kube_control_plane]
lap-k8s-master-01

[kube_node]
lap-k8s-worker-01
lap-k8s-worker-02

[etcd]
lap-k8s-master-01

[k8s_cluster:children]
kube_control_plane
kube_node
```

vim inventory/mycluster/group_vars/k8s_cluster/k8s-net-calico.yml
```
calico_network_backend: "bird"
calico_ipip_mode: "Never"
calico_vxlan_mode: "Never"
calico_pool_cidr: 10.244.0.0/16 # ← MUST match ippool cidr
```

vim inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
```
kube_network_plugin: calico
kube_proxy_strict_arp: true
cluster_name: lap-k8s.local
kube_service_addresses: 10.96.0.0/12
kube_pods_subnet: 10.244.0.0/16
```

vim inventory/mycluster/group_vars/k8s_cluster/addons.yml
```
ingress_nginx_enabled: true
ingress_nginx_namespace: ingress-nginx
ingress_nginx_host_network: false
ingress_nginx_default: true
ingress_nginx_service_type: LoadBalancer
helm_enabled: true
...
# MetalLB deployment
metallb_enabled: true
metallb_speaker_enabled: "{{ metallb_enabled }}"
metallb_namespace: "metallb-system"

# Switch protocol to Layer2
metallb_protocol: "layer2"

# MetalLB configuration
metallb_config:
  speaker:
    nodeselector:
      kubernetes.io/os: "linux"
    tolerations:
      - key: "node-role.kubernetes.io/control-plane"
        operator: "Equal"
        value: ""
        effect: "NoSchedule"

  controller:
    nodeselector:
      kubernetes.io/os: "linux"
    tolerations:
      - key: "node-role.kubernetes.io/control-plane"
        operator: "Equal"
        value: ""
        effect: "NoSchedule"

  # Address pool MetalLB will announce
  address_pools:
    pool1:
      ip_range:
        - 192.168.0.160-192.168.0.199   # your chosen range
      auto_assign: true

  # Layer2 mode configuration
  layer2:
    - pool1
```

ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v

ansible-playbook -i inventory/mycluster/inventory.ini --become --become-user=root reset.yml

ansible -i inventory/mycluster/inventory.ini all --become --become-user=root -m reboot

ansible -i inventory/mycluster/inventory.ini all -m ping
----

# Label the worker nodes
kubectl label nodes lap-k8s-worker-01 kubernetes.io/role=worker &&
kubectl label nodes lap-k8s-worker-02 kubernetes.io/role=worker && kgno
