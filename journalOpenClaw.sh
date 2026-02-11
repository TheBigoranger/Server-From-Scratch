#!/bin/bash
sudo journalctl -f -o cat _UID=1000 _SYSTEMD_USER_UNIT=openclaw-gateway.service
