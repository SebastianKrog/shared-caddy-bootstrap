#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

setup_defaults

require_command bash
require_command docker
require_command flock

require_env APP_NAME
require_env APP_SERVICE
require_env COMPOSE_FILE

: "${STOP_SHARED_CADDY_IF_EMPTY:=false}"

require_file "$COMPOSE_FILE" "Compose file"

docker_compose stop "$APP_SERVICE" >/dev/null || true

acquire_lock

if docker ps -a --format '{{.Names}}' | grep -qx "$SHARED_CADDY_CONTAINER"; then
  if docker ps --format '{{.Names}}' | grep -qx "$SHARED_CADDY_CONTAINER"; then
    docker exec "$SHARED_CADDY_CONTAINER" rm -f "/etc/caddy/sites/${APP_NAME}.caddy"
    validate_and_reload_caddy

    if [[ "$STOP_SHARED_CADDY_IF_EMPTY" == "true" ]]; then
      SITE_COUNT="$(
        docker exec "$SHARED_CADDY_CONTAINER" sh -c 'find /etc/caddy/sites -maxdepth 1 -type f -name "*.caddy" | wc -l'
      )"
      if [[ "$SITE_COUNT" == "0" ]]; then
        docker stop "$SHARED_CADDY_CONTAINER" >/dev/null
      fi
    fi
  else
    docker start "$SHARED_CADDY_CONTAINER" >/dev/null
    docker exec "$SHARED_CADDY_CONTAINER" rm -f "/etc/caddy/sites/${APP_NAME}.caddy"
    validate_and_reload_caddy

    if [[ "$STOP_SHARED_CADDY_IF_EMPTY" == "true" ]]; then
      SITE_COUNT="$(
        docker exec "$SHARED_CADDY_CONTAINER" sh -c 'find /etc/caddy/sites -maxdepth 1 -type f -name "*.caddy" | wc -l'
      )"
      if [[ "$SITE_COUNT" == "0" ]]; then
        docker stop "$SHARED_CADDY_CONTAINER" >/dev/null
      fi
    fi
  fi
fi

echo "Teardown complete for ${APP_NAME}."
