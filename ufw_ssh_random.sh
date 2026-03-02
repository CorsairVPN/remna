#!/usr/bin/env bash
set -euo pipefail

# Change SSH to a random high port and lock down the firewall (Debian/Ubuntu).

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root (e.g., sudo $0)" >&2
  exit 1
fi

ssh_config="/etc/ssh/sshd_config"
backup="${ssh_config}.bak.$(date +%Y%m%d%H%M%S)"
range_low="${PORT_LOW:-1025}"
range_high="${PORT_HIGH:-49151}"

pick_port() {
  local cand
  for _ in $(seq 1 25); do
    cand=$(shuf -i "${range_low}-${range_high}" -n 1)
    if ss -Hln | awk '{print $4}' | grep -qE "[:.]${cand}\$"; then
      continue
    fi
    echo "$cand"
    return 0
  done
  return 1
}

new_port="$(pick_port)" || {
  echo "Could not find a free port in ${range_low}-${range_high}" >&2
  exit 1
}

echo "Using SSH port: $new_port"
cp "$ssh_config" "$backup"

sed -i '/^[[:space:]]*Port[[:space:]]\+[0-9]\+/ s/^/# /' "$ssh_config"
if ! grep -Eq "^[[:space:]]*Port[[:space:]]+$new_port" "$ssh_config"; then
  printf "\nPort %s\n" "$new_port" >> "$ssh_config"
fi

if ! sshd -t; then
  mv "$backup" "$ssh_config"
  echo "sshd config test failed; restored $ssh_config" >&2
  exit 1
fi

systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || service ssh reload

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ufw

ufw allow "$new_port"
ufw allow 80
ufw allow 443
ufw --force enable

if ufw status | grep -q '22/tcp'; then
  printf 'y\n' | ufw delete allow 22/tcp >/dev/null 2>&1 || true
fi

ufw reload

echo "SSH now listens on port $new_port."
echo "Reconnect with: ssh -p $new_port <user>@<host>"
