# Quralyst FastAPI Backend — Task & Architecture Reference

> **Single source of truth** for all infrastructure, development, and deployment work.
> Last updated: 2026-06-17

---

## Governance Rules

- Never work directly on `master`. Always feature branch → PR → review → merge.
- All completed tasks must be logged here immediately.
- No application logic changes — infrastructure only.
- Do NOT merge PRs without approval.
- CI/CD triggers on `master` branch only.

---

## Project Overview

| Field     | Value                                                        |
| --------- | ------------------------------------------------------------ |
| Product   | Quralyst — AI-powered query intelligence platform            |
| Repo      | `quralyst-fastapi-backend`                                   |
| GitHub    | https://github.com/Karan-parmar-007/quralyst-fastapi-backend |
| Language  | Python 3.12                                                  |
| Framework | FastAPI v0.136.3 + Uvicorn v0.49.0                           |
| Database  | MongoDB Atlas (external, async pymongo)                      |
| Cache     | Redis 7 (Docker sidecar)                                     |
| Auth      | JWT HS256 via itsdangerous                                   |

---

## Current Architecture

```
quralyst-fastapi-backend/
├── main.py
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── buildspec.yml          — CodeBuild: build + tag :sha + push to ECR
├── appspec.yml            — CodeDeploy: 3 lifecycle hooks
├── .env.example
├── task.md
├── scripts/
│   ├── stop_container.sh     — BeforeInstall
│   ├── start_container.sh    — AfterInstall (pulls ECR, starts compose)
│   └── validate_service.sh   — ValidateService (polls health, triggers rollback)
└── app/
    ├── config.py
    ├── api/
    │   ├── main_router.py
    │   ├── dependencies.py
    │   ├── db_dependencies.py
    │   ├── middlewares/csrf.py
    │   └── routes/health/
    │       ├── health_routes.py    GET /health/live, GET /health/ready
    │       ├── health_schemas.py
    │       └── health_service.py
    └── db/
        └── mongo_session.py
```

### API Endpoints

| Method | Path            | Description                        |
| ------ | --------------- | ---------------------------------- |
| GET    | `/health/live`  | Liveness probe — no external deps  |
| GET    | `/health/ready` | Readiness probe — verifies MongoDB |

---

## AWS Infrastructure

### Development EC2

| Property      | Value                                                      |
| ------------- | ---------------------------------------------------------- |
| Instance ID   | `i-06e3f585b2d4d1d4c`                                      |
| Instance Type | t3.large (2 vCPU / 8 GB RAM)                               |
| OS            | Ubuntu 24.04 LTS                                           |
| Public IP     | 54.176.182.122                                             |
| Key Pair      | Quralyst-Frontend-Dev                                      |
| Pre-installed | Docker, Docker Compose, Nginx, CodeDeploy Agent, SSM Agent |

### Nginx Domains

| Domain                | Target                                   |
| --------------------- | ---------------------------------------- |
| `dev.fe.quralyst.ai`  | Frontend (already live)                  |
| `dev.api.quralyst.ai` | Backend port 8000 (pending Nginx config) |

### Port Map

| Service  | Port     | Host Exposed       |
| -------- | -------- | ------------------ |
| Frontend | existing | 80/443             |
| Backend  | 8000     | 8000               |
| Redis    | 6379     | No (internal only) |

### Full CI/CD Architecture (deployed)

```
GitHub (Karan-parmar-007/quralyst-fastapi-backend)
  master branch push
    ↓
AWS CodePipeline: quralyst-backend-dev-pipeline
    ↓
AWS CodeBuild: quralyst-backend-dev-build
  docker build
  docker tag  :${COMMIT_SHA}
  docker push → ECR (IMMUTABLE tags)
    ↓
AWS ECR: quralyst-backend-dev
  Lifecycle: keep latest 2 tagged images, expire untagged after 1 day
    ↓
AWS CodeDeploy: quralyst-backend-dev → quralyst-backend-dev-dg
  BeforeInstall  → stop_container.sh
  AfterInstall   → start_container.sh (pulls from ECR, starts compose)
  ValidateService→ validate_service.sh (auto-rollback on failure)
    ↓
EC2 (i-06e3f585b2d4d1d4c)
  ├── quralyst-backend container  :8000
  └── quralyst-redis container    internal
    ↓
MongoDB Atlas (external)
```

---

## Docker Details

| Setting         | Value                                            |
| --------------- | ------------------------------------------------ |
| Base image      | python:3.12-slim                                 |
| Build strategy  | Single-stage                                     |
| Run as          | appuser (UID 1001, non-root)                     |
| Health check    | GET /health/live                                 |
| Uvicorn workers | 2                                                |
| Image size      | **276 MB** ✅ (target <500 MB)                   |
| ECR tag format  | `manual-YYYYMMDDHHMM` (CI: `${COMMIT_SHA[0:8]}`) |

---

## Environment Variables (EC2 .env location: `/home/ubuntu/quralyst-backend/.env`)

| Variable                                  | Required                    |
| ----------------------------------------- | --------------------------- |
| `MONGO_URI`                               | ✅                          |
| `MONGO_DB_NAME`                           | ✅                          |
| `SECRET_KEY`                              | ✅                          |
| `ALGORITHM`                               | ❌ default HS256            |
| `ACCESS_TOKEN_EXPIRE_MINUTES`             | ❌ default 30               |
| `REFRESH_TOKEN_EXPIRE_DAYS`               | ❌ default 7                |
| `RESET_PASSWORD_TOKEN_EXPIRE_MINUTES`     | ❌ default 15               |
| `FORGET_PASSWORD_TOKEN_EXPIRE_MINUTES`    | ❌ default 15               |
| `EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES` | ❌ default 15               |
| `CSRF_SECRET_KEY`                         | ❌ falls back to SECRET_KEY |

---

## Completed Tasks

---

### ✅ TASK-001 — Local Environment Setup

| Field       | Value                                                      |
| ----------- | ---------------------------------------------------------- |
| Date        | Pre-2026-06-16                                             |
| Branch      | master (initial commit)                                    |
| Commit      | `ddd4b4f`                                                  |
| Description | venv, deps, .env, MongoDB verified, FastAPI starts locally |

---

### ✅ TASK-002 — Phase 1: Docker Files Created

| Field  | Value                                 |
| ------ | ------------------------------------- |
| Date   | 2026-06-16                            |
| Branch | `feature/docker-setup`                |
| Commit | `03dc065`                             |
| PR     | Targeting master — awaiting push auth |

**Files Created:**

| File                          | Purpose                                            |
| ----------------------------- | -------------------------------------------------- |
| `Dockerfile`                  | python:3.12-slim, non-root appuser, HEALTHCHECK    |
| `.dockerignore`               | Excludes .venv, .env, caches, IDE files            |
| `docker-compose.yml`          | Backend + Redis, internal network, resource limits |
| `.env.example`                | Safe credential template                           |
| `buildspec.yml`               | CodeBuild: build + tag :sha + push to ECR          |
| `appspec.yml`                 | CodeDeploy: 3-hook lifecycle manifest              |
| `scripts/stop_container.sh`   | BeforeInstall hook                                 |
| `scripts/start_container.sh`  | AfterInstall hook                                  |
| `scripts/validate_service.sh` | ValidateService hook                               |
| `task.md`                     | This file                                          |

**Issues:**

- `neo` user not in docker group on local machine → built on EC2 instead
- Git push blocked: local credential `Girish7010` lacks push access to `Karan-parmar-007` repo

---

### ✅ TASK-003 — Phase 2: ECR Repository Created

| Field        | Value                  |
| ------------ | ---------------------- |
| Date         | 2026-06-16             |
| Branch       | `feature/docker-setup` |
| AWS Resource | `quralyst-backend-dev` |

**ECR Details:**

| Setting              | Value                                                               |
| -------------------- | ------------------------------------------------------------------- |
| Repository Name      | `quralyst-backend-dev`                                              |
| Repository URI       | `438465146066.dkr.ecr.us-west-1.amazonaws.com/quralyst-backend-dev` |
| Region               | us-west-1                                                           |
| Image Tag Mutability | **IMMUTABLE**                                                       |
| Scan on Push         | Enabled                                                             |
| Encryption           | AES256                                                              |

**Lifecycle Policy:**

- Rule 1: Keep only the 2 most recent tagged images (expire older)
- Rule 2: Expire untagged images after 1 day

**Note on IMMUTABLE + buildspec:** With IMMUTABLE tags, `:latest` cannot be pushed repeatedly. `buildspec.yml` pushes only the commit SHA tag. `start_container.sh` re-tags the pulled image locally as `quralyst-backend:latest` for docker compose.

**Validation:**

- ECR repository exists and is IMMUTABLE ✅
- Lifecycle policy applied ✅
- First image pushed: `manual-202606161459` ✅

---

### ✅ TASK-004 — Phase 3: CodeBuild Project Created

| Field        | Value                        |
| ------------ | ---------------------------- |
| Date         | 2026-06-16                   |
| Branch       | `feature/docker-setup`       |
| AWS Resource | `quralyst-backend-dev-build` |

**CodeBuild Details:**

| Setting           | Value                                                                           |
| ----------------- | ------------------------------------------------------------------------------- |
| Project Name      | `quralyst-backend-dev-build`                                                    |
| ARN               | `arn:aws:codebuild:us-west-1:438465146066:project/quralyst-backend-dev-build`   |
| Source            | CODEPIPELINE (reads buildspec.yml from source artifact)                         |
| Environment Image | `aws/codebuild/standard:7.0`                                                    |
| Compute           | BUILD_GENERAL1_SMALL                                                            |
| Privileged Mode   | **true** (required for Docker-in-Docker)                                        |
| Service Role      | `arn:aws:iam::438465146066:role/CodeBuildServiceRole`                           |
| Timeout           | 30 minutes                                                                      |
| Cache             | S3: `quralyst-dev-codepipeline-artifacts-1772534128/cache/quralyst-backend-dev` |

**Environment Variables:**

| Variable              | Value                |
| --------------------- | -------------------- |
| `AWS_ACCOUNT_ID`      | 438465146066         |
| `ECR_REPOSITORY_NAME` | quralyst-backend-dev |
| `AWS_DEFAULT_REGION`  | us-west-1            |

**Validation:** Project created and verified ✅

---

### ✅ TASK-005 — Phase 4: CodeDeploy Created

| Field         | Value                  |
| ------------- | ---------------------- |
| Date          | 2026-06-16             |
| Branch        | `feature/docker-setup` |
| AWS Resources | App + Deployment Group |

**CodeDeploy Details:**

| Setting             | Value                                                  |
| ------------------- | ------------------------------------------------------ |
| Application Name    | `quralyst-backend-dev`                                 |
| Application ID      | `647f8105-c6d4-466e-99e1-cf67647890e4`                 |
| Deployment Group    | `quralyst-backend-dev-dg`                              |
| Deployment Group ID | `6a3696cd-8706-491c-af27-e54e025a224a`                 |
| Deployment Config   | `CodeDeployDefault.OneAtATime`                         |
| Deployment Type     | `IN_PLACE`                                             |
| Target EC2 Tag      | `Name=Quralyst-Frontend-Dev`                           |
| Service Role        | `arn:aws:iam::438465146066:role/CodeDeployServiceRole` |
| Auto-rollback       | Enabled on `DEPLOYMENT_FAILURE`                        |

**Deployment Scripts:**

| Hook            | Script                | Action                                                  |
| --------------- | --------------------- | ------------------------------------------------------- |
| BeforeInstall   | `stop_container.sh`   | Stops existing backend container                        |
| AfterInstall    | `start_container.sh`  | Pulls from ECR, starts docker compose                   |
| ValidateService | `validate_service.sh` | Polls /health/live + /health/ready, exits 1 to rollback |

**Validation:** Application and deployment group created ✅

---

### ✅ TASK-006 — Docker Build, ECR Push & EC2 Deployment

| Field       | Value                                      |
| ----------- | ------------------------------------------ |
| Date        | 2026-06-16                                 |
| Branch      | `feature/docker-setup`                     |
| Deployed to | EC2 `i-06e3f585b2d4d1d4c` (54.176.182.122) |

**Docker Build (on EC2):**

| Check         | Result                         |
| ------------- | ------------------------------ |
| Build success | ✅                             |
| Image size    | **276 MB** ✅ (target <500 MB) |
| Image tag     | `manual-202606161459`          |
| ECR push      | ✅                             |
| Non-root user | ✅ appuser UID 1001            |

**Container Deployment:**

| Check                                | Result     |
| ------------------------------------ | ---------- |
| `stop_container.sh` executed         | ✅         |
| `start_container.sh` executed        | ✅         |
| `quralyst-backend` container running | ✅ healthy |
| `quralyst-redis` container running   | ✅ healthy |
| Backend port 8000 exposed            | ✅         |

**Health Validation:**

| Check                 | Response                                                       | Result |
| --------------------- | -------------------------------------------------------------- | ------ |
| `GET /health/live`    | `{"status":"healthy","timestamp":"..."}`                       | ✅ 200 |
| `GET /health/ready`   | `{"status":"healthy","mongodb":"connected","timestamp":"..."}` | ✅ 200 |
| MongoDB connection    | connected                                                      | ✅     |
| `validate_service.sh` | Deployment validated successfully                              | ✅     |

**Container Logs:**

```
Uvicorn running on http://0.0.0.0:8000
Started parent process [7]
Started server process [9] — Application startup complete
Started server process [10] — Application startup complete
```

---

### ✅ TASK-007 — Phase 5: CodePipeline Created

| Field        | Value                           |
| ------------ | ------------------------------- |
| Date         | 2026-06-16                      |
| Branch       | `feature/docker-setup`          |
| AWS Resource | `quralyst-backend-dev-pipeline` |

**Pipeline Details:**

| Setting        | Value                                                                       |
| -------------- | --------------------------------------------------------------------------- |
| Pipeline Name  | `quralyst-backend-dev-pipeline`                                             |
| Pipeline ARN   | `arn:aws:codepipeline:us-west-1:438465146066:quralyst-backend-dev-pipeline` |
| Pipeline Type  | V2                                                                          |
| Execution Mode | SUPERSEDED                                                                  |
| Artifacts S3   | `quralyst-dev-codepipeline-artifacts-1772534128`                            |
| Service Role   | `arn:aws:iam::438465146066:role/AWSCodePipelineServiceRole`                 |

**Stages:**

| Stage  | Provider                 | Configuration                                                |
| ------ | ------------------------ | ------------------------------------------------------------ |
| Source | CodeStarSourceConnection | `Karan-parmar-007/quralyst-fastapi-backend`, branch `master` |
| Build  | CodeBuild                | `quralyst-backend-dev-build`                                 |
| Deploy | CodeDeploy               | App `quralyst-backend-dev`, Group `quralyst-backend-dev-dg`  |

**Trigger:** Push to `master` branch only ✅
**GitHub Connection:** `indago-research` (`cd2ba111-5db9-48d7-8339-ed97c6fd470b`) ✅

**Validation:** Pipeline created ✅

---

---

### ✅ TASK-008 — Pipeline Source Inspection (2026-06-17)

| Field       | Value                                                          |
| ----------- | -------------------------------------------------------------- |
| Date        | 2026-06-17                                                     |
| Branch      | `feature/docker-setup` (local, not yet pushed)                 |
| Objective   | Verify pipeline source repository and fix if incorrect         |

**Pipeline Inspection Results:**

| Field                    | Configured Value                                                              |
| ------------------------ | ----------------------------------------------------------------------------- |
| Pipeline Name            | `quralyst-backend-dev-pipeline`                                               |
| Source Repository        | `Karan-parmar-007/quralyst-fastapi-backend` ✅ **CORRECT**                    |
| Source Branch            | `master` ✅ **CORRECT**                                                       |
| GitHub Connection        | `cd2ba111-5db9-48d7-8339-ed97c6fd470b` (indago-research) ✅                   |
| CodeBuild Project        | `quralyst-backend-dev-build` ✅                                                |
| CodeDeploy Application   | `quralyst-backend-dev` ✅                                                     |
| Deployment Group         | `quralyst-backend-dev-dg` ✅                                                  |
| Artifact S3 Bucket       | `quralyst-dev-codepipeline-artifacts-1772534128` ✅                           |
| ECR Repository           | `438465146066.dkr.ecr.us-west-1.amazonaws.com/quralyst-backend-dev` ✅        |

**Root Cause Identified:**

The pipeline Source stage was already correctly configured. The pipeline DID trigger on commit `ddd4b4f` (the initial commit already on GitHub `master`). However the Build stage **FAILED** with:

```
Phase: DOWNLOAD_SOURCE, Code: YAML_FILE_ERROR
Message: stat /codebuild/output/src.../buildspec.yml: no such file or directory
```

**Reason:** All CI/CD files (`buildspec.yml`, `appspec.yml`, `Dockerfile`, `docker-compose.yml`, `scripts/`) were created on the local `feature/docker-setup` branch but **never pushed to GitHub**. The remote `master` only contains the initial commit (`ddd4b4f`) — the application code without any infrastructure files.

**Fix Required:** Push `feature/docker-setup` to GitHub → open PR → merge to `master` → pipeline auto-triggers with correct files.

**No pipeline source change is needed** — repository and branch are already correct.

**AWS Resources — No Changes Required:**

| Resource          | Status             | Reason                                 |
| ----------------- | ------------------ | -------------------------------------- |
| ECR Repository    | ✅ Reused as-is    | Already exists and configured          |
| CodeBuild Project | ✅ Reused as-is    | Already exists and configured          |
| CodeDeploy App    | ✅ Reused as-is    | Already exists and configured          |
| Deployment Group  | ✅ Reused as-is    | Already exists and configured          |
| CodePipeline      | ✅ Reused as-is    | Source already points to correct repo  |
| EC2 Instance      | ✅ Reused as-is    | Backend containers already running     |

---

### COMPLETED TASK-009 — Fix buildspec YAML + Permanent .env Path (2026-06-17)

| Field     | Value                                              |
| --------- | -------------------------------------------------- |
| Date      | 2026-06-17                                         |
| Branch    | `feature/fix-buildspec-yaml`                       |
| PR        | #2 (to master)                                     |
| Objective | Fix CodeBuild YAML_FILE_ERROR + permanent .env     |

**Changes in this PR:**

**1. buildspec.yml — complete rewrite (pure ASCII)**

| Problem | Fix |
| ------- | --- |
| Unicode em-dash chars in comments | Removed all comments from buildspec |
| Inline `#` comments inside `commands:` block | Commands block is comment-free |
| Bare `>` redirect operator (`printf ... > file`) | Replaced with `printf ... \| tee file` |
| Unquoted `$IMAGE_URI:$COMMIT_SHA` | Quoted: `"$IMAGE_URI:$COMMIT_SHA"` |

Validation: `yaml.safe_load()` passes, all bytes ASCII ✅

**2. scripts/start_container.sh — permanent ENV_FILE path**

| Before | After |
| ------ | ----- |
| `ENV_FILE="/home/ubuntu/quralyst-backend/.env"` | `ENV_FILE="/opt/quralyst-backend/.env"` |

Reason: `/home/ubuntu/quralyst-backend/` is managed by CodeDeploy and can be overwritten on each deployment. `/opt/quralyst-backend/.env` is outside the deployment directory and persists across all future deployments.

**3. task.md — updated with full audit findings**

**EC2 .env bootstrap (one-time manual step via SSM):**

```
Path:  /opt/quralyst-backend/.env
Owner: ubuntu:ubuntu
Mode:  600 (owner read/write only)
```

The `.env` is created on EC2 once via SSM run-command. All future CodeDeploy deployments reuse it at `/opt/quralyst-backend/.env` without touching it.

**Auto-trigger confirmation:**

The pipeline auto-trigger IS working correctly. PR #1 merge triggered the pipeline automatically (Source stage Succeeded, commit `26d394`). The Build stage was the only failure due to the buildspec YAML error — not a trigger configuration issue.

---

## Pending Tasks

| ID       | Task                                                       | Blocked by | Status     |
| -------- | ---------------------------------------------------------- | ---------- | ---------- |
| TASK-010 | Nginx reverse proxy `dev.api.quralyst.ai -> :8000`         | Approval   | Pending    |
| TASK-011 | SSL/HTTPS for `dev.api.quralyst.ai`                        | TASK-010   | Pending    |

---

## Files Changed Log

| Task     | File                          | Action                                                          |
| -------- | ----------------------------- | --------------------------------------------------------------- |
| TASK-002 | `Dockerfile`                  | Created                                                         |
| TASK-002 | `.dockerignore`               | Created                                                         |
| TASK-002 | `docker-compose.yml`          | Created                                                         |
| TASK-002 | `.env.example`                | Created                                                         |
| TASK-002 | `buildspec.yml`               | Created                                                         |
| TASK-002 | `appspec.yml`                 | Created                                                         |
| TASK-002 | `scripts/stop_container.sh`   | Created                                                         |
| TASK-002 | `scripts/start_container.sh`  | Created                                                         |
| TASK-002 | `scripts/validate_service.sh` | Created                                                         |
| TASK-002 | `task.md`                     | Created                                                         |
| TASK-002 | `.gitignore`                  | Modified (added !task.md, !.env.example exceptions)             |
| TASK-003 | `buildspec.yml`               | Modified (removed :latest ECR push for IMMUTABLE compatibility) |
| TASK-008 | `task.md`                          | Updated with pipeline inspection findings (2026-06-17)             |
| TASK-009 | `buildspec.yml`                    | Rewritten: pure ASCII, no comments, tee instead of `>`             |
| TASK-009 | `scripts/start_container.sh`       | ENV_FILE path changed to `/opt/quralyst-backend/.env` (permanent)  |
| TASK-009 | `task.md`                          | Updated with TASK-009 completion details                           |

---

## AWS Resources (Summary — All Reused, None Recreated)

| Resource          | Name                            | ARN / URI                                                                     |
| ----------------- | ------------------------------- | ----------------------------------------------------------------------------- |
| ECR Repository    | `quralyst-backend-dev`          | `438465146066.dkr.ecr.us-west-1.amazonaws.com/quralyst-backend-dev`           |
| CodeBuild Project | `quralyst-backend-dev-build`    | `arn:aws:codebuild:us-west-1:438465146066:project/quralyst-backend-dev-build` |
| CodeDeploy App    | `quralyst-backend-dev`          | ID: `647f8105-c6d4-466e-99e1-cf67647890e4`                                    |
| CodeDeploy Group  | `quralyst-backend-dev-dg`       | ID: `6a3696cd-8706-491c-af27-e54e025a224a`                                    |
| CodePipeline      | `quralyst-backend-dev-pipeline` | `arn:aws:codepipeline:us-west-1:438465146066:quralyst-backend-dev-pipeline`   |
| S3 Artifact Bucket| `quralyst-dev-codepipeline-artifacts-1772534128` | (existing)                                              |
| EC2 Instance      | `i-06e3f585b2d4d1d4c`          | 54.176.182.122 (t3.large, Ubuntu 24.04)                                       |

---

## Future Roadmap

| Task     | Description                                                   |
| -------- | ------------------------------------------------------------- |
| TASK-010 | Merge feature branch → trigger pipeline → validate end-to-end |
| TASK-011 | Nginx `dev.api.quralyst.ai` reverse proxy block               |
| TASK-012 | Certbot SSL for `dev.api.quralyst.ai`                         |
| TASK-013 | AWS Secrets Manager (replace .env on EC2)                     |
| TASK-014 | CloudWatch log groups for container stdout                    |
| TASK-015 | Rollback validation test                                      |
# Auto-trigger validation test - Wed Jun 17 11:25:23 AM IST 2026
