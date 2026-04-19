# Cloud Scripts

## Deploy Staging

Run from repo root:

```bash
SERVER_HOST=1.2.3.4 \
SERVER_USER=root \
DEBUG_SECRET=replace-with-long-secret \
POSTGRES_PASSWORD=replace-with-db-password \
./cloud/scripts/deploy_staging.sh
```

If `DEBUG_SECRET` or `POSTGRES_PASSWORD` is omitted, the script generates random values.

Assumptions:

- Server is Ubuntu or Debian-like with `apt-get`.
- SSH from your Mac to the server already works.
- The server user has root privileges.
- Ports `3000` and `22` are reachable during staging.

After deployment:

```bash
curl http://1.2.3.4:3000/health
```
