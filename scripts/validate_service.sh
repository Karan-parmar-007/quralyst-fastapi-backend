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
