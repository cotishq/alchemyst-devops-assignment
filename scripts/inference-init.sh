#!/bin/bash
set -euxo pipefail

PROJECT_DIR="/opt/alchemyst"
REPO_URL="https://github.com/cotishq/alchemyst-devops-assignment.git"

# Add 2GB swap for model loading
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# curl-minimal already present, don't install curl
dnf update -y
dnf install -y git python3 python3-pip

export HOME=/root

# iii CLI
curl -fsSL https://iii.dev/install.sh | bash
export PATH="/root/.iii/bin:$PATH"
echo 'export PATH="/root/.iii/bin:$PATH"' >> /etc/environment

# Clone repo
mkdir -p $PROJECT_DIR
git clone $REPO_URL $PROJECT_DIR

# Install Python deps
cd $PROJECT_DIR/quickstart/workers/inference-worker
pip3 install -r requirements.txt

# Placeholder env file
cat > /etc/iii-inference.env << 'ENVEOF'
III_URL=ws://GATEWAY_PRIVATE_IP_PLACEHOLDER:49134
ENVEOF

# systemd service
cat > /etc/systemd/system/iii-inference.service << 'SVCEOF'
[Unit]
Description=iii Inference Worker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/alchemyst/quickstart/workers/inference-worker
EnvironmentFile=/etc/iii-inference.env
Environment="PATH=/root/.iii/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HOME=/root"
ExecStart=/usr/bin/python3 inference_worker.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable iii-inference

echo "Inference VM init complete"
