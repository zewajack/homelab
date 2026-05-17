---
:
════════════════════════════════════════════════════════════
🏠 b13 HomeLab Network Layout
════════════════════════════════════════════════════════════
BSNL Router: <redacted>
TPLink Router: <redacted>

🌐 Domain
────────────────────────────────────────────────────────────
b13homelab.in

📡 Network
────────────────────────────────────────────────────────────
CIDR        : 192.168.0.0/23
Netmask     : 255.255.254.0
Range       : 192.168.0.0 - 192.168.1.255
Usable  : 510 IPs

2 contiguous /24 blocks:
- 192.168.0.0/24
- 192.168.1.0/24

════════════════════════════════════════════════════════════
## 🗺️ IP ADDRESS ALLOCATION
════════════════════════════════════════════════════════════

192.168.0.0/23
────────────────────────────────────────────────────────────

192.168.0.0            🔒 Network Address
192.168.0.1            🌐 Gateway / Router
192.168.0.2            🛡️ Pi-hole (DNS)
192.168.0.3               Ubuntu 24.10 Template

192.168.0.4 - 192.168.0.49   ⚙️ FREE (Infra / HA / Firewall)

192.168.0.50           🧠 Proxmox Host
192.168.0.51 - 192.168.0.99  📦 Proxmox VMs / Containers (50 IPs)

192.168.0.100 - 192.168.0.102  ☸️ k3s - VMware (Dell Laptop)
192.168.0.103 - 192.168.0.109  ⚙️ FREE (VMs)
192.168.0.110 - 192.168.0.149  🌈 MetalLB/Kube-VIP (40 IPs)

192.168.0.150 - 192.168.0.152  ☸️ k8s - VMware (Dell Laptop)
192.168.0.153 - 192.168.0.159  ⚙️ FREE (VMs)
192.168.0.160 - 192.168.0.199  🔷 MetalLB/Kube-VIP (40 IPs)

192.168.0.200 - 192.168.0.202  🧱 k3s - Bare Metal (Mini PCs)
192.168.0.203 - 192.168.0.209  ⚙️ FREE (Server)
192.168.0.210 - 192.168.0.255  🔹 MetalLB/Kube-VIP (46 IPs)

192.168.1.0 - 192.168.1.49      ⚙️ FREE (50 IPs)
192.168.1.50 - 192.168.1.99     ⚙️ FREE (50 IPs)
192.168.1.100 - 192.168.1.254   ⚙️ FREE (155 IPs)   📡 DHCP Pool

192.168.1.255                  📢 Broadcast Address
════════════════════════════════════════════════════════════
```
---

## 🖥️ CORE SERVICES

```
pve-00.b13homelab.in         → 192.168.0.50

nexus.b13homelab.in       → 192.168.0.2
  ├─ 🛡️ Pi-hole   ✅ running
  └─ 🌐 Unbound   ✅ running
```

---

## ☸️ k3s - VMware (Dell Laptop)

```
lap-k3s-master-01.b13homelab.in   → 192.168.0.100
lap-k3s-worker-01.b13homelab.in   → 192.168.0.101
lap-k3s-worker-02.b13homelab.in   → 192.168.0.102

🌈 MetalLB Range 40IPs (VMware)
192.168.0.110 - 192.168.0.149
```
## k8s - VMware (Dell Laptop)

```
lap-k8s-master-01.b13homelab.in   → 192.168.0.150
lap-k8s-worker-01.b13homelab.in   → 192.168.0.151
lap-k8s-worker-02.b13homelab.in   → 192.168.0.152

🔷 MetalLB Range 40IPs (VMware)
192.168.0.160 - 192.168.0.199
```
---

## 🧱 k8s - Bare Metal (Mini PCs)

```
mini-k8s-master-01.b13homelab.in  → 192.168.0.200
mini-k8s-worker-01.b13homelab.in  → 192.168.0.201
mini-k8s-worker-02.b13homelab.in  → 192.168.0.202

🔹 MetalLB Range 46 IPs (Bare Metal)
192.168.0.210 - 192.168.0.255
```

---

## 🔐 SSH ROOT ACCESS (⚠️ LAB ONLY)

```bash
sudo su -
echo "root:<redacted>" | sudo chpasswd && \
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
systemctl restart ssh
```

---

## ⏱️ NTP - India Timezone 🇮🇳

```bash
apt update && apt install -y chrony && \
cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak && \
echo -e "pool in.pool.ntp.org iburst\ndriftfile /var/lib/chrony/chrony.drift\nlogdir /var/log/chrony" \
| tee /etc/chrony/chrony.conf && \
systemctl restart chrony && \
systemctl enable chrony && \
timedatectl set-timezone Asia/Kolkata
```


## ⚙️ STATIC IP CONFIGURATION (ETHERNET)

```
🔎 Detect Interface
IFACE=$(ip -o link show | awk -F': ' '$2 ~ /^en/ {print $2; exit}')
```

```bash
bash -c "cat > /etc/netplan/50-cloud-init.yaml" <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: false
      addresses:
        - 192.168.0.202/23
      nameservers:
        addresses:
          - 192.168.0.2
          - 8.8.8.8
          - 1.1.1.1
      routes:
        - to: 0.0.0.0/0
          via: 192.168.0.1
EOF
```

```
🚀 Apply
netplan apply
```

---

## 📶 STATIC IP (Wi-Fi)

```
IFACE=$(ip -o link show | awk -F': ' '$2 ~ /^wl/ {print $2; exit}')
```

```bash
sudo bash -c "cat > /etc/netplan/50-cloud-init.yaml" <<EOF
network:
  version: 2
  wifis:
    $IFACE:
      dhcp4: false
      addresses:
        - <NODE_STATIC_IP>/23
      nameservers:
        addresses:
          - 192.168.0.2
          - 8.8.8.8
          - 1.1.1.1
      routes:
        - to: 0.0.0.0/0
          via: 192.168.0.1
      access-points:
        "TpLink":
          password: "<redacted>"
EOF
```

```
🚀 Apply
sudo netplan apply
```

---

## 🔄 SYSTEM UPDATE

```bash
apt-get update -y && apt-get upgrade -y
```

---

## 📶 Wi-Fi via NetworkManager

```bash
apt update -y
apt install -y network-manager
systemctl enable --now NetworkManager
```

```bash
nmcli device wifi list
nmcli device wifi connect "TpLink" password "<redacted>"
```

```bash
lvextend /dev/ubuntu-vg/ubuntu-lv -l +100%FREE
resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```
---

## Force time and date update

```bash
timedatectl set-ntp true
  chronyc waitsync 30
    OR
  chronyc burst 4/4 
  chronyc makestep
```