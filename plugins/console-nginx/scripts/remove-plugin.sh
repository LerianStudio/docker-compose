#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
  local type=$1
  local message=$2
  case $type in
    info)  echo -e "${GREEN}[INFO]${NC} $message" ;;
    warn)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
    error) echo -e "${RED}[ERROR]${NC} $message" ;;
  esac
}

# Docker Compose helper that supports both v1 (docker-compose) and v2 (docker compose)
compose() {
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

PLUGIN_NAME=$1

if [[ -z "$PLUGIN_NAME" ]]; then
  log "error" "Usage: ./remove-plugin.sh <plugin-name>"
  log "info" "Example: ./remove-plugin.sh crm"
  exit 1
fi

# Absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_CONF_PATH="$BASE_DIR/nginx/plugins/${PLUGIN_NAME}.conf"

# Check if plugin configuration exists
if [[ ! -f "$PLUGIN_CONF_PATH" ]]; then
  log "warn" "Plugin configuration file not found: $PLUGIN_CONF_PATH"
  log "info" "Plugin '$PLUGIN_NAME' may not be installed or already removed"
  exit 0
fi

log "info" "Removing plugin configuration for '$PLUGIN_NAME'..."

# Remove the configuration file
if rm "$PLUGIN_CONF_PATH"; then
  log "info" "Configuration file removed: $PLUGIN_CONF_PATH"
else
  log "error" "Failed to remove configuration file: $PLUGIN_CONF_PATH"
  exit 1
fi

# Check if NGINX is running in Docker (prefer known container name)
NGINX_CONTAINER=midaz-nginx
NGINX_ID=$(docker ps -q -f name="^${NGINX_CONTAINER}$")
if [[ -n "$NGINX_ID" ]]; then
  log "info" "Reloading NGINX configuration (container: $NGINX_CONTAINER)..."
  if docker exec "$NGINX_CONTAINER" nginx -s reload; then
    log "info" "NGINX reloaded successfully"
  else
    log "warn" "docker exec failed; trying compose exec ..."
    (cd "$BASE_DIR" && compose exec -T nginx nginx -s reload) && log "info" "NGINX reloaded via compose"
  fi
else
  # Fallback: try compose exec if service is up without the expected name
  if (cd "$BASE_DIR" && compose ps --services | grep -q '^nginx$'); then
    log "info" "Reloading NGINX via compose exec ..."
    (cd "$BASE_DIR" && compose exec -T nginx nginx -s reload) && log "info" "NGINX reloaded"
  else
    log "warn" "NGINX container not found. Configuration removed but NGINX not reloaded."
    log "info" "Start NGINX with 'docker compose up -d nginx' to apply changes"
  fi
fi

# Unregister plugin from console API
log "info" "Unregistering plugin '$PLUGIN_NAME' from the main console via API..."

HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -X DELETE \
  "http://localhost/api/plugin/manifest/unregister/" \
  -H "Content-Type: application/json" \
  -d "{\"host\": \"${PLUGIN_NAME}\"}")

HTTP_CODE=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS:.*//g')

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
  log "info" "Plugin unregistered successfully!"
elif [[ "$HTTP_CODE" == "404" ]]; then
  log "warn" "Plugin was not registered in the console (404 - Not Found)"
else
  log "warn" "Failed to unregister plugin from the main console (HTTP $HTTP_CODE)"
  if [[ -n "$HTTP_BODY" ]]; then
    log "warn" "Response: $HTTP_BODY"
  fi
fi

# Verify plugin route is no longer accessible
PLUGIN_ROUTE="http://localhost/${PLUGIN_NAME}/"
log "info" "Verifying plugin route is no longer accessible: $PLUGIN_ROUTE"

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" "$PLUGIN_ROUTE")
if [[ "$HTTP_CODE" == "404" ]]; then
  log "info" "Plugin route successfully removed (404 - Not Found)"
elif [[ "$HTTP_CODE" == "502" || "$HTTP_CODE" == "503" ]]; then
  log "info" "Plugin route removed but service may still be running (HTTP $HTTP_CODE)"
  log "info" "Consider stopping the plugin container if no longer needed"
else
  log "warn" "Plugin route still accessible (HTTP $HTTP_CODE). Manual verification recommended."
fi

log "info" "Plugin '$PLUGIN_NAME' removal completed!"
log "info" "Note: This script only removes the NGINX configuration and API registration."
log "info" "To fully remove the plugin, also stop and remove its Docker container."
