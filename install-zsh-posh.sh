
```bash
# --------------------------------------------------
# Base packages
# --------------------------------------------------
apt install -y \
  unzip \
  git \
  wget \
  zsh

dnf install -y git wget zsh

# --------------------------------------------------
# Oh My Zsh
# --------------------------------------------------
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# --------------------------------------------------
# Oh My Posh
# --------------------------------------------------
git clone https://github.com/JanDeDobbeleer/oh-my-posh.git .posh-themes

curl -s https://ohmyposh.dev/install.sh | bash

# --------------------------------------------------
# Ensure ~/.local/bin is in PATH (system-wide)
# --------------------------------------------------
# Ubuntu
cp /etc/environment "/etc/environment.bak.$(date +%F_%H-%M-%S)"

sed -i \
  's|^PATH="\(.*\)"|PATH="\1:/root/.local/bin"|' \
  /etc/environment

source /etc/environment

# RHEL/ROCKY

echo 'export PATH="$PATH:/root/.local/bin"' > /etc/profile.d/root-local-bin.sh
source /etc/profile.d/root-local-bin.sh

# --------------------------------------------------
# Install fonts
# --------------------------------------------------
oh-my-posh font install meslo
oh-my-posh font install hack
oh-my-posh font install CascadiaCode
oh-my-posh font install CascadiaMono
oh-my-posh font install JetBrainsMono

# --------------------------------------------------
# Zsh configuration
# --------------------------------------------------
cp ~/.zshrc ~/.zshrc.bak.$(date +%F_%H-%M-%S)

# Disable default Oh My Zsh theme
sed -i 's/^ZSH_THEME="robbyrussell"/ZSH_THEME=""/' ~/.zshrc

# Add Oh My Posh initialization if missing
if ! grep -q 'oh-my-posh init zsh' ~/.zshrc; then
  cat <<'EOF' >> ~/.zshrc

# --------------------------------------------------
# Oh My Posh theme
# --------------------------------------------------
THEME="cloud-native-azure"
eval "$(oh-my-posh init zsh --config /root/.posh-themes/themes/$THEME.omp.json)"
EOF
fi

# --------------------------------------------------
# Reload shell config
# --------------------------------------------------

# Download the file to the oh-my-zsh custom directory with the new name
curl -L https://raw.githubusercontent.com/ahmetb/kubectl-aliases/refs/heads/master/.kubectl_aliases \
  -o ~/.oh-my-zsh/custom/kubectl_aliases.zsh

# Reload your zsh configuration
source ~/.zshrc
```