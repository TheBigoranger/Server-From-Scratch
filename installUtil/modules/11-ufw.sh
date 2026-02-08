#!/bin/bash
set -euo pipefail

echo "[ufw] starting..."

# ===== locate project root lib directory =====
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib"

if [[ ! -f "$LIB_DIR/apt_install.sh" ]]; then
  echo "[ufw] ERROR: apt_install.sh not found in $LIB_DIR"
  exit 1
fi

# shellcheck source=/dev/null
source "$LIB_DIR/apt_install.sh"

# ===== install ufw only if missing or outdated =====
install_pkg_if_needed "ufw"

echo "[ufw] setting default policies..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# ===== enable ufw if not active =====
if sudo ufw status | grep -q "Status: active"; then
  echo "[ufw] ufw already enabled"
else
  echo "[ufw] enabling ufw..."
  sudo ufw --force enable
fi

# ===== ensure SSH rule exists (avoid duplicate spam) =====
if sudo ufw status | grep -q "22/tcp"; then
  echo "[ufw] ssh rule already exists"
else
  echo "[ufw] allowing ssh (22/tcp)..."
  sudo ufw allow 22/tcp
fi

echo "[ufw] current status:"
sudo ufw status verbose

echo "[ufw] done."

