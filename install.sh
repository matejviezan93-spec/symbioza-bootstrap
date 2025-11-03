#!/usr/bin/env bash
set -euo pipefail

echo "🧬 Symbióza Bootstrap starting..."

apt-get update -y
apt-get install -y git curl docker.io docker-compose sudo ufw

id -u codex &>/dev/null || useradd -m -s /bin/bash codex
usermod -aG docker codex

grep -q 8.8.8.8 /etc/resolv.conf || echo "nameserver 8.8.8.8" >> /etc/resolv.conf

cd /root
if [ ! -d "Baileys-Bridge" ]; then
  git clone --recurse-submodules git@github.com:matejviezan93-spec/Baileys-Bridge.git
fi
cd Baileys-Bridge
git submodule update --init --recursive --remote

cp ../symbioza-bootstrap/.env.template .env
cp ../symbioza-bootstrap/codex-boost.sh ./codex-boost.sh
chmod +x ./codex-boost.sh

grep -q codex-boost /etc/crontab || echo "@reboot root cd /root/Baileys-Bridge && ./codex-boost.sh" >> /etc/crontab

docker compose down -v || true
docker compose up -d --build

echo "✅ Bootstrap complete. Stack running."
