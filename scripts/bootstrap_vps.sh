#!/usr/bin/env bash
# =============================================================================
# Agentic Server Platform — One-Click Bootstrap & Hardening Script
# Targets: Ubuntu 24.04 / 26.04 LTS & Debian 12
# =============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./bootstrap_vps.sh)"
  exit 1
fi

echo "[+] 1. Updating System Packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
apt-get install -y ufw fail2ban curl git htop iotop rsync jq build-essential ca-certificates gnupg ripgrep ffmpeg

echo "[+] 2. Configuring User & Passwordless Sudo..."
TARGET_USER="gavadala"
if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$TARGET_USER"
fi
usermod -aG sudo "$TARGET_USER"
echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$TARGET_USER"
chmod 0440 /etc/sudoers.d/"$TARGET_USER"

# Copy SSH keys from root if not present
mkdir -p "/home/$TARGET_USER/.ssh"
if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys "/home/$TARGET_USER/.ssh/authorized_keys"
    chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.ssh"
    chmod 700 "/home/$TARGET_USER/.ssh"
    chmod 600 "/home/$TARGET_USER/.ssh/authorized_keys"
fi

echo "[+] 3. Hardening SSH Configuration..."
cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers gavadala
X11Forwarding no
MaxAuthTries 3
EOF
sshd -t && (systemctl restart ssh || systemctl restart sshd)

echo "[+] 4. Configuring UFW Firewall & Fail2ban..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH Access"
ufw allow 81/tcp comment "CasaOS WebUI"
ufw --force enable
systemctl enable fail2ban && systemctl restart fail2ban

echo "[+] 5. Installing Node.js 22 LTS..."
if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi

echo "[+] 6. Installing CasaOS & Docker Engine..."
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.casaos.io | bash
fi
usermod -aG docker "$TARGET_USER"

echo "[+] 7. Installing Cloudflared..."
if ! command -v cloudflared >/dev/null 2>&1; then
    curl -fsSL -o /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
    rm -f /tmp/cloudflared.deb
fi

echo "[+] 8. Setting up Directory Structure..."
mkdir -p /opt/agentic-platform/{stack,scripts,omniroute}
chown -R "$TARGET_USER:$TARGET_USER" /opt/agentic-platform

echo "[✓] VPS Bootstrap and Hardening Completed Successfully!"
echo "    Connect with: ssh $TARGET_USER@<YOUR_SERVER_IP>"
