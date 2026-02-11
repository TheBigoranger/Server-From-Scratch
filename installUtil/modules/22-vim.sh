#!/bin/bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib"
source "$LIB_DIR/apt_install.sh"
source "$LIB_DIR/vim_plugin.sh"

VIMRC="$HOME/.vimrc"
VIM_AUTOLOAD_DIR="$HOME/.vim/autoload"
VIM_PLUG_PATH="$VIM_AUTOLOAD_DIR/plug.vim"
PLUG_BLOCK_START="\" >>> installUtil vim plugins >>>"
PLUG_BLOCK_END="\" <<< installUtil vim plugins <<<"
VIM_PLUGINS=(
  "luochen1990/rainbow"
  "mcmartelle/vim-monokai-bold"
  "vim-airline/vim-airline"
)

install_pkg_if_needed "vim"
install_pkg_if_needed "curl"

mkdir -p "$VIM_AUTOLOAD_DIR"

if [[ ! -f "$VIM_PLUG_PATH" ]]; then
  curl -fLo "$VIM_PLUG_PATH" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

touch "$VIMRC"

if ! grep -q '^set number$' "$VIMRC"; then
  echo "set number" >> "$VIMRC"
fi

block_file="$(mktemp)"
{
  echo "$PLUG_BLOCK_START"
  echo "call plug#begin('~/.vim/plugged')"
  for repo in "${VIM_PLUGINS[@]}"; do
    echo "Plug '$repo'"
  done
  echo "call plug#end()"
  echo ""
  echo "let g:rainbow_active = 1"
  echo "colorscheme monokai-bold"
  echo "$PLUG_BLOCK_END"
} > "$block_file"

if grep -q "$PLUG_BLOCK_START" "$VIMRC"; then
  awk -v start="$PLUG_BLOCK_START" -v end="$PLUG_BLOCK_END" -v block="$block_file" '
    $0 == start {
      while ((getline line < block) > 0) print line
      inblock = 1
      next
    }
    inblock && $0 == end { inblock = 0; next }
    !inblock { print }
  ' "$VIMRC" > "${VIMRC}.tmp"
  mv "${VIMRC}.tmp" "$VIMRC"
else
  echo "" >> "$VIMRC"
  cat "$block_file" >> "$VIMRC"
fi

rm -f "$block_file"

for repo in "${VIM_PLUGINS[@]}"; do
  ensure_vim_plugin "$repo"
done
