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
