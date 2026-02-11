#!/bin/bash
set -euo pipefail

vim_plugin_dir_name() {
  local repo="$1"
  echo "${repo##*/}"
}

vim_plugin_installed() {
  local repo="$1"
  local dir_name
  dir_name="$(vim_plugin_dir_name "$repo")"
  [[ -d "$HOME/.vim/plugged/$dir_name" ]]
}

ensure_vim_plugin() {
  local repo="$1"

  if ! command -v vim >/dev/null 2>&1; then
    echo "[vim-plugin] vim not found, skipping."
    return 0
  fi

  if [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
    echo "[vim-plugin] vim-plug not found, skipping."
    return 0
  fi

  if vim_plugin_installed "$repo"; then
    echo "[vim-plugin] already installed: $repo"
    return 0
  fi

  echo "[vim-plugin] installing: $repo"
  vim +PlugInstall +qall </dev/null

  if vim_plugin_installed "$repo"; then
    echo "[vim-plugin] ok: $repo"
  else
    echo "[vim-plugin] missing after install: $repo"
  fi
}

ensure_vim_plugins() {
  local repos=("$@")
  local repo

  for repo in "${repos[@]}"; do
    ensure_vim_plugin "$repo"
  done
}