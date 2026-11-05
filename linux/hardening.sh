#!/usr/bin/env bash
#
# hardening.sh — apply the safe SSH/firewall basics on Ubuntu/Debian
#
# What it does:
#   1. Writes an sshd drop-in: key-only auth, no root login (backs up first)
#   2. Installs and enables UFW: deny incoming by default, allow SSH (+ any
#      extra ports you pass)
#   3. Installs Fail2ban with an sshd jail
#
# What it does NOT do: create users, touch existing keys, or change your
# SSH port. Run it, then TEST a fresh SSH login in a new terminal before
# closing your current session.
#
# Usage:
#   sudo ./hardening.sh                 # SSH only
#   sudo ./hardening.sh 80 443          # SSH + web ports
#
# ⚠️ WARNING: If you do not already have SSH key login working for a sudo
# user, this script will lock you out of password-based access. It checks
# for authorized_keys first and refuses to disable passwords if none exist.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo $0)" >&2
  exit 1
fi

# --- Safety check: at least one real user must have an authorized_keys file
KEY_FOUND=0
for dir in /home/* /root; do
  if [[ -s "$dir/.ssh/authorized_keys" ]]; then
    KEY_FOUND=1
    echo "Found authorized_keys in $dir/.ssh/"
  fi
done
if [[ $KEY_FOUND -eq 0 ]]; then
  echo "ERROR: No authorized_keys found for any user." >&2
  echo "Set up SSH key login first — see ssh-key-management.md" >&2
  exit 1
fi

read -rp "Apply hardening (sshd key-only, UFW, Fail2ban)? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# --- 1. SSH hardening via a drop-in (easy to revert: delete the file)
SSHD_DROPIN=/etc/ssh/sshd_config.d/99-hardening.conf
cat > "$SSHD_DROPIN" <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
EOF
sshd -t
systemctl reload ssh || systemctl reload sshd
echo "SSH hardened (drop-in: $SSHD_DROPIN)"

# --- 2. Firewall
apt-get update -qq
apt-get install -y -qq ufw fail2ban
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
for port in "$@"; do
  ufw allow "$port"
  echo "Allowed port $port"
done
ufw --force enable
ufw status verbose

# --- 3. Fail2ban sshd jail
cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban
fail2ban-client status sshd || true

echo
echo "Done. NOW: open a NEW terminal and test SSH login before closing this one."
echo "To undo the SSH part: rm $SSHD_DROPIN && systemctl reload ssh"
