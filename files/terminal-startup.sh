#!/bin/bash
# Install ttyd + kubectl at startup
if [ ! -f /usr/local/bin/ttyd ]; then
  apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
  curl -sLo /usr/local/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64
  chmod +x /usr/local/bin/ttyd
  curl -sLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl
fi
echo "Starting ttyd on :7681..."
exec ttyd -p 7681 -c "admin:${TUI_PASSWORD}" -W /scripts/connect.sh
