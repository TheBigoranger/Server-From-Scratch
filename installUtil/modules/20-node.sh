#!/bin/bash
set -euo pipefail

echo "[node] starting Node.js setup..."

# ===== locate lib directory =====
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib"

if [[ ! -f "$LIB_DIR/apt_install.sh" ]]; then
  echo "[node] ERROR: apt_install.sh not found in $LIB_DIR"
  exit 1
fi

# shellcheck source=/dev/null
source "$LIB_DIR/apt_install.sh"

# ===== base dependencies (install only if needed) =====
install_pkg_if_needed ca-certificates
install_pkg_if_needed curl
install_pkg_if_needed gnupg

# ===== ensure NodeSource repo exists =====
NODE_LIST="/etc/apt/sources.list.d/nodesource.list"

if [[ ! -f "$NODE_LIST" ]]; then
  echo "[node] adding NodeSource LTS repository..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
else
  echo "[node] NodeSource repo already exists"
fi

# NodeSource 脚本可能新增 repo，需要刷新一次（但仍保持安静）
sudo apt-get update -qq

# ===== install nodejs only if missing/outdated =====
install_pkg_if_needed nodejs

echo "[node] node: $(node -v)"
echo "[node] npm:  $(npm -v)"
echo "[node] npx:  $(npx -v)"

# ===== install global npm tools only if missing =====
if ! command -v npm-check >/dev/null 2>&1; then
  echo "[node] installing global npm tool: npm-check"
  sudo npm install -g npm-check
else
  echo "[node] npm-check already installed"
fi

echo "[node] npm-check: $(npm-check -gv)"

echo "[node] optional global update check..."
sudo npm-check -gu || true

echo "[node] done."

