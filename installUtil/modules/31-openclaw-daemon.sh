#!/usr/bin/env bash
set -euo pipefail

echo "[31] Configure OpenClaw Gateway (user-level, stable version) + Browser (headless)"

USER_NAME="$(whoami)"
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="openclaw-gateway.service"
SERVICE_PATH="$SYSTEMD_USER_DIR/$SERVICE_NAME"

GATEWAY_PORT=18789

# Browser defaults
BROWSER_DEFAULT_PROFILE="openclaw"
BROWSER_CDP_PORT=18800

# ------------------------------------------------------------
# 0. enable linger (so user services start at boot)
# ------------------------------------------------------------
echo "[31] Ensuring linger is enabled for user: $USER_NAME"
if ! loginctl show-user "$USER_NAME" | grep -q "Linger=yes"; then
  sudo loginctl enable-linger "$USER_NAME"
  echo "[31] Linger enabled."
else
  echo "[31] Linger already enabled."
fi

# ------------------------------------------------------------
# 1. sanity checks
# ------------------------------------------------------------
if [[ ! -f "$OPENCLAW_JSON" ]]; then
  echo "[31][ERROR] $OPENCLAW_JSON not found. Run openclaw onboard first."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[31] Installing jq..."
  sudo apt update
  sudo apt install -y jq
fi

OPENCLAW_BIN="$(command -v openclaw)"
echo "[31] Using openclaw binary: $OPENCLAW_BIN"

# ------------------------------------------------------------
# 2. read gateway token from openclaw.json (source of truth)
# ------------------------------------------------------------
GATEWAY_TOKEN="$(jq -r '.gateway.auth.token // empty' "$OPENCLAW_JSON")"

if [[ -z "$GATEWAY_TOKEN" || "$GATEWAY_TOKEN" == "null" ]]; then
  echo "[31][ERROR] gateway.auth.token not found in $OPENCLAW_JSON"
  exit 1
fi

echo "[31] Gateway token loaded from openclaw.json"

# ------------------------------------------------------------
# 3. Ensure Chromium exists + resolve executablePath (DO NOT hardcode)
# ------------------------------------------------------------
echo "[31] Ensuring chromium is installed..."
if ! command -v chromium >/dev/null 2>&1; then
  sudo apt update
  # Some distros use chromium-browser, some use chromium
  if sudo apt install -y chromium-browser; then
    :
  else
    sudo apt install -y chromium
  fi
fi

CHROMIUM_PATH="$(command -v chromium || true)"
if [[ -z "$CHROMIUM_PATH" ]]; then
  echo "[31][ERROR] chromium still not found after install."
  exit 1
fi
echo "[31] chromium resolved via 'which chromium': $CHROMIUM_PATH"

# ------------------------------------------------------------
# 4. Patch ~/.openclaw/openclaw.json with global browser config (for ALL agents)
#     NOTE: This is top-level key 'browser' (NOT tools.*)
# ------------------------------------------------------------
echo "[31] Writing global browser config into $OPENCLAW_JSON (top-level .browser)..."

# backup once
if [[ ! -f "$OPENCLAW_JSON.bak.before_browser" ]]; then
  cp "$OPENCLAW_JSON" "$OPENCLAW_JSON.bak.before_browser"
  echo "[31] Backup created: $OPENCLAW_JSON.bak.before_browser"
fi

tmp_json="$(mktemp)"
jq \
  --arg chromium "$CHROMIUM_PATH" \
  --arg defaultProfile "$BROWSER_DEFAULT_PROFILE" \
  --argjson cdpPort "$BROWSER_CDP_PORT" \
  '
  .browser = (
    (.browser // {}) * {
      enabled: true,
      remoteCdpTimeoutMs: 1500,
      remoteCdpHandshakeTimeoutMs: 3000,
      defaultProfile: $defaultProfile,
      color: "#FF4500",
      headless: true,
      noSandbox: false,
      attachOnly: false,
      executablePath: $chromium,
      profiles: (
        (.browser.profiles // {}) * {
          openclaw: { cdpPort: $cdpPort, color: "#FF4500" }
        }
      )
    }
  )
  ' "$OPENCLAW_JSON" > "$tmp_json"

mv "$tmp_json" "$OPENCLAW_JSON"
echo "[31] Browser config updated."

# ------------------------------------------------------------
# 5. write user-level systemd service (gateway)
# ------------------------------------------------------------
mkdir -p "$SYSTEMD_USER_DIR"

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=OpenClaw Gateway (user-level)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment=HOME=%h
Environment=XDG_CONFIG_HOME=%h/.config
Environment=XDG_CACHE_HOME=%h/.cache
Environment=OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}

WorkingDirectory=%h

# IMPORTANT:
# --bind must be enum: loopback | lan | tailnet | auto | custom
ExecStart=${OPENCLAW_BIN} gateway \\
  --bind loopback \\
  --port ${GATEWAY_PORT} \\
  --auth token \\
  --verbose
ExecStartPost=/bin/bash -c 'for i in {1..60}; do if command -v ss >/dev/null 2>&1 && ss -lnt | grep -q ":${GATEWAY_PORT} "; then break; fi; sleep 0.5; done; "${OPENCLAW_BIN}" browser --browser-profile "${BROWSER_DEFAULT_PROFILE}" start'

Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

echo "[31] Wrote systemd service: $SERVICE_PATH"

# ------------------------------------------------------------
# 6. reload + enable + restart gateway
# ------------------------------------------------------------
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME"

echo "[31] Gateway restarted."

# ------------------------------------------------------------
# 7. Start browser profile (headless) and verify CDP
# ------------------------------------------------------------
echo "[31] Starting OpenClaw browser profile: $BROWSER_DEFAULT_PROFILE"

# best-effort: stop 'chrome' relay profile if it exists, to avoid confusion
"$OPENCLAW_BIN" browser --browser-profile chrome stop >/dev/null 2>&1 || true

# start target profile
"$OPENCLAW_BIN" browser --browser-profile "$BROWSER_DEFAULT_PROFILE" start || true

# quick health check (CDP HTTP endpoint)
if command -v curl >/dev/null 2>&1; then
  if curl -sS --max-time 2 "http://127.0.0.1:${BROWSER_CDP_PORT}/json/version" >/dev/null 2>&1; then
    echo "[31] Browser CDP is healthy: http://127.0.0.1:${BROWSER_CDP_PORT}"
  else
    echo "[31][WARN] Browser CDP not reachable yet on 127.0.0.1:${BROWSER_CDP_PORT}."
    echo "          You can check with:"
    echo "            openclaw browser --browser-profile $BROWSER_DEFAULT_PROFILE status"
    echo "            curl -s http://127.0.0.1:${BROWSER_CDP_PORT}/json/version"
  fi
else
  echo "[31][WARN] curl not installed; skipping CDP health check."
fi

echo "[31] Done."
echo
echo "Check status with:"
echo "  systemctl --user status $SERVICE_NAME --no-pager"
echo "  ss -lntp | grep ${GATEWAY_PORT}"
echo
echo "Browser checks:"
echo "  openclaw browser --browser-profile $BROWSER_DEFAULT_PROFILE status"
echo "  openclaw browser --browser-profile $BROWSER_DEFAULT_PROFILE tabs"
echo "  curl -s http://127.0.0.1:${BROWSER_CDP_PORT}/json/version"

