#!/usr/bin/env bash
# =============================================================================
# stop_container.sh — CodeDeploy BeforeInstall hook
# =============================================================================
# Gracefully stops the running quralyst-backend container (if any).
# Safe to run even if no container is running.
# =============================================================================

set -euo pipefail

DEPLOY_DIR="/home/ubuntu/quralyst-backend"
CONTAINER_NAME="quralyst-backend"

echo "[stop_container] Starting at $(date)"

cd "$DEPLOY_DIR" 2>/dev/null || true

# Stop the backend container if it is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[stop_container] Stopping container: ${CONTAINER_NAME}"
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
    echo "[stop_container] Container stopped and removed."
else
    echo "[stop_container] No running container named '${CONTAINER_NAME}' — nothing to stop."
fi

# Stop via docker compose as a fallback (handles redis as well)
if [ -f "${DEPLOY_DIR}/docker-compose.yml" ]; then
    echo "[stop_container] Running docker compose down..."
    docker compose -f "${DEPLOY_DIR}/docker-compose.yml" down --remove-orphans 2>/dev/null || true
fi

echo "[stop_container] Done at $(date)"
