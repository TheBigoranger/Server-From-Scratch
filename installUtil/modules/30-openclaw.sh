#!/bin/bash
set -euo pipefail

echo "[openclaw] checking node & npm..."

if ! command -v node >/dev/null 2>&1; then
  echo "[openclaw] ERROR: node not found. Please run modules/20-node.sh first."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "[openclaw] ERROR: npm not found. Please run modules/20-node.sh first."
  exit 1
fi

NODE_MAJOR="$(node -p "parseInt(process.versions.node.split('.')[0], 10)")"
echo "[openclaw] node version: $(node -v)"

if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "[openclaw] ERROR: OpenClaw requires Node >= 22. Current: $(node -v)"
  exit 1
fi

echo "[openclaw] installing openclaw CLI globally (npm)..."
sudo npm install -g openclaw@latest

echo "[openclaw] installed:"
command -v openclaw
openclaw --version || true

echo ""
echo "============================================================"
echo "[openclaw] Optional next step: onboarding"
echo ""
echo "This will run:"
echo "  openclaw onboard --install-daemon"
echo ""
echo "It is INTERACTIVE and will:"
echo "  - create config files"
echo "  - install & enable the OpenClaw daemon"
echo "  - possibly open local ports"
echo ""
read -r -p "Do you want to run onboarding now? [y/N]: " ANSWER

case "$ANSWER" in
  y|Y)
    echo "[openclaw] starting onboarding..."
    openclaw onboard --install-daemon
    rc=$?

    # 130 = Ctrl+C
    if [[ "$rc" -eq 130 ]]; then
      echo "[openclaw] onboarding interrupted (Ctrl+C). Continue..."
    else
      # 如果你希望非 0 就中断模块，用 return/exit
      # 如果你希望继续执行，也可以改成: echo warn 然后继续
      if [[ "$rc" -ne 0 ]]; then
        echo "[openclaw] onboarding failed with rc=$rc"
        return "$rc"
      fi
    fi
    ;;
  *)
    echo "[openclaw] onboarding skipped."
    echo "[openclaw] You can run it later with:"
    echo "  openclaw onboard --install-daemon"
    ;;
esac

