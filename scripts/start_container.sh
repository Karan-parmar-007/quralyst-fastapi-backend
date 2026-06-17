#!/usr/bin/env bash
# =============================================================================
# start_container.sh — CodeDeploy AfterInstall hook
# =============================================================================
# Reads the image URI written by CodeBuild (imageDetail.json), logs in to ECR,
# pulls the new image, and starts the backend + Redis via docker compose.
# =============================================================================

set -euo pipefail

DEPLOY_DIR="/home/ubuntu/quralyst-backend"
ENV_FILE="/home/ubuntu/quralyst-backend/.env"
IMAGE_DETAIL="${DEPLOY_DIR}/imageDetail.json"

echo "[start_container] Starting at $(date)"

# ── Validate required files ──────────────────────────────────────────────────
if [ ! -f "$IMAGE_DETAIL" ]; then
    echo "[start_container] ERROR: imageDetail.json not found at ${IMAGE_DETAIL}"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "[start_container] ERROR: .env not found at ${ENV_FILE}"
    echo "[start_container] Place the production .env file on the EC2 at ${ENV_FILE}"
    exit 1
fi

# ── Parse image URI ──────────────────────────────────────────────────────────
IMAGE_URI=$(python3 -c "import json,sys; d=json.load(open('${IMAGE_DETAIL}')); print(d['ImageURI'])")
ECR_REGISTRY=$(echo "$IMAGE_URI" | cut -d'/' -f1)
AWS_REGION=$(echo "$ECR_REGISTRY" | awk -F'.' '{print $4}')

echo "[start_container] Image URI   -> ${IMAGE_URI}"
echo "[start_container] ECR Registry-> ${ECR_REGISTRY}"
echo "[start_container] AWS Region  -> ${AWS_REGION}"

# ── ECR Login ────────────────────────────────────────────────────────────────
echo "[start_container] Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"
echo "[start_container] ECR login successful."

# ── Pull latest image ────────────────────────────────────────────────────────
echo "[start_container] Pulling image: ${IMAGE_URI}"
docker pull "$IMAGE_URI"

# ── Tag as local latest for docker-compose reference ────────────────────────
docker tag "$IMAGE_URI" quralyst-backend:latest
echo "[start_container] Tagged image as quralyst-backend:latest"

# ── Start services via docker compose ───────────────────────────────────────
echo "[start_container] Starting services with docker compose..."
docker compose \
    -f "${DEPLOY_DIR}/docker-compose.yml" \
    --env-file "$ENV_FILE" \
    up -d --remove-orphans

echo "[start_container] Services started. Container status:"
docker compose -f "${DEPLOY_DIR}/docker-compose.yml" ps

echo "[start_container] Done at $(date)"
