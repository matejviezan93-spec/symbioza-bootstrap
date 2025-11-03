#!/usr/bin/env bash
set -euo pipefail
echo "🧬 Symbióza Bootstrap starting..."

# --- remove any conflicting docker packages first ---
echo "🧹 Cleaning old Docker packages..."
apt-get remove -y docker.io docker-doc docker-compose docker-compose-plugin \
  docker-buildx docker-buildx-plugin containerd runc || true
apt-get autoremove -y
apt-get clean
dpkg --configure -a || true
rm -rf /var/lib/dpkg/lock* /var/cache/apt/archives/lock

# --- add official Docker CE repository ---
echo "⚙️ Setting up official Docker repository..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y

# --- install official Docker CE + Compose plugin ---
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- install other dependencies ---
apt-get install -y git sudo ufw

# --- create codex user ---
id -u codex &>/dev/null || useradd -m -s /bin/bash codex
usermod -aG docker codex

# --- dns fallback ---
grep -q 8.8.8.8 /etc/resolv.conf || echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# --- clone main repo ---
cd /root
if [ ! -d "Baileys-Bridge" ]; then
  git clone --recurse-submodules git@github.com:matejviezan93-spec/Baileys-Bridge.git
fi
cd Baileys-Bridge
git submodule update --init --recursive --remote

# --- copy env & boost scripts ---
cp ../symbioza-bootstrap/.env.template .env
cp ../symbioza-bootstrap/codex-boost.sh ./codex-boost.sh
chmod +x ./codex-boost.sh

# --- add autostart ---
grep -q codex-boost /etc/crontab || echo "@reboot root cd /root/Baileys-Bridge && ./codex-boost.sh" >> /etc/crontab

# --- build & start stack ---
docker compose down -v || true
docker compose up -d --build

echo "✅ Bootstrap complete. Stack running."
