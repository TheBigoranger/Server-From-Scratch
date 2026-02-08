#!/usr/bin/env bash
set -e

echo "======================================"
echo "[32] Installing OpenClaw skills (via ClawHub)"
echo "======================================"

# ---------- sanity check ----------
if ! command -v node >/dev/null 2>&1; then
  echo "[ERROR] node is not installed"
  exit 1
fi

if ! command -v clawhub >/dev/null 2>&1; then
  echo "[INFO] clawhub not found, installing globally via npm..."
  sudo npm install -g clawhub
else
  echo "[INFO] clawhub found at: $(command -v clawhub)"
fi

echo "[INFO] Running as user: $(whoami)"
echo

# ---------- skills to install ----------
SKILLS=(
)

# ---------- install loop ----------
for SKILL in "${SKILLS[@]}"; do
  echo "[INFO] Installing skill: $SKILL"

  if clawhub list 2>/dev/null | grep -q "$SKILL"; then
    echo "[SKIP] $SKILL already installed"
  else
    clawhub install "$SKILL"
    echo "[OK]   $SKILL installed"
  fi

  echo
done

# ---------- summary ----------
echo "======================================"
echo "[32] OpenClaw skills installation done"
echo "======================================"
echo
echo "Next steps:"
echo "  - Restart OpenClaw gateway to activate skills:"
echo "      systemctl --user restart openclaw-gateway.service"
echo
echo "  - Verify with:"
echo "      clawhub list"
echo "      openclaw skill list"

