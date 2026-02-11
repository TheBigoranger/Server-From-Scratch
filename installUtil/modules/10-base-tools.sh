#!/bin/bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib"
source "$LIB_DIR/apt_install.sh"

BASE_PKGS=(
  ca-certificates
  curl
  wget
  git
  htop
  tmux
  unzip
  xz-utils
  software-properties-common
  python3
  python3-pip
  python3-venv
  vim
)

for pkg in "${BASE_PKGS[@]}"; do
  install_pkg_if_needed "$pkg"
done

# Seed git config if missing (safe defaults).
if command -v git >/dev/null 2>&1; then
  if [[ -z "$(git config --global --get user.name || true)" ]]; then
    git config --global user.name "Ethan Xu"
  fi
  if [[ -z "$(git config --global --get user.email || true)" ]]; then
    git config --global user.email "ethanxuyicheng@gmail.com"
  fi
fi

