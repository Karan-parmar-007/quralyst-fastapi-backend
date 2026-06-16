# =============================================================================
# Quralyst FastAPI Backend — Production Dockerfile
# =============================================================================
# Build strategy  : Single-stage (slim base keeps image small)
# Target image    : python:3.12-slim  (~150 MB base)
# Run as          : non-root user  `appuser` (UID 1001)
# Exposed port    : 8000
# Health check    : GET /health/live  (liveness probe already wired in app)
# =============================================================================

FROM python:3.12-slim

# ---------------------------------------------------------------------------
# 1. OS-level dependencies (only what is strictly required)
# ---------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Create a non-root user and working directory
# ---------------------------------------------------------------------------
RUN groupadd --gid 1001 appgroup \
    && useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# ---------------------------------------------------------------------------
# 3. Install Python dependencies
#    Copy requirements first to exploit Docker layer caching.
# ---------------------------------------------------------------------------
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ---------------------------------------------------------------------------
# 4. Copy application source (excluding everything in .dockerignore)
# ---------------------------------------------------------------------------
COPY --chown=appuser:appgroup . .

# ---------------------------------------------------------------------------
# 5. Drop privileges
# ---------------------------------------------------------------------------
USER appuser

# ---------------------------------------------------------------------------
# 6. Runtime configuration
# ---------------------------------------------------------------------------
EXPOSE 8000

# Environment variables that can be overridden at runtime via --env-file or
# docker-compose.  Sensible defaults are set here where safe to do so.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# ---------------------------------------------------------------------------
# 7. Health check (mirrors the /health/live liveness probe)
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health/live || exit 1

# ---------------------------------------------------------------------------
# 8. Entrypoint
# ---------------------------------------------------------------------------
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT} --workers 2"]
