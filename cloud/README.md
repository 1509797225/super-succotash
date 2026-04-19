# JellyTodo Cloud Staging

This folder contains the first deployable cloud test environment for JellyTodo.

It is intentionally small:

- Node.js + Express API
- PostgreSQL
- Docker Compose
- Debug seed/reset endpoints
- Basic sync pull/push API shape for future iOS integration

## Deployment Order

Recommended order:

1. Deploy this cloud staging service first.
2. Validate `health`, `debug seed`, `summary`, and `sync pull`.
3. Keep iOS client unchanged until the API shape is stable.
4. Later add iOS sync client and local SQLite migration.

Do not connect the iOS app directly to PostgreSQL. The app should only talk to this API through HTTPS.

## Local Run

```bash
cd cloud
cp .env.example .env
docker compose -f docker-compose.staging.yml up --build
```

Health check:

```bash
curl http://localhost:3000/health
```

Seed staging data:

```bash
curl -X POST http://localhost:3000/debug/seed \
  -H 'Content-Type: application/json' \
  -H 'x-debug-secret: change-this-debug-secret' \
  -d '{"level":"basic"}'
```

Available levels:

```text
basic
medium
large
heavy
```

Summary:

```bash
curl -H 'x-debug-secret: change-this-debug-secret' \
  http://localhost:3000/debug/summary
```

Reset staging data:

```bash
curl -X POST http://localhost:3000/debug/reset \
  -H 'x-debug-secret: change-this-debug-secret'
```

Pull sync data:

```bash
curl 'http://localhost:3000/sync/pull'
```

## Server Deployment

On your cloud server:

```bash
git clone https://github.com/1509797225/super-succotash.git
cd super-succotash/cloud
cp .env.example .env
```

Edit `.env`:

```text
DATABASE_URL=postgres://jellytodo:<strong-password>@postgres:5432/jellytodo
DEBUG_SECRET=<long-random-secret>
```

Also update `POSTGRES_PASSWORD` in `docker-compose.staging.yml` to match the password in `DATABASE_URL`.

Then run:

```bash
docker compose -f docker-compose.staging.yml up -d --build
```

Open only `80/443/22` publicly on a real server. PostgreSQL should not expose a public port.

If you use Caddy for HTTPS, copy the example:

```bash
sudo cp Caddyfile.example /etc/caddy/Caddyfile
sudo nano /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Replace `api.your-domain.com` with your real domain and point the domain A record to your server IP first.

## Production Safety

The debug endpoints are for staging only:

- `/debug/seed`
- `/debug/reset`
- `/debug/summary`

Keep `DEBUG_SECRET` private. Disable or firewall these endpoints before production.
