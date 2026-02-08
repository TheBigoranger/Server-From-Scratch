#!/usr/bin/env bash
set -euo pipefail

echo "[shadowsocks] Updating package index..."
sudo apt update -qq >/dev/null

echo "[shadowsocks] Installing shadowsocks-libev..."
sudo apt install -y shadowsocks-libev >/dev/null

CONF="/etc/shadowsocks-libev/config.json"
SERVICE="/etc/systemd/system/ss-server.service"
SS_PORT="8388"

# =========================
# Ask password (default if empty)
# =========================
DEFAULT_PASS="MY_STRONG_PASSWORD"
read -r -s -p "[shadowsocks] Enter Shadowsocks password (press Enter for default): " SS_PASS
echo
SS_PASS="${SS_PASS:-$DEFAULT_PASS}"

# =========================
# Force overwrite config file
# =========================
echo "[shadowsocks] Overwriting config: $CONF"
sudo mkdir -p /etc/shadowsocks-libev
sudo tee "$CONF" >/dev/null <<JSON
{
  "server": "0.0.0.0",
  "server_port": ${SS_PORT},
  "password": "$(printf '%s' "$SS_PASS")",
  "timeout": 300,
  "method": "aes-256-gcm",
  "mode": "tcp_and_udp"
}
JSON
sudo chmod 600 "$CONF"

# =========================
# Force overwrite systemd service
# =========================
echo "[shadowsocks] Overwriting systemd unit: $SERVICE"
sudo tee "$SERVICE" >/dev/null <<'EOF'
[Unit]
Description=Shadowsocks ss-server (custom)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# =========================
# Optional: open firewall if UFW is active
# =========================
if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "[shadowsocks] UFW active -> allowing ${SS_PORT}/tcp and ${SS_PORT}/udp"
  sudo ufw allow "${SS_PORT}/tcp" >/dev/null
  sudo ufw allow "${SS_PORT}/udp" >/dev/null
  sudo ufw reload >/dev/null || true
else
  echo "[shadowsocks] UFW inactive -> skip firewall rules"
fi

# =========================
# Disable possible conflicting units
# =========================
echo "[shadowsocks] Disabling possible conflicting units..."
sudo systemctl disable --now shadowsocks-libev 2>/dev/null || true
sudo systemctl disable --now "shadowsocks-libev@config" 2>/dev/null || true
sudo systemctl disable --now ss-local 2>/dev/null || true
sudo systemctl disable --now ss-redir 2>/dev/null || true
sudo systemctl disable --now ss-tunnel 2>/dev/null || true

# =========================
# Reload + enable + restart
# =========================
echo "[shadowsocks] Reloading systemd and restarting ss-server..."
sudo systemctl daemon-reload
sudo systemctl enable ss-server >/dev/null
sudo systemctl restart ss-server

sleep 1
if systemctl is-active --quiet ss-server; then
  echo "[shadowsocks] ✅ ss-server is running with latest config"
  echo "[shadowsocks] Config file: $CONF"
  echo "[shadowsocks] Listening on: 0.0.0.0:${SS_PORT} (tcp/udp)"
  echo "[shadowsocks] View logs:"
  echo "  sudo journalctl -u ss-server -f -o cat"
else
  echo "[shadowsocks] ❌ ss-server failed to start. Logs:"
  echo "  sudo journalctl -u ss-server -e --no-pager"
  exit 1
fi

