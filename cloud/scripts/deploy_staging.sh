#!/usr/bin/env bash
set -euo pipefail

SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-root}"
REPO_URL="${REPO_URL:-https://github.com/1509797225/super-succotash.git}"
REMOTE_DIR="${REMOTE_DIR:-/opt/jellytodo}"
DEBUG_SECRET="${DEBUG_SECRET:-}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

if [[ -z "$SERVER_HOST" ]]; then
  echo "Missing SERVER_HOST."
  echo "Usage:"
  echo "  SERVER_HOST=1.2.3.4 DEBUG_SECRET=xxx POSTGRES_PASSWORD=xxx ./cloud/scripts/deploy_staging.sh"
  exit 1
fi

if [[ -z "$DEBUG_SECRET" ]]; then
  DEBUG_SECRET="$(openssl rand -hex 24)"
fi

if [[ -z "$POSTGRES_PASSWORD" ]]; then
  POSTGRES_PASSWORD="$(openssl rand -hex 18)"
fi

echo "== JellyTodo staging deploy =="
echo "Server: ${SERVER_USER}@${SERVER_HOST}"
echo "Remote dir: ${REMOTE_DIR}"
echo ""

ssh "${SERVER_USER}@${SERVER_HOST}" "bash -s" <<REMOTE
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  apt-get update
  apt-get install -y git
fi

if ! command -v docker >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

mkdir -p "${REMOTE_DIR}"

if [[ -d "${REMOTE_DIR}/.git" ]]; then
  cd "${REMOTE_DIR}"
  git fetch origin
  git checkout main
  git pull --ff-only origin main
else
  rm -rf "${REMOTE_DIR}"
  git clone "${REPO_URL}" "${REMOTE_DIR}"
  cd "${REMOTE_DIR}"
fi

cd "${REMOTE_DIR}/cloud"

cat > .env <<ENV
NODE_ENV=staging
PORT=3000
DATABASE_URL=postgres://jellytodo:${POSTGRES_PASSWORD}@postgres:5432/jellytodo
DEBUG_SECRET=${DEBUG_SECRET}
ENV

python3 - <<'PY'
from pathlib import Path
path = Path("docker-compose.staging.yml")
text = path.read_text()
start = "POSTGRES_PASSWORD: "
lines = []
password = "${POSTGRES_PASSWORD}"
for line in text.splitlines():
    if line.strip().startswith(start):
        indent = line[:len(line) - len(line.lstrip())]
        lines.append(f"{indent}POSTGRES_PASSWORD: {password}")
    else:
        lines.append(line)
path.write_text("\\n".join(lines) + "\\n")
PY

docker compose -f docker-compose.staging.yml up -d --build
docker compose -f docker-compose.staging.yml ps
REMOTE

echo ""
echo "Deploy complete."
echo "Health check:"
echo "  curl http://${SERVER_HOST}:3000/health"
echo ""
echo "Seed example:"
echo "  curl -X POST http://${SERVER_HOST}:3000/debug/seed \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'x-debug-secret: ${DEBUG_SECRET}' \\"
echo "    -d '{\"level\":\"basic\"}'"
