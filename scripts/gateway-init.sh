#!/bin/bash
set -euxo pipefail

INFERENCE_IP="${inference_private_ip}"
PROJECT_DIR="/opt/alchemyst"
REPO_URL="https://github.com/cotishq/alchemyst-devops-assignment.git"

# curl-minimal is already installed on AL2023, don't reinstall curl
dnf update -y
dnf install -y git nginx

# Node.js 20
dnf install -y nodejs npm

# Bun
export HOME=/root
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="/root/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
echo 'export BUN_INSTALL="/root/.bun"' >> /etc/environment
echo 'export PATH="/root/.bun/bin:$PATH"' >> /etc/environment

# iii CLI
curl -fsSL https://iii.dev/install.sh | bash
export PATH="/root/.iii/bin:$PATH"
echo 'export PATH="/root/.iii/bin:$PATH"' >> /etc/environment

# Clone repo
mkdir -p $PROJECT_DIR
git clone $REPO_URL $PROJECT_DIR
cd $PROJECT_DIR/quickstart

# Fix config.yaml
cat > $PROJECT_DIR/quickstart/config.yaml << 'CONFIGEOF'
workers:
  - name: iii-observability
    config:
      enabled: true
      service_name: iii
      exporter: memory
      memory_max_spans: 10000
      metrics_enabled: true
      metrics_exporter: memory
      logs_enabled: true
      logs_exporter: memory
      logs_console_output: true
      sampling_ratio: 1.0

  - name: iii-queue
    config:
      adapter:
        name: builtin

  - name: iii-state
    config:
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: ./data/state_store.db

  - name: iii-http
    config:
      port: 3111
      host: 0.0.0.0
      default_timeout: 60000
      concurrency_request_limit: 1024
      cors:
        allowed_origins:
          - '*'
        allowed_methods:
          - GET
          - POST
          - PUT
          - DELETE
          - OPTIONS

  - name: caller-worker
    worker_path: /opt/alchemyst/quickstart/workers/caller-worker
CONFIGEOF

# Install caller-worker deps
cd $PROJECT_DIR/quickstart/workers/caller-worker
/root/.bun/bin/bun install

# systemd: iii engine
cat > /etc/systemd/system/iii-engine.service << 'SVCEOF'
[Unit]
Description=iii Engine
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/alchemyst/quickstart
Environment="PATH=/root/.iii/bin:/root/.bun/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HOME=/root"
ExecStart=/root/.iii/bin/iii --config /opt/alchemyst/quickstart/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

# nginx config
cat > /etc/nginx/conf.d/alchemyst.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3111;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }
}
NGINXEOF

rm -f /etc/nginx/conf.d/default.conf

systemctl daemon-reload
systemctl enable iii-engine
systemctl start iii-engine
systemctl enable nginx
systemctl start nginx

echo "Gateway init complete"
