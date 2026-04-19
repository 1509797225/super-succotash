#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLOUD_DIR="$ROOT_DIR/cloud"
API_DIR="$CLOUD_DIR/api"

APP_USER="${APP_USER:-$(id -un)}"
DB_NAME="${DB_NAME:-jellytodo}"
DB_USER="${DB_USER:-jellytodo}"
PORT="${PORT:-3000}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
DEBUG_SECRET="${DEBUG_SECRET:-$(openssl rand -hex 32)}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -hex 24)}"

echo "Installing native Ubuntu runtime..."
sudo apt-get update
sudo apt-get install -y nodejs npm postgresql nginx
sudo systemctl enable --now postgresql

echo "Creating PostgreSQL database and role..."
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
  ELSE
    ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
SQL

echo "Writing cloud environment..."
cat > "$CLOUD_DIR/.env" <<EOF
NODE_ENV=staging
PORT=${PORT}
DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@127.0.0.1:5432/${DB_NAME}
DEBUG_SECRET=${DEBUG_SECRET}
EOF
chmod 600 "$CLOUD_DIR/.env"

echo "Installing API dependencies..."
cd "$API_DIR"
npm config set registry "$NPM_REGISTRY"
npm install --omit=dev
npm run check

echo "Installing systemd service..."
sudo tee /etc/systemd/system/jellytodo-cloud.service >/dev/null <<EOF
[Unit]
Description=JellyTodo Cloud Staging API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${CLOUD_DIR}
EnvironmentFile=${CLOUD_DIR}/.env
ExecStart=/usr/bin/node api/src/server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jellytodo-cloud
sudo systemctl restart jellytodo-cloud

echo "Configuring nginx reverse proxy on port 80..."
sudo tee /etc/nginx/sites-available/jellytodo >/dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 4m;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/jellytodo /etc/nginx/sites-enabled/jellytodo
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Validating local health check..."
curl -sS "http://127.0.0.1/health"
echo
echo "Native Ubuntu deployment finished. Open inbound TCP 80 or 3000 in the cloud security group for public access."
