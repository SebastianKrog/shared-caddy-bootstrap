# shared-caddy-bootstrap

Shared deploy-time bootstrap for a single shared Caddy instance that multiple
projects can attach to.

This repo is not a separately deployed service. It is a versioned deploy helper.
Projects download a pinned release tarball during deploy, then call `bootstrap.sh`
or `teardown.sh`.

## What it does

- ensures the shared Docker network exists
- ensures shared Caddy data/config volumes exist
- starts the app service from the caller's compose file
- creates or starts the shared `shared-caddy` container
- installs the base Caddyfile
- installs the caller's site snippet
- validates and reloads Caddy
- uses `flock` to serialize shared-Caddy mutation

## Required on the target server

- bash
- docker with `docker compose`
- `flock` available on PATH
- Linux host

## Interface

The scripts are configured entirely by environment variables.

### Required for `bootstrap.sh`

- `APP_NAME`
- `APP_SERVICE`
- `COMPOSE_FILE`
- `SITE_FILE`
- `SITE_DOMAIN`

### Optional overrides

- `BASE_CADDYFILE`
- `SHARED_CADDY_CONTAINER`
- `SHARED_PROXY_NETWORK`
- `SHARED_CADDY_DATA_VOLUME`
- `SHARED_CADDY_CONFIG_VOLUME`
- `SHARED_CADDY_LOCK_FILE`
- `CADDY_IMAGE`

## Example caller usage

```bash
tar -xzf /tmp/shared-caddy-bootstrap-v1.0.0.tar.gz -C /tmp
SITE_DOMAIN="$(grep ^SITE_DOMAIN= .env | cut -d= -f2-)" \
APP_NAME="r_runner" \
APP_SERVICE="r-runner" \
COMPOSE_FILE="compose.yaml" \
SITE_FILE="deploy/caddy/sites/r_runner.caddy" \
/tmp/shared-caddy-bootstrap/bin/bootstrap.sh
```

## GitHub Actions deploy commands

Most callers run the bootstrap script over SSH inside their deploy workflow.
At minimum, the deploy job should run commands equivalent to:

```bash
set -e
cd /opt/<your-app>
docker compose -f compose.yaml pull

bootstrap_version="<pinned-release-tag>"
bootstrap_tmp_dir="$(mktemp -d /tmp/shared-caddy-bootstrap.XXXXXX)"
bootstrap_tarball="${bootstrap_tmp_dir}/shared-caddy-bootstrap-${bootstrap_version}.tar.gz"
bootstrap_url="https://github.com/SebastianKrog/shared-caddy-bootstrap/releases/download/${bootstrap_version}/shared-caddy-bootstrap-${bootstrap_version}.tar.gz"
trap 'rm -rf "${bootstrap_tmp_dir}"' EXIT

curl -fsSL "$bootstrap_url" -o "$bootstrap_tarball"
tar -xzf "$bootstrap_tarball" -C "$bootstrap_tmp_dir" --strip-components=1

SITE_DOMAIN="$(grep ^SITE_DOMAIN= .env | cut -d= -f2-)" \
APP_NAME="<app-name>" \
APP_SERVICE="<compose-service-name>" \
COMPOSE_FILE="compose.yaml" \
SITE_FILE="deploy/caddy/sites/<site-file>.caddy" \
"$bootstrap_tmp_dir/bin/bootstrap.sh"
```

In a GitHub Actions workflow, this is usually executed in an SSH step (for
example `ssh user@host '...commands above...'`) after copying `compose.yaml`,
the site file, and `.env` to the server.

## Caller repo responsibilities

Each app repo keeps only its own app-specific files, for example:

```text
deploy/
  caddy/
    sites/
      r_runner.caddy
compose.yaml
```

Example snippet:

```caddy
__SITE_DOMAIN__ {
    encode gzip
    reverse_proxy r-runner:8000
}
```
