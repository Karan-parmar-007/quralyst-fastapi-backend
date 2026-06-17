#!/usr/bin/env bash
# =============================================================================
# validate_service.sh — CodeDeploy ValidateService hook
# =============================================================================
# Confirms the backend container is healthy after deployment.
# If validation fails, CodeDeploy triggers automatic rollback.
# =============================================================================

set -euo pipefail

HEALTH_URL="http://localhost:8000/health/live"
READY_URL="http://localhost:8000/health/ready"
MAX_RETRIES=10
RETRY_INTERVAL=6   # seconds between retries (total wait up to 60 s)

echo "[validate_service] Starting at $(date)"
echo "[validate_service] Health endpoint: ${HEALTH_URL}"

# ── Wait for the container to become responsive ──────────────────────────────
attempt=0
until curl -sf "$HEALTH_URL" -o /dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$MAX_RETRIES" ]; then
        echo "[validate_service] ERROR: /health/live did not respond after ${MAX_RETRIES} attempts."
        echo "[validate_service] Container logs:"
        docker logs quralyst-backend --tail 50 2>/dev/null || true
        exit 1
    fi
    echo "[validate_service] Attempt ${attempt}/${MAX_RETRIES} — waiting ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

echo "[validate_service] /health/live responded OK."

# ── Readiness probe (verifies MongoDB connectivity) ──────────────────────────
READY_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$READY_URL" || echo "000")
if [ "$READY_HTTP_CODE" -eq 200 ]; then
    echo "[validate_service] /health/ready returned 200 — MongoDB connected."
else
    echo "[validate_service] WARNING: /health/ready returned HTTP ${READY_HTTP_CODE}."
    echo "[validate_service] This may indicate a MongoDB connectivity issue."
    echo "[validate_service] Container logs:"
    docker logs quralyst-backend --tail 50 2>/dev/null || true
    # Treat readiness failure as deployment failure to trigger rollback
    exit 1
fi

echo "[validate_service] ✅ Deployment validated successfully at $(date)"

# ── Cleanup Old Backend Docker Images ─────────────────────────────────────────
echo "[validate_service] Starting Docker image cleanup..."

REPO_NAME="438465146066.dkr.ecr.us-west-1.amazonaws.com/quralyst-backend-dev"

# `docker images` returns images sorted by creation date (newest first) by default
ALL_IMAGES=$(docker images --format '{{.ID}}' "$REPO_NAME")
IMAGE_COUNT=$(echo "$ALL_IMAGES" | grep -v '^$' | wc -l || true)

echo "[validate_service] Found ${IMAGE_COUNT} backend images."

if [ "$IMAGE_COUNT" -gt 2 ]; then
    # Skip the first 2 (newest) and target the rest
    OLD_IMAGES=$(echo "$ALL_IMAGES" | awk 'NR>2')
    
    for img in $OLD_IMAGES; do
        echo "[validate_service] Removing old backend image: $img"
        # Safe remove: docker rmi will automatically fail if the image is in use by a running container
        docker rmi "$img" || echo "[validate_service] Skipped $img (may be in use)."
    done
else
    echo "[validate_service] 2 or fewer backend images found. No backend cleanup needed."
fi

# ── Safe Docker System Prune ──────────────────────────────────────────────────
echo "[validate_service] Running safe docker cleanup for unused resources..."
# Removes stopped containers, unused networks, dangling images, and build cache.
# Does NOT remove active volumes, running containers, or tagged images (like redis:7-alpine).
docker system prune -f
