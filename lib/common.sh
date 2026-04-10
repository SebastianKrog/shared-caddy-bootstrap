#!/usr/bin/env bash
set -euo pipefail

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "$path" ]]; then
    echo "$label not found: $path" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Required environment variable is missing: $name" >&2
    exit 1
  fi
}

docker_compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

ensure_shared_network() {
  docker network inspect "$SHARED_PROXY_NETWORK" >/dev/null 2>&1 || \
    docker network create "$SHARED_PROXY_NETWORK" >/dev/null
}

ensure_shared_volumes() {
  docker volume inspect "$SHARED_CADDY_DATA_VOLUME" >/dev/null 2>&1 || \
    docker volume create "$SHARED_CADDY_DATA_VOLUME" >/dev/null

  docker volume inspect "$SHARED_CADDY_CONFIG_VOLUME" >/dev/null 2>&1 || \
    docker volume create "$SHARED_CADDY_CONFIG_VOLUME" >/dev/null
}

ensure_caddy_exists_or_running() {
  if ! docker ps -a --format '{{.Names}}' | grep -qx "$SHARED_CADDY_CONTAINER"; then
    docker run -d \
      --name "$SHARED_CADDY_CONTAINER" \
      --network "$SHARED_PROXY_NETWORK" \
      -p 80:80 \
      -p 443:443 \
      -v "$SHARED_CADDY_DATA_VOLUME:/data" \
      -v "$SHARED_CADDY_CONFIG_VOLUME:/etc/caddy" \
      "$CADDY_IMAGE" \
      sh -c 'mkdir -p /etc/caddy/sites && printf "{\n    admin 0.0.0.0:2019\n}\n\nimport /etc/caddy/sites/*.caddy\n" > /etc/caddy/Caddyfile && exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile' \
      >/dev/null
    return
  fi

  if ! docker ps --format '{{.Names}}' | grep -qx "$SHARED_CADDY_CONTAINER"; then
    docker start "$SHARED_CADDY_CONTAINER" >/dev/null
  fi
}

render_site_file() {
  local tmp_file
  tmp_file="$(mktemp)"
  sed "s|__SITE_DOMAIN__|${SITE_DOMAIN}|g" "$SITE_FILE" > "$tmp_file"
  echo "$tmp_file"
}

validate_and_reload_caddy() {
  docker exec "$SHARED_CADDY_CONTAINER" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
  docker exec "$SHARED_CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
}

acquire_lock() {
  exec 9>"$SHARED_CADDY_LOCK_FILE"
  flock 9
}

setup_defaults() {
  : "${BASE_CADDYFILE:="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/caddy/base/Caddyfile"}"
  : "${SHARED_CADDY_CONTAINER:=shared-caddy}"
  : "${SHARED_PROXY_NETWORK:=shared-proxy}"
  : "${SHARED_CADDY_DATA_VOLUME:=shared-caddy-data}"
  : "${SHARED_CADDY_CONFIG_VOLUME:=shared-caddy-config}"
  : "${SHARED_CADDY_LOCK_FILE:=/tmp/shared-caddy-bootstrap.lock}"
  : "${CADDY_IMAGE:=caddy:2}"
}
