#!/bin/bash
set -euo pipefail

# Quiet apt update (只执行一次)
apt_quiet_update() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[apt-lib] apt-get not found, skipping."
    return 1
  fi

  # 用一个锁文件避免多次 update
  local flag="/tmp/.apt_updated_once"
  if [[ ! -f "$flag" ]]; then
    sudo apt-get update -qq
    touch "$flag"
  fi
}

pkg_available() {
  local pkg="$1"
  apt-cache show "$pkg" >/dev/null 2>&1
}

installed_ver() {
  local pkg="$1"
  dpkg-query -W -f='${Status} ${Version}\n' "$pkg" 2>/dev/null \
    | awk '($1=="install" && $2=="ok" && $3=="installed"){print $4; exit}'
}

candidate_ver() {
  local pkg="$1"
  apt-cache policy "$pkg" 2>/dev/null | awk -F': ' '/Candidate:/{print $2; exit}'
}

needs_install() {
  local pkg="$1"
  local inst cand

  inst="$(installed_ver "$pkg" || true)"
  cand="$(candidate_ver "$pkg" || true)"

  [[ -z "$inst" ]] && return 0
  [[ -z "$cand" || "$cand" == "(none)" ]] && return 1

  dpkg --compare-versions "$cand" gt "$inst"
}

install_pkg_if_needed() {
  local pkg="$1"

  apt_quiet_update || return 0

  if ! pkg_available "$pkg"; then
    echo "[apt-lib] skip (not available): $pkg"
    return 0
  fi

  if needs_install "$pkg"; then
    local inst cand
    inst="$(installed_ver "$pkg" || true)"
    cand="$(candidate_ver "$pkg" || true)"

    if [[ -z "$inst" ]]; then
      echo "[apt-lib] installing: $pkg (candidate: $cand)"
    else
      echo "[apt-lib] upgrading:  $pkg ($inst -> $cand)"
    fi

    sudo apt-get install -y -qq "$pkg"
  else
    echo "[apt-lib] skip (up-to-date): $pkg ($(installed_ver "$pkg"))"
  fi
}

