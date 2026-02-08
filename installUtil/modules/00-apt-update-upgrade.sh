#!/bin/bash
set -euo pipefail

echo "[apt] waiting for dpkg/apt lock (unattended-upgrades may be running)..."
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  sleep 5
done

sudo apt update
sudo apt -y upgrade
sudo apt -y dist-upgrade

sudo apt -y autoremove
sudo apt -y autoclean
