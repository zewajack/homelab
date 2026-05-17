# Installing Ansible via `pip` inside a Python virtual environment.

```bash
apt update && apt upgrade -y
apt install python3 python3-pip python3-venv -y

python3 -m venv ~/ansible-env
source ~/ansible-env/bin/activate

pip install --upgrade pip
pip install ansible
ansible --version
deactivate
```
