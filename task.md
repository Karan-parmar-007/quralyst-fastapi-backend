# Quralyst FastAPI Backend — Task & Architecture Reference

> **Single source of truth** for all infrastructure, development, deployment, and governance work on the `quralyst-fastapi-backend` repository.
> Last updated: 2026-06-16

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Current Architecture](#2-current-architecture)
3. [AWS Infrastructure](#3-aws-infrastructure)
4. [Development Environment](#4-development-environment)
5. [Docker Tasks (Phase 1)](#5-docker-tasks-phase-1)
6. [CI/CD Tasks (Phases 2–5)](#6-cicd-tasks-phases-25)
7. [Completed Tasks](#7-completed-tasks)
8. [Pending Tasks](#8-pending-tasks)
9. [Files Changed Log](#9-files-changed-log)
10. [Validation Reports](#10-validation-reports)
11. [Future Roadmap](#11-future-roadmap)

---

## 1. Project Overview

| Field        | Value |
|-------------|-------|
| **Product**  | Quralyst — AI-powered query intelligence platform |
| **Repo**     | `quralyst-fastapi-backend` |
| **GitHub**   | https://github.com/Karan-parmar-007/quralyst-fastapi-backend |
| **Language** | Python 3.12 |
| **Framework**| FastAPI (v0.136.3) + Uvicorn (v0.49.0) |
| **Database** | MongoDB Atlas (external managed, async via `pymongo`) |
| **Cache**    | Redis 7 (Docker sidecar) |
| **Auth**     | JWT (HS256) via `itsdangerous` |

### Governance Rules (Must Always Follow)

- ✅ Never commit directly to `master`.
- ✅ Always work on a `feature/*` branch → PR → review → merge.
- ✅ All completed tasks must be logged in this file.
- ✅ No application logic, routes, auth, or MongoDB implementation changes — infrastructure work only.
- ✅ Do NOT create AWS resources until credentials are provided and approved.
- ✅ Do NOT merge a PR until approved.
- ✅ CI/CD triggers on `master` branch only.

---

## 2. Current Architecture

```
quralyst-fastapi-backend/
├── main.py                          # FastAPI app factory + lifespan handler
├── requirements.txt                 # Pinned Python dependencies
├── Dockerfile                       # Production container image           [NEW]
├── docker-compose.yml               # Local / EC2 dev orchestration        [NEW]
├── .dockerignore                    # Build-context exclusions              [NEW]
├── buildspec.yml                    # CodeBuild pipeline definition         [NEW]
├── appspec.yml                      # CodeDeploy deployment manifest        [NEW]
├── .env                             # Local secrets (git-ignored)
├── .env.example                     # Safe template (committed)             [NEW]
├── .gitignore
├── task.md                          # This file                             [NEW]
├── scripts/
│   ├── stop_container.sh            # CodeDeploy BeforeInstall hook         [NEW]
│   ├── start_container.sh           # CodeDeploy AfterInstall hook          [NEW]
│   └── validate_service.sh          # CodeDeploy ValidateService hook       [NEW]
└── app/
    ├── config.py                    # Pydantic-settings (DatabaseSettings, AuthSettings)
    ├── api/
    │   ├── main_router.py
    │   ├── dependencies.py
    │   ├── db_dependencies.py
    │   ├── middlewares/csrf.py
    │   └── routes/health/
    │       ├── health_routes.py     # GET /health/live, GET /health/ready
    │       ├── health_schemas.py
    │       └── health_service.py
    └── db/
        └── mongo_session.py         # AsyncMongoClient wrapper
```

### API Endpoints

| Method | Path             | Description                           |
|--------|-----------------|---------------------------------------|
| GET    | `/health/live`  | Liveness probe — no external deps     |
| GET    | `/health/ready` | Readiness probe — verifies MongoDB    |

---

## 3. AWS Infrastructure

### Development EC2

| Property        | Value                   |
|----------------|-------------------------|
| Instance ID    | `i-06e3f585b2d4d1d4c`  |
| Instance Type  | `t3.large` (2 vCPU / 8 GB RAM) |
| OS             | Ubuntu 24.04 LTS        |
| Pre-installed  | Docker, Docker Compose, Nginx, CodeDeploy Agent, SSM Agent |

### Domain Routing (Nginx — target state)

| Domain                     | Target                |
|---------------------------|----------------------|
| `dev.fe.quralyst.ai`      | Frontend container (already working) |
| `dev.api.quralyst.ai`     | Backend container (port 8000) |

### Target Deployment Architecture

```
Backend Repo (GitHub master branch)
   ↓  PR merge triggers pipeline
AWS CodePipeline (Source stage — GitHub connection)
   ↓
AWS CodeBuild
   ├─ docker build -t quralyst-backend:latest .
   ├─ docker tag  :$COMMIT_SHA
   └─ docker push both tags → ECR
AWS ECR  (quralyst-backend-dev)
   └─ Lifecycle policy: keep latest 2 images, delete older
   ↓
AWS CodeDeploy
   ├─ appspec.yml lifecycle
   │    BeforeInstall  → stop_container.sh
   │    AfterInstall   → start_container.sh   (pulls from ECR)
   │    ValidateService→ validate_service.sh
   └─ Auto-rollback on ValidateService failure
Development EC2 (i-06e3f585b2d4d1d4c)
   ├─ Backend Docker container  (port 8000)
   └─ Redis Docker container    (internal only)
   ↓
MongoDB Atlas  (external, managed)
Nginx reverse proxy
   dev.api.quralyst.ai → localhost:8000
```

### Port Map (EC2)

| Service      | Internal Port | Host Exposed |
|-------------|--------------|--------------|
| Frontend    | (existing)   | 80 / 443     |
| Backend     | 8000         | 8000         |
| Redis       | 6379         | No (internal bridge only) |

---

## 4. Development Environment

### Prerequisites

- Python 3.12
- Docker ≥ 24.x
- Docker Compose ≥ 2.x
- AWS CLI v2 (for Phases 2–5)

### Local Setup (Completed)

```bash
# Clone
git clone https://github.com/Karan-parmar-007/quralyst-fastapi-backend.git
cd quralyst-fastapi-backend

# Create virtual environment
python3 -m venv .venv && source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env   # Fill in real values

# Start (no Docker)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Start (with Docker)
docker compose up --build -d
```

### Environment Variables

| Variable                              | Required | Default | Description |
|--------------------------------------|----------|---------|-------------|
| `MONGO_URI`                          | ✅       | —       | MongoDB Atlas connection string |
| `MONGO_DB_NAME`                      | ✅       | —       | Target database name |
| `SECRET_KEY`                         | ✅       | —       | JWT signing key |
| `ALGORITHM`                          | ❌       | `HS256` | JWT algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES`        | ❌       | `30`    | Access token TTL |
| `REFRESH_TOKEN_EXPIRE_DAYS`          | ❌       | `7`     | Refresh token TTL |
| `RESET_PASSWORD_TOKEN_EXPIRE_MINUTES`| ❌       | `15`    | Password-reset token TTL |
| `FORGET_PASSWORD_TOKEN_EXPIRE_MINUTES`| ❌      | `15`    | Forgot-password token TTL |
| `EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES`| ❌  | `15`    | Email verification TTL |
| `CSRF_SECRET_KEY`                    | ❌       | —       | Falls back to `SECRET_KEY` |

> **EC2 Note:** Place the production `.env` file at `/home/ubuntu/quralyst-backend/.env` on the EC2 instance. The deployment scripts expect it there. This file must NOT be committed to git.

---

## 5. Docker Tasks (Phase 1)

### Design Decisions

| Decision               | Choice                         | Reason |
|-----------------------|-------------------------------|--------|
| Base image            | `python:3.12-slim`            | ~160 MB, minimal attack surface |
| Build strategy        | Single-stage                  | No compiled extensions; multi-stage adds complexity without benefit |
| Non-root user         | `appuser` UID 1001            | Security hardening |
| Layer caching         | requirements.txt copied first | Avoids reinstalling deps on every code change |
| Health check          | `GET /health/live`            | Mirrors existing FastAPI liveness probe |
| Uvicorn workers       | 2                             | Matches t3.large 2-vCPU count |
| Redis exposure        | Internal bridge only          | No host-port binding — backend reaches it via Docker network |
| Secret injection      | `env_file` in Compose         | Secrets never baked into image |

### Docker Quick Reference

```bash
# Build
docker build -t quralyst-backend:latest .

# Run standalone (with env file)
docker run --rm --env-file .env -p 8000:8000 quralyst-backend:latest

# Full stack (backend + redis)
docker compose up --build -d

# Logs
docker compose logs -f backend
docker compose logs -f redis

# Health checks
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready

# Stop
docker compose down

# Stop + remove volumes
docker compose down -v

# Image size check
docker image ls quralyst-backend:latest
```

---

## 6. CI/CD Tasks (Phases 2–5)

> ⚠️ **These phases require AWS credentials + GitHub URL. No resources will be created until credentials are provided.**

### Phase 2 — AWS ECR (Pending credentials)

**Repository:** `quralyst-backend-dev`

AWS CLI commands to run once credentials are provided:

```bash
# Create ECR repository with immutable tags
aws ecr create-repository \
    --repository-name quralyst-backend-dev \
    --image-tag-mutability IMMUTABLE \
    --region <REGION>

# Apply lifecycle policy (keep latest 2 images)
aws ecr put-lifecycle-policy \
    --repository-name quralyst-backend-dev \
    --lifecycle-policy-text '{
      "rules": [{
        "rulePriority": 1,
        "description": "Keep only the 2 most recent images",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 2
        },
        "action": { "type": "expire" }
      }]
    }' \
    --region <REGION>
```

### Phase 3 — AWS CodeBuild (Pending credentials)

**File:** `buildspec.yml` (already created in repo)

CodeBuild project configuration:
- Source: GitHub (`quralyst-fastapi-backend`, `master` branch)
- Environment: `aws/codebuild/standard:7.0`, privileged mode (required for Docker)
- Environment variables:
  - `AWS_ACCOUNT_ID` — your 12-digit account ID
  - `ECR_REPOSITORY_NAME` — `quralyst-backend-dev`
- Service role: Must include `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`

### Phase 4 — AWS CodeDeploy (Pending credentials)

**Files:** `appspec.yml`, `scripts/stop_container.sh`, `scripts/start_container.sh`, `scripts/validate_service.sh`

CodeDeploy configuration:
- Application name: `quralyst-backend-dev`
- Deployment group: `quralyst-backend-dev-dg`
- Target EC2 tag: match the development EC2 instance
- Deployment type: `IN_PLACE`
- Auto-rollback: enabled on `DEPLOYMENT_FAILURE`
- EC2 prerequisite: `.env` placed at `/home/ubuntu/quralyst-backend/.env`

### Phase 5 — AWS CodePipeline (Pending credentials)

Pipeline name: `quralyst-backend-dev-pipeline`

| Stage   | Provider       | Action |
|--------|---------------|--------|
| Source  | GitHub (v2)   | Watch `master` branch of `quralyst-fastapi-backend` |
| Build   | CodeBuild     | Run `buildspec.yml` → push to ECR |
| Deploy  | CodeDeploy    | Run `appspec.yml` lifecycle on EC2 |

---

## 7. Completed Tasks

### ✅ TASK-001 — Local Environment Setup

| Field          | Value |
|---------------|-------|
| Date          | Pre-2026-06-16 |
| Branch        | `master` (initial commit) |
| Description   | venv created, deps installed, `.env` configured, MongoDB verified, FastAPI starts. |
| Commit        | `ddd4b4f` |

---

### ✅ TASK-002 — Phase 1: Docker Setup

| Field          | Value |
|---------------|-------|
| Date          | 2026-06-16 |
| Branch        | `feature/docker-setup` |
| PR            | Targeting `master` — awaiting approval |

**Files Created:**

| File                        | Description |
|----------------------------|-------------|
| `Dockerfile`               | Single-stage, python:3.12-slim, non-root appuser, healthcheck |
| `.dockerignore`            | Excludes .venv, .env, caches, IDE files from build context |
| `docker-compose.yml`       | Backend + Redis with health checks and resource limits |
| `.env.example`             | Safe credential template (committed) |
| `buildspec.yml`            | CodeBuild spec — build, tag (:latest + :sha), push to ECR |
| `appspec.yml`              | CodeDeploy manifest with 3 lifecycle hooks |
| `scripts/stop_container.sh`| CodeDeploy BeforeInstall — stops existing container |
| `scripts/start_container.sh`| CodeDeploy AfterInstall — pulls from ECR, starts compose |
| `scripts/validate_service.sh`| CodeDeploy ValidateService — polls health endpoints |
| `task.md`                  | This file |

See [Section 10](#10-validation-reports) for validation results.

---

## 8. Pending Tasks

| ID       | Task                                    | Blocked by       | Status |
|---------|----------------------------------------|-----------------|--------|
| TASK-003 | Docker build validation (local)        | User sudo/docker | 🟡 Manual step required |
| TASK-004 | Phase 2 — Create ECR repository        | AWS credentials  | 🔲 Awaiting credentials |
| TASK-005 | Phase 3 — Create CodeBuild project     | AWS credentials  | 🔲 Awaiting credentials |
| TASK-006 | Phase 4 — Create CodeDeploy app + group | AWS credentials | 🔲 Awaiting credentials |
| TASK-007 | Phase 5 — Create CodePipeline          | AWS credentials  | 🔲 Awaiting credentials |
| TASK-008 | EC2 — Place production .env on server  | PEM key          | 🔲 Awaiting PEM key |
| TASK-009 | Nginx — Add backend reverse proxy block | TASK-007 done   | 🔲 Pending |
| TASK-010 | SSL — Certbot for dev.api.quralyst.ai  | TASK-009 done   | 🔲 Pending |

---

## 9. Files Changed Log

| Task      | File                          | Action  |
|----------|-------------------------------|---------|
| TASK-002  | `Dockerfile`                 | Created |
| TASK-002  | `.dockerignore`              | Created |
| TASK-002  | `docker-compose.yml`         | Created |
| TASK-002  | `.env.example`               | Created |
| TASK-002  | `buildspec.yml`              | Created |
| TASK-002  | `appspec.yml`                | Created |
| TASK-002  | `scripts/stop_container.sh`  | Created |
| TASK-002  | `scripts/start_container.sh` | Created |
| TASK-002  | `scripts/validate_service.sh`| Created |
| TASK-002  | `task.md`                    | Created |

---

## 10. Validation Reports

### TASK-002 — Phase 1 Docker Validation

#### Docker Build

```bash
docker build -t quralyst-backend:latest .
```

> ⚠️ **Manual validation required.** The current `neo` user is not yet in the `docker` group on this machine.
>
> Run the following commands in your terminal to add the user and then build:
> ```bash
> sudo usermod -aG docker neo
> # Re-login or open a new terminal, then:
> docker build -t quralyst-backend:latest .
> docker image ls quralyst-backend:latest
> ```

Expected image size: < 500 MB (python:3.12-slim ≈ 160 MB + deps ≈ 200 MB → ~360 MB total).

#### Docker Run Validation

```bash
# Start full stack
docker compose up --build -d

# Verify health endpoints
curl http://localhost:8000/health/live
# Expected: {"status":"healthy","timestamp":"..."}

curl http://localhost:8000/health/ready
# Expected: {"status":"healthy","mongodb":"connected","timestamp":"..."}
```

#### Issues Encountered

| Issue | Resolution |
|-------|-----------|
| `neo` user not in `docker` group | Run `sudo usermod -aG docker neo` then re-login |

#### Recommendations

- Place production `.env` at `/home/ubuntu/quralyst-backend/.env` on EC2 before first CodeDeploy run.
- Consider AWS Secrets Manager for long-term secret management (Phase 2+).
- Pin Redis to a specific patch version (e.g., `redis:7.2-alpine`) for reproducibility.
- Enable Docker BuildKit (`DOCKER_BUILDKIT=1`) for faster builds in CodeBuild.

---

## 11. Future Roadmap

| Phase | Task | Notes |
|-------|------|-------|
| 2 | AWS ECR `quralyst-backend-dev` | Immutable tags, lifecycle policy (keep 2) |
| 3 | CodeBuild + buildspec.yml | Build on PR merge to master, push :latest + :sha to ECR |
| 4 | CodeDeploy + appspec.yml | stop → pull → start → validate → auto-rollback |
| 5 | CodePipeline | GitHub → CodeBuild → ECR → CodeDeploy |
| 6 | Nginx reverse proxy | `dev.api.quralyst.ai → localhost:8000` |
| 7 | SSL / HTTPS for API domain | Certbot or ACM |
| 8 | AWS Secrets Manager | Replace EC2 `.env` file with managed secrets |
| 9 | CloudWatch logging | Centralized log aggregation from container stdout |
| 10 | Auto Scaling | Scale beyond single EC2 if traffic grows |
