#!/bin/bash
# Setup script — creates a Python venv inside the ansible directory and installs Ansible
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== Fixing directory permissions ==="
chmod 755 "$SCRIPT_DIR"

echo "=== Detecting OS ==="
if command -v apt &>/dev/null; then
    PKG_MGR="apt"
    echo "Detected: Debian/Ubuntu (apt)"
    apt update && apt install -y python3 python3-pip python3-venv sshpass
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
    echo "Detected: RHEL/Fedora (dnf)"
    dnf install -y python3 python3-pip sshpass
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
    echo "Detected: CentOS/RHEL (yum)"
    yum install -y python3 python3-pip sshpass
else
    echo "ERROR: No supported package manager found (apt/dnf/yum)"
    exit 1
fi

echo "=== Creating Python venv at $VENV_DIR ==="
python3 -m venv "$VENV_DIR"

echo "=== Installing Ansible ==="
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install ansible
ansible --version
deactivate

echo ""
echo "=== Setup complete ==="
echo "To use:"
echo "  cd $SCRIPT_DIR"
echo "  source .venv/bin/activate"
echo "  python3 generate-inventory.py"
echo "  ansible-playbook playbooks/site.yml"
echo "  deactivate"
