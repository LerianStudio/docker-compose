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

# Absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PLUGIN_SCRIPT="$SCRIPT_DIR/scripts/add-plugin.sh"

# 1. Start the NGINX container so the add-plugin script can work
log "info" "Starting NGINX container..."
(cd "$SCRIPT_DIR" && compose up -d nginx)

# 2. Loop to process all plugins passed as arguments
if [ "$#" -eq 0 ]; then
    log "error" "Usage: $0 <plugin-name1> <plugin-port1> [<plugin-name2> <plugin-port2> ...]"
    exit 1
fi

while [ "$#" -gt 0 ]; do
    PLUGIN_NAME=$1
    PLUGIN_PORT=$2

    if [ -z "$PLUGIN_NAME" ] || [ -z "$PLUGIN_PORT" ]; then
        log "error" "Incomplete plugin and port arguments."
        exit 1
    fi

    log "info" "Configuring plugin $PLUGIN_NAME on port $PLUGIN_PORT..."
    bash "$ADD_PLUGIN_SCRIPT" "$PLUGIN_NAME" "$PLUGIN_PORT"

    shift 2
done

log "info" "Process completed."