#!/usr/bin/env bash
set -euo pipefail
echo "🧬 Symbióza Bootstrap starting..."

# --- remove old docker variants ---
echo "🧹 Cleaning old Docker packages..."
apt-get remove -y docker.io docker-doc docker-compose docker-compose-plugin \
  docker-buildx docker-buildx-plugin containerd runc || true
apt-get autoremove -y
apt-get clean
dpkg --configure -a || true
rm -rf /var/lib/dpkg/lock* /var/cache/apt/archives/lock

# --- install official docker repo ---
echo "⚙️ Installing official Docker CE..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- base deps ---
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

# --- autostart ---
grep -q codex-boost /etc/crontab || echo "@reboot root cd /root/Baileys-Bridge && ./codex-boost.sh" >> /etc/crontab

# --- kill existing containers & free ports ---
echo "🔌 Checking for old containers..."
docker ps -q | xargs -r docker stop || true
docker ps -a -q | xargs -r docker rm -f || true

# --- free any occupied ports (8000,8080,5432,9090,3000) ---
for p in 8000 8080 5432 9090 3000; do
  pid=$(lsof -ti :$p || true)
  if [ -n "$pid" ]; then
    echo "⚠️ Port $p in use by PID $pid — killing..."
    kill -9 $pid || true
  fi
done

# --- start docker stack ---
echo "🚀 Starting Symbióza stack..."
docker compose down -v || true
# --- deep port kill (tcp6/tcp4 fallback) ---
for p in 8000 8080 5432 9090 3000; do
  pid=$(lsof -t -i:$p 2>/dev/null || ss -lptn "sport = :$p" 2>/dev/null | awk '{print $7}' | grep -o '[0-9]*' | head -n1)
  if [ -n "$pid" ]; then
    echo "⚠️ Killing process $pid on port $p"
    kill -9 "$pid" 2>/dev/null || true
  fi
  fuser -k ${p}/tcp 2>/dev/null || true
  fuser -k ${p}/tcp6 2>/dev/null || true
done
docker compose up -d --build

echo "✅ Bootstrap complete. Stack running."
