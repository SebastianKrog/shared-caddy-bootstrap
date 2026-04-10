#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

setup_defaults

require_command bash
require_command docker
require_command flock
require_command sed
require_command mktemp

require_env APP_NAME
require_env APP_SERVICE
require_env COMPOSE_FILE
require_env SITE_FILE
require_env SITE_DOMAIN

require_file "$COMPOSE_FILE" "Compose file"
require_file "$SITE_FILE" "Site snippet"
require_file "$BASE_CADDYFILE" "Base Caddyfile"

# External network must exist before docker compose can start the app service.
ensure_shared_network
ensure_shared_volumes

docker_compose up -d "$APP_SERVICE"

acquire_lock

ensure_shared_network
ensure_shared_volumes
ensure_caddy_exists_or_running

docker cp "$BASE_CADDYFILE" "$SHARED_CADDY_CONTAINER:/etc/caddy/Caddyfile"

TMP_SITE_FILE="$(render_site_file)"
trap 'rm -f "$TMP_SITE_FILE"' EXIT
docker cp "$TMP_SITE_FILE" "$SHARED_CADDY_CONTAINER:/etc/caddy/sites/${APP_NAME}.caddy"

validate_and_reload_caddy

echo "Bootstrap complete. ${APP_NAME} registered in ${SHARED_CADDY_CONTAINER}."
