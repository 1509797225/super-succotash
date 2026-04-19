# Cloud Scripts

## Native Ubuntu Deployment

Run this on the Ubuntu server after cloning the repo:

```bash
cd super-succotash
APP_USER=ubuntu ./cloud/scripts/deploy_native_ubuntu.sh
```

This path avoids Docker Hub and installs PostgreSQL, Node.js, nginx, and a `jellytodo-cloud.service` systemd unit directly on Ubuntu.

After deployment:

```bash
curl http://127.0.0.1/health
```

For public access, open inbound TCP `80` in the cloud security group. Open `3000` only for temporary direct staging tests.

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

Docker assumptions:

- Server is Ubuntu or Debian-like with `apt-get`.
- SSH from your Mac to the server already works.
- The server user has root privileges.
- Ports `3000` and `22` are reachable during staging.

After deployment:

```bash
curl http://1.2.3.4:3000/health
```
