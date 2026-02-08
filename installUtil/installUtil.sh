#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$BASE_DIR/modules"

log() { echo -e "\n[installUtil] $*\n"; }

run_module() {
  local name="$1"
  local path="$MODULE_DIR/$name"
  if [[ ! -x "$path" ]]; then
    echo "[ERROR] Module not found or not executable: $path"
    exit 1
  fi
  log "Running module: $name"
  "$path"
}

# =========================
# Run modules in order
# =========================
run_module "00-apt-update-upgrade.sh"
run_module "10-base-tools.sh"
run_module "11-ufw.sh"
run_module "20-node.sh"
run_module "21-shadowsocks.sh"
run_module "30-openclaw.sh"
run_module "31-openclaw-daemon.sh"
run_module "32-openclaw-skills.sh"