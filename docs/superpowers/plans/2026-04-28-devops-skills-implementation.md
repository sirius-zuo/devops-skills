# DevOps Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build 5 Claude Code skills (`devops`, `devops-analyze`, `devops-security`, `devops-generate`, `devops-report`) that establish DevOps setup, CI/CD pipelines, security review, and an HTML deployment report for any project across three scenarios: design-stage, code-complete, and DevOps-review.

**Architecture:** One entry dispatcher skill (`devops`) detects the scenario and calls four sub-skills sequentially. All skills stored in `~/.claude/skills/`. No skill invokes another directly — only the dispatcher calls sub-skills. Security runs before generation so security tool choices are baked into generated CI configs.

**Tech Stack:** Claude Code skill format (SKILL.md with YAML frontmatter), Graphviz DOT for diagram definitions, inline SVG for report diagrams, shell templates for CI/CD (GitHub Actions YAML, GitLab CI YAML, CircleCI YAML), Dockerfile, docker-compose, Terraform HCL.

---

## File Structure

```
~/.claude/skills/
├── devops/
│   └── SKILL.md                    ← entry dispatcher
├── devops-analyze/
│   └── SKILL.md                    ← codebase analysis + guided questions
├── devops-security/
│   └── SKILL.md                    ← security checklist + CI tool selection
├── devops-generate/
│   └── SKILL.md                    ← config file generation
└── devops-report/
    └── SKILL.md                    ← HTML report + embedded SVG diagrams

Output written to project root (at runtime):
devops/
├── working/
│   ├── analysis.json
│   ├── security-findings.json
│   ├── ci/
│   │   ├── github-actions/
│   │   ├── gitlab-ci/
│   │   └── circleci/
│   ├── containers/
│   ├── compose/
│   ├── k8s/                        ← conditional on deployment target
│   ├── infra/                      ← conditional on cloud selection
│   ├── devcontainer/
│   └── scripts/
└── report/
    └── index.html
```

---

## Task 1: `devops` — Entry Dispatcher Skill

**Files:**
- Create: `~/.claude/skills/devops/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/.claude/skills/devops
```

- [ ] **Step 2: Write the dispatcher SKILL.md**

Write `~/.claude/skills/devops/SKILL.md` with this exact content:

```markdown
---
name: devops
description: Use when setting up DevOps workflows, CI/CD pipelines, deployment configuration, or reviewing existing DevOps setup for any project
---

# DevOps Setup

## Overview

Detects which of three scenarios applies, confirms with the user, then calls sub-skills in sequence to produce working config files and an HTML report.

## Scenario Detection

Scan the working directory before doing anything else:

| Signal | Scenario |
|---|---|
| Design/arch docs found, no source code | 1. Design-stage |
| Source code found, no `devops/` folder | 2. Code-complete |
| Source code + `devops/` folder both found | 3. DevOps-review |

**Design docs signals:** files named `*.md` containing architecture, ADR, design decision keywords; files in `docs/`, `design/`, `spec/` folders; no `.py`/`.ts`/`.go`/`.java`/`.rb`/`.rs` source files present.

**Source code signals:** presence of `.py`, `.ts`, `.js`, `.go`, `.java`, `.rb`, `.rs`, `.cs` files outside of `docs/`.

**DevOps folder signal:** `devops/` directory exists with at least one config file inside.

**If ambiguous** (source code + design docs, no devops/): ask — "I see both design docs and source code but no devops/ folder. Should I base recommendations on: (A) The design docs — Scenario 1, or (B) The existing codebase — Scenario 2?"

## Stack Detection

While scanning, note:
- Language: file extensions
- Framework: imports in source files (express, fastapi, gin, spring, rails, etc.)
- Database: ORM config files, connection strings, docker-compose services
- Cloud: SDK imports (boto3/aws-sdk → AWS; google-cloud → GCP; azure → Azure)
- CI/CD: presence of `.github/`, `.gitlab-ci.yml`, `.circleci/`
- Containers: Dockerfile, docker-compose.yml, `k8s/` directory

## Announcement & Confirmation

Before calling any sub-skill, announce to the user:

```
Detected scenario: [1. Design-stage | 2. Code-complete | 3. DevOps-review]
Detected stack: [language] + [framework] | DB: [database] | Cloud: [cloud or "none detected"]

I will now:
1. Analyze the project and ask a few targeted questions → devops/working/analysis.json
2. Run a security review → devops/working/security-findings.json
3. Generate config files → devops/working/
4. Produce an HTML report → devops/report/index.html

Proceed? (yes/no)
```

Wait for confirmation before proceeding.

## Pipeline

Call these sub-skills in order. Pass the scenario and detected stack as context to each.

1. Invoke `devops-analyze`
2. Invoke `devops-security`
3. Invoke `devops-generate`
4. Invoke `devops-report`

## Context Object

Track this throughout the session — each sub-skill reads from it:

```json
{
  "scenario": "design | codebase | review",
  "detected_stack": {
    "language": "",
    "framework": "",
    "database": [],
    "existing_infra": ""
  },
  "source": {
    "design_docs": [],
    "source_files": [],
    "existing_devops_files": []
  }
}
```

## Output Locations

- Config files: `devops/working/` (relative to project root)
- HTML report: `devops/report/index.html`
- Create both directories if they don't exist.
```

- [ ] **Step 3: Run baseline pressure scenario**

Dispatch a subagent with this prompt to document behavior WITHOUT the skill:

> "You are in a project directory that has a `src/` folder with TypeScript files and a `docs/architecture.md` file. There is no `devops/` folder. The user types: 'Please set up my DevOps for this project.' What do you do? Walk me through your exact actions."

Document what the subagent does naturally without the skill. Expected baseline failure: subagent likely dives straight into generating files without scenario detection, confirmation, or sub-skill sequencing.

- [ ] **Step 4: Verify the skill changes behavior**

Re-run the same scenario WITH the skill loaded. Verify the agent:
- Detects scenario (Code-complete, since source + no devops/ folder)
- Announces detected scenario and stack
- Confirms with user before proceeding
- Calls `devops-analyze` first (not generating configs directly)

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills
git add devops/SKILL.md
git commit -m "feat: add devops entry dispatcher skill"
```

---

## Task 2: `devops-analyze` — Analysis & Guided Questions Skill

**Files:**
- Create: `~/.claude/skills/devops-analyze/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/.claude/skills/devops-analyze
```

- [ ] **Step 2: Write the devops-analyze SKILL.md**

Write `~/.claude/skills/devops-analyze/SKILL.md` with this exact content:

```markdown
---
name: devops-analyze
description: Use when called by the devops dispatcher to analyze a project and gather DevOps configuration choices through guided questions before generating configs
---

# DevOps Analysis & Guided Questions

## Overview

Reads project sources, detects the tech stack, then asks 6 guided questions with smart defaults. Produces `devops/working/analysis.json` consumed by all downstream sub-skills.

## What to Read Per Scenario

| Scenario | Read These |
|---|---|
| design | All `.md` files in `docs/`, `design/`, `spec/`; ADRs; any `package.json`, `requirements.txt`, `go.mod`, `pom.xml` for dependency hints |
| codebase | Source file extensions for language; import statements for framework; ORM config files (`database.yml`, `alembic.ini`, `prisma/schema.prisma`); `.env.example`; existing `Dockerfile` or `docker-compose.yml` if present |
| review | Everything above + `.github/workflows/*.yml`; `.gitlab-ci.yml`; `.circleci/config.yml`; `terraform/` or `pulumi/` directories; existing `docker-compose*.yml` |

## Stack Detection Rules

Apply these when reading source files:

**Language detection** (by file extension):
- `.py` → Python
- `.ts` or `.tsx` → TypeScript
- `.js` or `.mjs` → JavaScript
- `.go` → Go
- `.java` → Java
- `.rb` → Ruby
- `.rs` → Rust
- `.cs` → C#

**Framework detection** (by imports/dependencies):
- `express` or `fastify` → Node.js web
- `react` or `next` → React/Next.js
- `fastapi` or `django` or `flask` → Python web
- `gin` or `echo` or `fiber` → Go web
- `spring` → Java Spring
- `rails` → Ruby on Rails

**Database detection** (by ORM/driver imports or compose services):
- `prisma`, `sequelize`, `typeorm` → PostgreSQL or MySQL (check schema)
- `sqlalchemy`, `django.db` → PostgreSQL or MySQL
- `mongoose` → MongoDB
- `redis` package → Redis

**Cloud detection** (by SDK imports):
- `boto3`, `@aws-sdk` → AWS
- `google-cloud`, `@google-cloud` → GCP
- `@azure` → Azure

**CI/CD detection** (by directory/file presence):
- `.github/workflows/` → GitHub Actions
- `.gitlab-ci.yml` → GitLab CI
- `.circleci/` → CircleCI

**Container/K8s detection**:
- `Dockerfile` present → Docker
- `k8s/` or `kubernetes/` directory → Kubernetes

## Guided Questions

Ask these one at a time, in order. Show the detected default in [brackets]. Wait for confirmation before the next question.

**Q1: Cloud provider**
> "Cloud provider [detected: X or 'none detected']: AWS / GCP / Azure / Multi-cloud / Self-hosted"

**Q2: CI/CD platform**
> "CI/CD platform [detected: X or 'GitHub Actions recommended']: GitHub Actions / GitLab CI / CircleCI"

**Q3: Deployment target**
> "Deployment target [detected: X or 'Containers recommended']: Containers (ECS/Cloud Run/ACA) / Kubernetes / Serverless (Lambda/Cloud Functions/Azure Functions) / VMs"

**Q4: Database and stateful services**
> "Confirmed stateful services [detected: postgres, redis or 'none detected']: (confirm list or add/remove)"

**Q5: Secrets management**
> "Secrets management [suggested based on cloud: AWS → Secrets Manager, GCP → Secret Manager, Azure → Key Vault, none → env files]: AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault / Azure Key Vault / env files (.env.local gitignored)"

**Q6: Team size**
> "Team size (affects pipeline complexity): Solo (<5 devs) / Small team (5-20 devs, daily deploys) / Large team (20+ devs, CI on every PR)"

## Output

After all 6 questions are answered, create `devops/working/analysis.json`:

```json
{
  "scenario": "design | codebase | review",
  "project_name": "detected from package.json or directory name",
  "stack": {
    "language": "TypeScript",
    "framework": "Express",
    "database": ["PostgreSQL", "Redis"],
    "external_services": []
  },
  "choices": {
    "cloud_provider": "AWS",
    "ci_cd_platform": "GitHub Actions",
    "deployment_target": "Containers",
    "secrets_management": "AWS Secrets Manager",
    "team_size": "Small team"
  },
  "detected": {
    "has_dockerfile": false,
    "has_k8s_manifests": false,
    "has_existing_ci": false,
    "has_existing_compose": false,
    "has_existing_devops_folder": false,
    "existing_ci_platform": null
  }
}
```

Write this file to `devops/working/analysis.json`. Create the directory if it doesn't exist.

Confirm to the user: "Analysis complete. Saved to devops/working/analysis.json. Moving to security review."
```

- [ ] **Step 3: Run baseline pressure scenario**

Dispatch a subagent with this prompt:

> "The user has a TypeScript Express project with PostgreSQL. The devops dispatcher has identified this as Scenario 2 (Code-complete). You need to gather the DevOps configuration choices from the user. Walk me through exactly what you do and what questions you ask."

Document: Does the agent ask all 6 questions? Does it offer detected defaults? Does it write analysis.json at the end?

- [ ] **Step 4: Verify skill compliance**

With skill loaded, verify:
- All 6 questions asked in order
- Each question shows a detected default
- `devops/working/analysis.json` written after answers collected
- Confirmation message given before handing back to dispatcher

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills
git add devops-analyze/SKILL.md
git commit -m "feat: add devops-analyze guided questions skill"
```

---

## Task 3: `devops-security` — Security Review & CI Tooling Skill

**Files:**
- Create: `~/.claude/skills/devops-security/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/.claude/skills/devops-security
```

- [ ] **Step 2: Write the devops-security SKILL.md**

Write `~/.claude/skills/devops-security/SKILL.md` with this exact content:

```markdown
---
name: devops-security
description: Use when called by the devops dispatcher after analysis to audit security posture and select CI security tooling before config generation
---

# DevOps Security Review

## Overview

Runs a security checklist audit and selects appropriate CI security tools. Produces `devops/working/security-findings.json` and security tool configs in `devops/working/ci/security/`. Runs BEFORE `devops-generate` so security tool choices are baked into CI configs.

## Inputs

Read `devops/working/analysis.json` before starting. Use `scenario`, `stack`, `choices`, and `detected` fields throughout this skill.

## Security Checklist

Evaluate each item. For codebase and review scenarios, actively read source files and existing configs to check. For design scenario, note items as "cannot verify — recommend at implementation".

Rate each finding: **Critical** / **High** / **Medium** / **Low**. If the item passes, do not include it in findings.

### Category 1: Secrets & Credentials

- [ ] No hardcoded secrets in source files (grep for patterns: `API_KEY`, `SECRET`, `PASSWORD`, `TOKEN`, `PRIVATE_KEY`, `aws_access_key`, `api_key =`)
- [ ] `.env` files are listed in `.gitignore`
- [ ] CI/CD YAML files do not echo secret values in `run:` steps
- [ ] Secrets referenced by environment variable name, not literal value, in configs

**Severity guide:** Hardcoded secret in source = Critical. .env not gitignored = High. Secret echoed in CI = High.

### Category 2: Container Security

Only if `detected.has_dockerfile` is true — check existing Dockerfile. Otherwise note as "recommend at implementation".

- [ ] App process does not run as root (Dockerfile has `USER` instruction before `CMD`)
- [ ] Base image uses a specific version tag, not `latest`
- [ ] Multi-stage build used to exclude dev dependencies from production image
- [ ] Only necessary ports are `EXPOSE`d
- [ ] Base image is official (from Docker Hub official or distroless)

**Severity guide:** Running as root = High. `latest` tag = Medium. No multi-stage build = Medium.

### Category 3: Network Exposure

For design scenario, flag as recommendations. For codebase, check framework config:

- [ ] API endpoints that modify data require authentication middleware
- [ ] Rate limiting configured (check for express-rate-limit, django-ratelimit, etc.)
- [ ] CORS policy is restrictive — not `origin: '*'` in production config
- [ ] HTTPS enforced (HTTP requests redirect to HTTPS)

**Severity guide:** No auth on data-modifying endpoints = Critical. Wildcard CORS in prod = High.

### Category 4: Dependencies

- [ ] Lockfile present (`package-lock.json`, `yarn.lock`, `poetry.lock`, `go.sum`, `Gemfile.lock`, `Cargo.lock`)
- [ ] No obviously outdated major versions in direct dependencies (check package.json/requirements.txt dates)
- [ ] Dockerfile RUN installs pin package versions (not `pip install requests` without `==version`)

**Severity guide:** No lockfile = High. Unpinned Dockerfile installs = Medium.

### Category 5: CI/CD Pipeline

Only for review scenario with existing CI configs. For others, note as "will be configured in generated pipeline".

- [ ] Main/production branch is protected (requires PR review)
- [ ] Production deployments require manual approval gate
- [ ] Docker images are tagged with commit SHA, not `latest`
- [ ] No secrets stored as plain text in CI YAML

**Severity guide:** No prod approval gate = High. Secrets in CI YAML = Critical.

### Category 6: Cloud IAM

Only if cloud provider is AWS/GCP/Azure. Check existing infra-as-code if present.

- [ ] Service accounts/roles use least-privilege (no `*` wildcard permissions)
- [ ] CI/CD runner role has only the permissions needed to deploy
- [ ] Storage buckets/blobs are not publicly accessible by default
- [ ] No long-lived access keys committed to repository

**Severity guide:** Wildcard IAM permissions = High. Public storage = High. Committed keys = Critical.

### Category 7: OWASP Top 10 (framework-specific)

Apply based on detected framework:

- **Injection:** ORM or parameterized queries used? (no string-concatenated SQL)
- **Authentication:** Session expiry configured? Passwords hashed (bcrypt/argon2)?
- **Security Misconfiguration:** Debug mode disabled in prod? Detailed error messages not exposed to clients?
- **Vulnerable Components:** See Dependencies category above.

**Severity guide:** SQL injection risk = Critical. Debug in prod = High.

### Category 8: Secrets Management

- [ ] Production secrets stored in secrets manager (not `.env` files committed to repo)
- [ ] Dev secrets in `.env.local` (gitignored), not `.env` (which may be committed)
- [ ] Secret rotation policy exists or is recommended

**Severity guide:** Production secrets in committed env file = Critical. No rotation = Low.

## Security Tool Selection

Select tools based on `analysis.json`.choices.ci_cd_platform:

| Tool | When to Include |
|---|---|
| **Trivy** | Always — container + dependency CVE scanning |
| **Semgrep** | Always — open source SAST, no account required |
| **CodeQL** | Include if GitHub Actions selected |
| **Dependabot** | Include if GitHub Actions selected |
| **Snyk** | Include if GitLab CI or CircleCI selected (as alternative to Dependabot) |
| **Gitleaks** | Always — secrets detection in git history and CI |
| **OWASP ZAP** | Include if deployment target is Containers or Kubernetes |

## Output

### 1. Write security-findings.json

Create `devops/working/security-findings.json`:

```json
{
  "summary": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "findings": [
    {
      "category": "Secrets & Credentials",
      "severity": "Critical",
      "finding": "Specific description of what was found",
      "remediation": "Specific fix: e.g., move API_KEY to .env.local and add to .gitignore"
    }
  ],
  "selected_tools": ["trivy", "semgrep", "gitleaks", "owasp-zap"],
  "scenario": "codebase"
}
```

Include ONLY findings (items that failed the checklist). Do not include passing items.

### 2. Write Gitleaks config

Create `devops/working/ci/security/.gitleaks.toml`:

```toml
title = "Gitleaks Config"

[allowlist]
  description = "Allowlisted paths"
  paths = [
    '''devops/working/''',
    '''\.env\.example$''',
  ]
```

### 3. Write Trivy ignore

Create `devops/working/ci/security/.trivyignore`:

```
# Add CVE IDs here to suppress false positives after manual review
# Example: CVE-2023-12345
```

## Confirmation

After writing both output files, tell the user:

```
Security review complete.
  Critical: N | High: N | Medium: N | Low: N
  Tools selected: [list]
  Saved to devops/working/security-findings.json

Top findings:
  [List top 3 by severity with one-line remediation each]

Moving to config generation.
```
```

- [ ] **Step 3: Run baseline pressure scenario**

Dispatch a subagent with this prompt:

> "You have `devops/working/analysis.json` showing: TypeScript Express app, AWS cloud, GitHub Actions, Containers deployment. The source code has a file `src/config.ts` containing `const API_KEY = 'sk-live-abc123'` and no `.gitignore`. You need to do a security review before generating DevOps configs. Walk me through exactly what you check and what you output."

Document: Does the agent check all 8 categories? Does it write `security-findings.json`? Does it select security tools?

- [ ] **Step 4: Verify skill compliance**

With skill loaded, verify:
- All 8 categories evaluated
- Hardcoded `API_KEY` flagged as Critical
- Missing `.gitignore` flagged as High
- `security-findings.json` written with correct structure
- Gitleaks and Trivy configs written
- Summary shown to user before moving on

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills
git add devops-security/SKILL.md
git commit -m "feat: add devops-security checklist and tool selection skill"
```

---

## Task 4: `devops-generate` — Config File Generation Skill

**Files:**
- Create: `~/.claude/skills/devops-generate/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/.claude/skills/devops-generate
```

- [ ] **Step 2: Write the devops-generate SKILL.md**

Write `~/.claude/skills/devops-generate/SKILL.md` with this exact content:

```markdown
---
name: devops-generate
description: Use when called by the devops dispatcher after security review to generate all DevOps config files based on analysis.json and security-findings.json
---

# DevOps Config Generation

## Overview

Reads `devops/working/analysis.json` and `devops/working/security-findings.json`. Generates working config templates to `devops/working/`. All files are templates — the user reviews and adapts them.

## Inputs

Read both JSON files before generating anything. Use `stack.language`, `choices.ci_cd_platform`, `choices.deployment_target`, `choices.cloud_provider`, and `selected_tools` throughout.

## Always Generate

Generate these for every project regardless of choices.

---

### Dockerfile (production)

`devops/working/containers/Dockerfile`

Generate a multi-stage production Dockerfile for the detected language. Always: non-root user, specific version pins, multi-stage build to minimize final image size.

**Node.js / TypeScript:**
```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS prod
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget --spider -q http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

**Python:**
```dockerfile
FROM python:3.12-slim AS base
WORKDIR /app
RUN addgroup --system appgroup && adduser --system --group appuser

FROM base AS deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM base AS prod
COPY --from=deps /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=deps /usr/local/bin /usr/local/bin
COPY . .
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD wget --spider -q http://localhost:8000/health || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Go:**
```dockerfile
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server ./cmd/server

FROM gcr.io/distroless/static-debian12 AS prod
COPY --from=build /app/server /server
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD ["/server", "-health"]
CMD ["/server"]
```

For other languages: adapt the pattern — official base image, pinned version, multi-stage, non-root user, HEALTHCHECK.

---

### Dockerfile.dev (local dev)

`devops/working/containers/Dockerfile.dev`

**Node.js / TypeScript:**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
EXPOSE 3000
CMD ["npx", "ts-node-dev", "--respawn", "--transpile-only", "src/index.ts"]
```

**Python:**
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

**Go:**
```dockerfile
FROM golang:1.22-alpine
WORKDIR /app
RUN go install github.com/air-verse/air@latest
COPY go.mod go.sum ./
RUN go mod download
COPY . .
EXPOSE 8080
CMD ["air"]
```

---

### .dockerignore

`devops/working/containers/.dockerignore`

```
node_modules
.git
.env*
!.env.example
dist
build
*.log
.DS_Store
coverage
.nyc_output
__pycache__
*.pyc
.pytest_cache
tmp
```

---

### docker-compose.yml (local dev)

`devops/working/compose/docker-compose.yml`

Generate based on detected `stack.database` list. Include only detected services.

```yaml
version: '3.9'

services:
  app:
    build:
      context: ../../../
      dockerfile: devops/working/containers/Dockerfile.dev
    ports:
      - "${APP_PORT:-3000}:3000"
    volumes:
      - ../../../src:/app/src
    env_file:
      - ../../../.env.local
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  # Include if PostgreSQL detected:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${DB_NAME:-app_dev}
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-devpassword}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-app}"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Include if Redis detected:
  cache:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  # Include if MongoDB detected:
  # mongo:
  #   image: mongo:7
  #   ports:
  #     - "27017:27017"
  #   environment:
  #     MONGO_INITDB_DATABASE: app_dev

volumes:
  postgres_data:
```

Only include services matching detected databases. Comment out undetected services rather than removing them (useful reference).

---

### docker-compose.team.yml

`devops/working/compose/docker-compose.team.yml`

```yaml
version: '3.9'

# Team dev — extends local compose with stricter resource limits
# Mirrors staging more closely than local dev

services:
  app:
    extends:
      file: docker-compose.yml
      service: app
    environment:
      NODE_ENV: development
      LOG_LEVEL: debug
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  db:
    extends:
      file: docker-compose.yml
      service: db
    deploy:
      resources:
        limits:
          memory: 256M
```

---

### docker-compose.prod.yml (reference)

`devops/working/compose/docker-compose.prod.yml`

```yaml
version: '3.9'

# Production-like reference — not for direct deployment
# Use this as the source of truth for staging/prod environment config

services:
  app:
    image: ${IMAGE_NAME}:${IMAGE_TAG:-latest}
    restart: unless-stopped
    environment:
      NODE_ENV: production
      LOG_LEVEL: warn
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 256M
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

---

### devcontainer.json

`devops/working/devcontainer/.devcontainer/devcontainer.json`

```json
{
  "name": "App Dev Container",
  "dockerComposeFile": [
    "../../compose/docker-compose.yml",
    "docker-compose.devcontainer.yml"
  ],
  "service": "app",
  "workspaceFolder": "/app",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "postCreateCommand": "npm install",
  "forwardPorts": [3000],
  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "ms-azuretools.vscode-docker"
      ],
      "settings": {
        "editor.formatOnSave": true
      }
    }
  }
}
```

Adapt `postCreateCommand` and extensions to the detected language and framework.

`devops/working/devcontainer/.devcontainer/docker-compose.devcontainer.yml`:

```yaml
version: '3.9'
services:
  app:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

---

### Setup Scripts

`devops/working/scripts/setup-local.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "Setting up local dev environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required. Install from https://docs.docker.com/get-docker/"; exit 1; }

# Create .env.local if it doesn't exist
if [ ! -f .env.local ]; then
  if [ -f .env.example ]; then
    cp .env.example .env.local
    echo "Created .env.local from .env.example — update with your local values"
  else
    cat > .env.local << 'EOF'
# Local dev environment variables — gitignored
NODE_ENV=development
APP_PORT=3000
DB_NAME=app_dev
DB_USER=app
DB_PASSWORD=devpassword
DB_HOST=localhost
DB_PORT=5432
REDIS_URL=redis://localhost:6379
EOF
    echo "Created .env.local — update with your local values"
  fi
fi

# Start services
echo "Starting services..."
docker compose -f devops/working/compose/docker-compose.yml up -d

# Wait for health
echo "Waiting for services to be healthy..."
sleep 3

echo ""
echo "Local dev environment ready."
echo "  App:   http://localhost:${APP_PORT:-3000}"
echo "  DB:    localhost:5432"
echo ""
echo "Run 'docker compose -f devops/working/compose/docker-compose.yml logs -f' to see logs."
```

`devops/working/scripts/setup-team.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "Setting up team dev environment..."

command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required."; exit 1; }
command -v code >/dev/null 2>&1 || { echo "WARN: VS Code not found. Install from https://code.visualstudio.com/"; }

echo ""
echo "Team dev uses a VS Code Dev Container."
echo "To open:"
echo "  1. Open this repo in VS Code"
echo "  2. Install the 'Dev Containers' extension (ms-vscode-remote.remote-containers)"
echo "  3. Run: Cmd+Shift+P → 'Dev Containers: Reopen in Container'"
echo ""
echo "Or run the local dev setup first: ./devops/working/scripts/setup-local.sh"
```

---

## CI/CD Pipeline Generation

Generate for the platform in `analysis.json.choices.ci_cd_platform`. Generate ALL three platforms (GitHub Actions, GitLab CI, CircleCI) even if only one was selected — the user can choose which to use.

---

### GitHub Actions

`devops/working/ci/github-actions/ci.yml` (compatible with `.github/workflows/ci.yml`):

```yaml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  lint:
    name: Lint + SAST
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Adapt setup to detected language:
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint

      - name: Semgrep SAST
        uses: semgrep/semgrep-action@v1
        with:
          config: auto

      - name: CodeQL Analysis
        uses: github/codeql-action/init@v3
        with:
          languages: javascript-typescript

      - name: Gitleaks secret scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  test:
    name: Test
    runs-on: ubuntu-latest
    needs: lint
    services:
      # Include services matching detected databases:
      db:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test
          POSTGRES_PASSWORD: testpass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
        env:
          DATABASE_URL: postgresql://test:testpass@localhost:5432/test_db

  build:
    name: Build + Push Image
    runs-on: ubuntu-latest
    needs: test
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: devops/working/containers/Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security-scan:
    name: Security Scan (Trivy)
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name != 'pull_request'
    steps:
      - name: Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
          ignore-unfixed: true

  deploy-staging:
    name: Deploy → Staging
    runs-on: ubuntu-latest
    needs: security-scan
    if: github.ref == 'refs/heads/main'
    environment:
      name: staging
      url: https://staging.your-app.example.com
    steps:
      - uses: actions/checkout@v4
      # Replace with your cloud-specific deploy step:
      - name: Deploy to staging
        run: |
          echo "Deploying ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} to staging"
          # AWS ECS: aws ecs update-service --cluster staging --service app --force-new-deployment
          # GCP Cloud Run: gcloud run deploy app --image ... --region us-central1
          # K8s: kubectl set image deployment/app app=...

  dast-scan:
    name: DAST Scan (OWASP ZAP)
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    steps:
      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.9.0
        with:
          target: 'https://staging.your-app.example.com'
          allow_issue_writing: false

  deploy-prod:
    name: Deploy → Production
    runs-on: ubuntu-latest
    needs: dast-scan
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://your-app.example.com
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        run: |
          echo "Deploying ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} to production"
          # Same deploy command as staging, targeting prod cluster/service
```

`devops/working/ci/github-actions/dependabot.yml` (compatible with `.github/dependabot.yml`):

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "docker"
    directory: "/devops/working/containers"
    schedule:
      interval: "weekly"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Adapt `package-ecosystem` to detected language (pip for Python, gomod for Go, maven for Java).

---

### GitLab CI

`devops/working/ci/gitlab-ci/.gitlab-ci.yml`:

```yaml
stages:
  - lint
  - test
  - build
  - security-scan
  - deploy-staging
  - dast
  - deploy-prod

variables:
  IMAGE_NAME: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  DOCKER_BUILDKIT: "1"
  FF_USE_FASTZIP: "true"

.node-base: &node-base
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/

lint:
  stage: lint
  <<: *node-base
  script:
    - npm ci
    - npm run lint
    - npx semgrep --config=auto --error .
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

gitleaks:
  stage: lint
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --config devops/working/ci/security/.gitleaks.toml

test:
  stage: test
  <<: *node-base
  services:
    - name: postgres:16-alpine
      alias: db
  variables:
    POSTGRES_DB: test_db
    POSTGRES_USER: test
    POSTGRES_PASSWORD: testpass
    DATABASE_URL: postgresql://test:testpass@db/test_db
  script:
    - npm ci
    - npm test
  coverage: '/Lines\s*:\s*(\d+\.?\d*)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - |
      docker build \
        -f devops/working/containers/Dockerfile \
        -t $IMAGE_NAME \
        --cache-from $CI_REGISTRY_IMAGE:latest \
        .
    - docker push $IMAGE_NAME
    - docker tag $IMAGE_NAME $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:latest

trivy-scan:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed $IMAGE_NAME
  only:
    - main

snyk-scan:
  stage: security-scan
  image: node:20-alpine
  script:
    - npm install -g snyk
    - snyk auth $SNYK_TOKEN
    - snyk test --severity-threshold=high
  only:
    - main
  allow_failure: true

deploy-staging:
  stage: deploy-staging
  environment:
    name: staging
    url: https://staging.your-app.example.com
  script:
    - echo "Deploy $IMAGE_NAME to staging"
    # Add your cloud-specific deploy command
  only:
    - main

zap-scan:
  stage: dast
  image: zaproxy/zap-stable
  script:
    - zap-baseline.py -t https://staging.your-app.example.com -r zap-report.html
  artifacts:
    paths:
      - zap-report.html
  only:
    - main
  allow_failure: true

deploy-prod:
  stage: deploy-prod
  environment:
    name: production
    url: https://your-app.example.com
  when: manual
  script:
    - echo "Deploy $IMAGE_NAME to production"
    # Add your cloud-specific deploy command
  only:
    - main
```

---

### CircleCI

`devops/working/ci/circleci/.circleci/config.yml`:

```yaml
version: 2.1

orbs:
  node: circleci/node@5
  docker: circleci/docker@2
  snyk: snyk/snyk@1

executors:
  node-executor:
    docker:
      - image: cimg/node:20.0

jobs:
  lint:
    executor: node-executor
    steps:
      - checkout
      - node/install-packages
      - run: npm run lint
      - run:
          name: Semgrep SAST
          command: |
            pip install semgrep
            semgrep --config=auto --error .
      - run:
          name: Gitleaks
          command: |
            curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz | tar -xz
            ./gitleaks detect --source . --config devops/working/ci/security/.gitleaks.toml

  test:
    docker:
      - image: cimg/node:20.0
      - image: cimg/postgres:16.0
        environment:
          POSTGRES_DB: test_db
          POSTGRES_USER: test
          POSTGRES_PASSWORD: testpass
    steps:
      - checkout
      - node/install-packages
      - run:
          name: Wait for DB
          command: dockerize -wait tcp://localhost:5432 -timeout 1m
      - run: npm test
        environment:
          DATABASE_URL: postgresql://test:testpass@localhost:5432/test_db

  build-push:
    docker:
      - image: cimg/base:2024.01
    steps:
      - checkout
      - setup_remote_docker:
          docker_layer_caching: true
      - docker/check
      - docker/build:
          dockerfile: devops/working/containers/Dockerfile
          image: $DOCKER_IMAGE
          tag: $CIRCLE_SHA1
      - docker/push:
          image: $DOCKER_IMAGE
          tag: $CIRCLE_SHA1

  trivy-scan:
    docker:
      - image: aquasec/trivy:latest
    steps:
      - run:
          name: Trivy scan
          command: trivy image --exit-code 1 --severity CRITICAL,HIGH $DOCKER_IMAGE:$CIRCLE_SHA1

  snyk-scan:
    executor: node-executor
    steps:
      - checkout
      - snyk/scan:
          severity-threshold: high
          fail-on-issues: true

  deploy-staging:
    docker:
      - image: cimg/base:2024.01
    steps:
      - run: echo "Deploy $DOCKER_IMAGE:$CIRCLE_SHA1 to staging"

  deploy-prod:
    docker:
      - image: cimg/base:2024.01
    steps:
      - run: echo "Deploy $DOCKER_IMAGE:$CIRCLE_SHA1 to production"

workflows:
  ci-cd:
    jobs:
      - lint
      - test:
          requires: [lint]
      - build-push:
          requires: [test]
      - trivy-scan:
          requires: [build-push]
          filters:
            branches:
              only: main
      - snyk-scan:
          requires: [build-push]
          filters:
            branches:
              only: main
      - deploy-staging:
          requires: [trivy-scan, snyk-scan]
          filters:
            branches:
              only: main
      - deploy-prod:
          requires: [deploy-staging]
          type: approval
          filters:
            branches:
              only: main
```

---

## Kubernetes Manifests (conditional)

Only generate if `choices.deployment_target` is "Kubernetes".

`devops/working/k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  labels:
    app: app
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: app
          image: IMAGE_NAME:IMAGE_TAG
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          envFrom:
            - secretRef:
                name: app-secrets
            - configMapRef:
                name: app-config
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
      imagePullSecrets:
        - name: registry-credentials
```

`devops/working/k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: ClusterIP
```

`devops/working/k8s/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app
                port:
                  number: 80
```

`devops/working/k8s/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  NODE_ENV: "production"
  LOG_LEVEL: "warn"
  PORT: "3000"
```

---

## Terraform (conditional)

Only generate if `choices.cloud_provider` is AWS, GCP, or Azure AND `choices.deployment_target` is Containers, Kubernetes, or Serverless.

**AWS ECS example** (`devops/working/infra/terraform/main.tf`):

```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "app/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = var.app_name
    image = "${var.ecr_repository_url}:${var.image_tag}"
    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]
    environment = []
    secrets = [{
      name      = "DATABASE_URL"
      valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}-db-url"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.app_name}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.app_name}-ecs-execution-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.app_name}-ecs-task-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

data "aws_caller_identity" "current" {}
```

`devops/working/infra/terraform/variables.tf`:

```hcl
variable "app_name" {
  type        = string
  description = "Application name (used for resource naming)"
}

variable "environment" {
  type        = string
  description = "Environment: dev, staging, prod"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ecr_repository_url" {
  type        = string
  description = "ECR repository URL (without tag)"
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy"
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}
```

`devops/working/infra/environments/dev.tfvars`:
```hcl
app_name    = "your-app-dev"
environment = "dev"
aws_region  = "us-east-1"
image_tag   = "latest"
task_cpu    = "256"
task_memory = "512"
```

`devops/working/infra/environments/staging.tfvars`:
```hcl
app_name    = "your-app-staging"
environment = "staging"
aws_region  = "us-east-1"
task_cpu    = "512"
task_memory = "1024"
```

`devops/working/infra/environments/prod.tfvars`:
```hcl
app_name    = "your-app-prod"
environment = "prod"
aws_region  = "us-east-1"
task_cpu    = "1024"
task_memory = "2048"
```

For GCP Cloud Run or Azure Container Apps, adapt the Terraform to use the appropriate provider and resource types. The variables.tf structure stays the same.

---

## Completion

After writing all files, tell the user:

```
Config generation complete. Files written to devops/working/.

Generated:
  ✓ containers/Dockerfile (production, multi-stage)
  ✓ containers/Dockerfile.dev (dev with hot-reload)
  ✓ compose/docker-compose.yml (local dev)
  ✓ compose/docker-compose.team.yml (team dev)
  ✓ compose/docker-compose.prod.yml (prod reference)
  ✓ devcontainer/.devcontainer/devcontainer.json
  ✓ ci/github-actions/ci.yml
  ✓ ci/gitlab-ci/.gitlab-ci.yml
  ✓ ci/circleci/.circleci/config.yml
  ✓ scripts/setup-local.sh
  ✓ scripts/setup-team.sh
  [✓ k8s/ — 4 manifests] (if Kubernetes selected)
  [✓ infra/terraform/ — main.tf, variables.tf, 3 env files] (if cloud infra selected)

Moving to report generation.
```
```

- [ ] **Step 3: Run baseline pressure scenario**

Dispatch a subagent with this prompt:

> "You have `devops/working/analysis.json` with: TypeScript Express app, AWS, GitHub Actions, Containers deployment, PostgreSQL and Redis detected, Small team. You also have `devops/working/security-findings.json` with Trivy and Gitleaks selected. Generate all the DevOps config files now. List exactly what files you create and show the content of the GitHub Actions CI pipeline."

Document: Does the agent generate all required files? Does it use multi-stage Dockerfile? Does it include the security scan stage in CI? Does it inject Gitleaks?

- [ ] **Step 4: Verify skill compliance**

With skill loaded, verify:
- Multi-stage Dockerfile generated with non-root user
- GitHub Actions CI includes `lint → test → build → security-scan → deploy-staging → deploy-prod` pipeline
- Gitleaks step included in lint job
- Trivy scan included in security-scan job
- `deploy-prod` has manual approval gate (`environment: production`)
- All three CI platforms generated (not just GitHub Actions)
- `setup-local.sh` and `setup-team.sh` scripts generated
- Completion summary shown

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills
git add devops-generate/SKILL.md
git commit -m "feat: add devops-generate config file generation skill"
```

---

## Task 5: `devops-report` — HTML Report & Diagrams Skill

**Files:**
- Create: `~/.claude/skills/devops-report/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/.claude/skills/devops-report
```

- [ ] **Step 2: Write the devops-report SKILL.md**

Write `~/.claude/skills/devops-report/SKILL.md` with this exact content:

```markdown
---
name: devops-report
description: Use when called by the devops dispatcher after config generation to produce a self-contained HTML report with architecture and workflow diagrams embedded as inline SVG
---

# DevOps HTML Report Generation

## Overview

Reads `devops/working/analysis.json` and `devops/working/security-findings.json` plus the generated file list. Produces `devops/report/index.html` — a single self-contained HTML file with embedded SVG diagrams, no external dependencies.

## Inputs

Read these files before generating the report:
- `devops/working/analysis.json`
- `devops/working/security-findings.json`
- List all files in `devops/working/` (for the artifacts table)

## Diagram Generation

For each diagram: write a Graphviz DOT definition, then convert it mentally to SVG using the DOT layout rules below. Embed the resulting SVG string directly in the HTML. No tools required — generate the SVG as text.

**SVG generation approach:** Graphviz DOT → translate nodes/edges to SVG `<rect>`, `<text>`, `<line>`, and `<path>` elements with approximate layout. Use `rankdir=LR` for left-to-right pipelines, `rankdir=TB` for top-down architectures. Clusters become `<rect>` with labels.

### Diagram 1: Architecture Overview (C4 Container Level)

Adapt based on detected `stack`. Include all services in `stack.database` and any external services.

```dot
digraph architecture {
  rankdir=TB
  graph [fontname="Arial" bgcolor="transparent"]
  node [shape=box style="filled,rounded" fontname="Arial" fontsize=12 margin="0.3,0.2"]
  edge [fontname="Arial" fontsize=10]

  user [label="User / Client" shape=ellipse fillcolor="#dbeafe" color="#2563eb"]

  subgraph cluster_app {
    label="Application Layer" style=filled fillcolor="#eff6ff" color="#2563eb"
    app [label="App Service\n(TypeScript/Express)" fillcolor="#bfdbfe" color="#1d4ed8"]
  }

  subgraph cluster_data {
    label="Data Layer" style=filled fillcolor="#f0fdf4" color="#16a34a"
    db [label="PostgreSQL\n(Primary DB)" fillcolor="#bbf7d0" color="#15803d"]
    cache [label="Redis\n(Cache)" fillcolor="#bbf7d0" color="#15803d"]
  }

  subgraph cluster_infra {
    label="Infrastructure" style=filled fillcolor="#fafafa" color="#6b7280"
    secrets [label="Secrets Manager\n(AWS SM)" fillcolor="#f3f4f6" color="#4b5563"]
    registry [label="Container Registry\n(GHCR)" fillcolor="#f3f4f6" color="#4b5563"]
  }

  user -> app [label="HTTPS"]
  app -> db [label="PostgreSQL"]
  app -> cache [label="Redis"]
  app -> secrets [label="read secrets" style=dashed]
  registry -> app [label="pull image" style=dashed]
}
```

Adapt node labels to actual detected stack. Remove services not in `stack.database`.

### Diagram 2: CI/CD Pipeline

```dot
digraph pipeline {
  rankdir=LR
  graph [fontname="Arial" bgcolor="transparent"]
  node [shape=box style="filled,rounded" fontname="Arial" fontsize=11 width=1.2]
  edge [fontname="Arial" fontsize=9]

  lint [label="Lint\n+ SAST\n+ Secrets" fillcolor="#fef9c3" color="#92400e"]
  test [label="Test\n+ Coverage" fillcolor="#fef9c3" color="#92400e"]
  build [label="Build\n+ Push\nImage" fillcolor="#dbeafe" color="#1d4ed8"]
  scan [label="Security\nScan\n(Trivy)" fillcolor="#fee2e2" color="#991b1b"]
  staging [label="Deploy\nStaging" fillcolor="#dcfce7" color="#15803d"]
  dast [label="DAST\n(ZAP)" fillcolor="#fee2e2" color="#991b1b"]
  approval [label="Manual\nApproval" shape=diamond fillcolor="#fef3c7" color="#b45309"]
  prod [label="Deploy\nProduction" fillcolor="#dcfce7" color="#15803d"]

  lint -> test -> build -> scan -> staging -> dast -> approval -> prod
}
```

### Diagram 3: Deployment Topology

Generate based on `choices.cloud_provider` and `choices.deployment_target`.

**AWS + Containers (ECS):**
```dot
digraph deployment {
  rankdir=TB
  graph [fontname="Arial" bgcolor="transparent"]
  node [shape=box style="filled,rounded" fontname="Arial" fontsize=11]

  internet [label="Internet" shape=ellipse fillcolor="#f3f4f6"]
  ecr [label="ECR\nContainer\nRegistry" fillcolor="#fff7ed" color="#c2410c"]
  ghcr [label="CI/CD\n(GitHub Actions)" fillcolor="#f3f4f6" color="#374151"]

  subgraph cluster_vpc {
    label="AWS VPC" style=filled fillcolor="#eff6ff" color="#2563eb"
    subgraph cluster_public {
      label="Public Subnets" style=filled fillcolor="#dbeafe" color="#3b82f6"
      alb [label="ALB\nLoad Balancer" fillcolor="#bfdbfe"]
    }
    subgraph cluster_private {
      label="Private Subnets" style=filled fillcolor="#f0fdf4" color="#16a34a"
      ecs [label="ECS Fargate\n(App Container)" fillcolor="#bbf7d0"]
      rds [label="RDS\nPostgreSQL" fillcolor="#bbf7d0"]
      elasticache [label="ElastiCache\nRedis" fillcolor="#bbf7d0"]
    }
    sm [label="Secrets\nManager" fillcolor="#fef3c7" color="#b45309"]
  }

  internet -> alb -> ecs
  ecs -> rds [label="TCP 5432"]
  ecs -> elasticache [label="TCP 6379"]
  ecs -> sm [label="read" style=dashed]
  ghcr -> ecr [label="push image" style=dashed]
  ecr -> ecs [label="pull" style=dashed]
}
```

For GCP: use Cloud Run, Cloud SQL, Memorystore, Secret Manager, Artifact Registry.
For Azure: use ACA, Azure Database, Azure Cache for Redis, Key Vault, ACR.
For Kubernetes: show ingress → service → pod → persistent volume.

### Diagram 4: Dev Environment Topology

```dot
digraph devenvs {
  rankdir=LR
  graph [fontname="Arial" bgcolor="transparent"]
  node [shape=box style="filled,rounded" fontname="Arial" fontsize=11]

  subgraph cluster_local {
    label="Local Dev (Docker Compose)" style=filled fillcolor="#eff6ff" color="#2563eb"
    lapp [label="App\n(hot-reload)" fillcolor="#bfdbfe"]
    ldb [label="PostgreSQL\n(local)" fillcolor="#bbf7d0"]
    lredis [label="Redis\n(local)" fillcolor="#bbf7d0"]
    lenv [label=".env.local\n(dev secrets)" fillcolor="#f3f4f6" shape=note]
  }

  subgraph cluster_team {
    label="Team Dev (DevContainer + optional kind)" style=filled fillcolor="#f0fdf4" color="#16a34a"
    tapp [label="App\n(VS Code\nDevContainer)" fillcolor="#bbf7d0"]
    tdb [label="PostgreSQL\n(shared)" fillcolor="#bbf7d0"]
    tk8s [label="kind cluster\n(optional k8s)" fillcolor="#fef9c3" style="filled,dashed"]
  }

  dev1 [label="Developer\n(local machine)" shape=ellipse fillcolor="#f9fafb"]
  dev2 [label="Developer\n(team)" shape=ellipse fillcolor="#f9fafb"]

  dev1 -> lapp -> ldb
  dev1 -> lapp -> lredis
  lenv -> lapp [style=dashed label="env vars"]
  dev2 -> tapp -> tdb
  dev2 -> tk8s [style=dashed label="optional"]
}
```

Adapt based on detected databases from `stack.database`.

## Report Sections

Generate the HTML in this order:

1. **Executive Summary** — stack, scenario, 3 key decisions, top 3 findings from security-findings.json
2. **Architecture Overview** — Diagram 1 embedded SVG
3. **Deployment Architecture** — Diagram 3 embedded SVG
4. **CI/CD Workflow** — Diagram 2 embedded SVG + table of pipeline stages
5. **Dev Environments** — Diagram 4 embedded SVG + setup instructions
6. **Generated Artifacts** — table of every file in devops/working/ with one-line description
7. **Security Report** — severity counts, findings table sorted Critical→Low
8. **Recommendations** — prioritized list (especially detailed for review scenario)

**For review scenario only:** Add a "Before vs After" section between Recommendations and the end. Compare existing config issues (from security-findings.json) with the improvements made in the generated configs.

## HTML Template

Generate the complete HTML. Substitute all `{placeholder}` values from analysis.json and security-findings.json.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DevOps Report — {project_name}</title>
  <style>
    :root {
      --blue: #2563eb; --green: #16a34a; --yellow: #d97706;
      --red: #dc2626; --gray-50: #f9fafb; --gray-100: #f3f4f6;
      --gray-200: #e5e7eb; --gray-700: #374151; --gray-900: #111827;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           color: var(--gray-900); background: #fff; line-height: 1.5; }
    .container { max-width: 1100px; margin: 0 auto; padding: 2rem 1.5rem; }
    header { background: var(--blue); color: #fff; padding: 2rem 2.5rem;
             margin-bottom: 2.5rem; border-radius: 10px; }
    header h1 { font-size: 1.8rem; margin-bottom: 0.4rem; }
    header .meta { opacity: 0.85; font-size: 0.9rem; }
    section { margin-bottom: 2.5rem; }
    h2 { font-size: 1.25rem; color: var(--blue); padding-bottom: 0.5rem;
         border-bottom: 2px solid var(--gray-200); margin-bottom: 1.25rem; }
    h3 { font-size: 1.05rem; color: var(--gray-700); margin-bottom: 0.75rem; margin-top: 1.25rem; }
    .diagram-wrap { background: var(--gray-50); border: 1px solid var(--gray-200);
                    border-radius: 8px; padding: 1.5rem; margin: 1rem 0;
                    overflow-x: auto; text-align: center; }
    table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
    th { background: var(--gray-100); padding: 0.6rem 0.875rem; text-align: left;
         font-weight: 600; border-bottom: 2px solid var(--gray-200); }
    td { padding: 0.55rem 0.875rem; border-bottom: 1px solid var(--gray-200);
         vertical-align: top; }
    tr:last-child td { border-bottom: none; }
    .badge { display: inline-block; padding: 0.15rem 0.55rem; border-radius: 20px;
             font-size: 0.75rem; font-weight: 600; letter-spacing: 0.02em; }
    .badge-critical { background: #fee2e2; color: var(--red); }
    .badge-high { background: #ffedd5; color: #c2410c; }
    .badge-medium { background: #fef9c3; color: #92400e; }
    .badge-low { background: #dcfce7; color: var(--green); }
    .counts { display: flex; gap: 1rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
    .count-card { flex: 1; min-width: 100px; background: var(--gray-50);
                  border: 1px solid var(--gray-200); border-radius: 8px;
                  padding: 1rem; text-align: center; }
    .count-num { font-size: 2rem; font-weight: 700; line-height: 1; }
    .count-card.critical .count-num { color: var(--red); }
    .count-card.high .count-num { color: #c2410c; }
    .count-card.medium .count-num { color: #92400e; }
    .count-card.low .count-num { color: var(--green); }
    .count-label { font-size: 0.8rem; color: var(--gray-700); margin-top: 0.25rem; }
    .recs { list-style: none; }
    .recs li { padding: 0.6rem 0; border-bottom: 1px solid var(--gray-200);
               display: flex; gap: 0.6rem; }
    .recs li::before { content: "→"; color: var(--blue); font-weight: bold;
                       flex-shrink: 0; margin-top: 0.1rem; }
    .setup-cmd { background: #1e293b; color: #e2e8f0; padding: 0.75rem 1rem;
                 border-radius: 6px; font-family: monospace; font-size: 0.875rem;
                 margin: 0.5rem 0; }
    .stack-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                  gap: 0.75rem; margin-bottom: 1.25rem; }
    .stack-item { background: var(--gray-50); border: 1px solid var(--gray-200);
                  border-radius: 6px; padding: 0.75rem 1rem; }
    .stack-item .label { font-size: 0.75rem; color: var(--gray-700); font-weight: 600;
                         text-transform: uppercase; letter-spacing: 0.05em; }
    .stack-item .value { font-size: 0.95rem; font-weight: 500; margin-top: 0.15rem; }
    @media print {
      header { background: #1e40af !important; -webkit-print-color-adjust: exact; }
      .diagram-wrap { page-break-inside: avoid; }
    }
  </style>
</head>
<body>
<div class="container">

  <header>
    <h1>DevOps Report — {project_name}</h1>
    <div class="meta">
      Scenario: {scenario_label} &nbsp;|&nbsp;
      Generated: {date} &nbsp;|&nbsp;
      Cloud: {cloud_provider} &nbsp;|&nbsp;
      CI/CD: {ci_cd_platform}
    </div>
  </header>

  <section>
    <h2>Executive Summary</h2>
    <div class="stack-grid">
      <div class="stack-item">
        <div class="label">Language</div>
        <div class="value">{language}</div>
      </div>
      <div class="stack-item">
        <div class="label">Framework</div>
        <div class="value">{framework}</div>
      </div>
      <div class="stack-item">
        <div class="label">Cloud</div>
        <div class="value">{cloud_provider}</div>
      </div>
      <div class="stack-item">
        <div class="label">Deployment</div>
        <div class="value">{deployment_target}</div>
      </div>
      <div class="stack-item">
        <div class="label">Secrets</div>
        <div class="value">{secrets_management}</div>
      </div>
      <div class="stack-item">
        <div class="label">Team Size</div>
        <div class="value">{team_size}</div>
      </div>
    </div>
    <h3>Top Security Findings</h3>
    <!-- Table of top 3 findings by severity from security-findings.json -->
  </section>

  <section>
    <h2>Architecture Overview</h2>
    <div class="diagram-wrap">
      <!-- Diagram 1 SVG embedded here -->
    </div>
  </section>

  <section>
    <h2>Deployment Architecture</h2>
    <div class="diagram-wrap">
      <!-- Diagram 3 SVG embedded here -->
    </div>
  </section>

  <section>
    <h2>CI/CD Workflow</h2>
    <div class="diagram-wrap">
      <!-- Diagram 2 SVG embedded here -->
    </div>
    <h3>Pipeline Stages</h3>
    <table>
      <thead><tr><th>Stage</th><th>Jobs</th><th>Gate</th></tr></thead>
      <tbody>
        <tr><td>lint</td><td>ESLint, Semgrep SAST, Gitleaks</td><td>Blocks test on failure</td></tr>
        <tr><td>test</td><td>Unit + integration tests with real DB</td><td>Blocks build on failure</td></tr>
        <tr><td>build</td><td>Multi-stage Docker build, push to registry</td><td>Main branch only for push</td></tr>
        <tr><td>security-scan</td><td>Trivy CVE scan on built image</td><td>Main branch only; blocks deploy on Critical/High</td></tr>
        <tr><td>deploy-staging</td><td>Deploy to staging environment</td><td>Auto after security scan passes</td></tr>
        <tr><td>dast</td><td>OWASP ZAP baseline scan on staging</td><td>Non-blocking (report only)</td></tr>
        <tr><td>deploy-prod</td><td>Deploy to production environment</td><td><strong>Manual approval required</strong></td></tr>
      </tbody>
    </table>
  </section>

  <section>
    <h2>Dev Environments</h2>
    <div class="diagram-wrap">
      <!-- Diagram 4 SVG embedded here -->
    </div>
    <h3>Quick Start</h3>
    <p><strong>Local dev (single machine):</strong></p>
    <div class="setup-cmd">./devops/working/scripts/setup-local.sh</div>
    <p style="margin-top:0.75rem"><strong>Team dev (DevContainer):</strong></p>
    <div class="setup-cmd">./devops/working/scripts/setup-team.sh</div>
  </section>

  <section>
    <h2>Generated Artifacts</h2>
    <table>
      <thead><tr><th>File</th><th>Purpose</th></tr></thead>
      <tbody>
        <!-- One row per file in devops/working/, generated from file list -->
      </tbody>
    </table>
  </section>

  <section>
    <h2>Security Report</h2>
    <div class="counts">
      <div class="count-card critical">
        <div class="count-num">{critical_count}</div>
        <div class="count-label">Critical</div>
      </div>
      <div class="count-card high">
        <div class="count-num">{high_count}</div>
        <div class="count-label">High</div>
      </div>
      <div class="count-card medium">
        <div class="count-num">{medium_count}</div>
        <div class="count-label">Medium</div>
      </div>
      <div class="count-card low">
        <div class="count-num">{low_count}</div>
        <div class="count-label">Low</div>
      </div>
    </div>
    <table>
      <thead>
        <tr><th>Severity</th><th>Category</th><th>Finding</th><th>Remediation</th></tr>
      </thead>
      <tbody>
        <!-- Rows from security-findings.json, sorted Critical → High → Medium → Low -->
      </tbody>
    </table>
  </section>

  <section>
    <h2>Recommendations</h2>
    <ul class="recs">
      <!-- Prioritized list. For review scenario: reference specific existing config
           issues found vs what was generated as improvement -->
    </ul>
  </section>

  <!-- Only for review scenario: -->
  <!--
  <section>
    <h2>Before vs After</h2>
    <table>
      <thead><tr><th>Area</th><th>Before (existing config)</th><th>After (generated config)</th></tr></thead>
      <tbody>
        <tr>
          <td>CI pipeline</td>
          <td>No security scanning stages, no approval gate for prod</td>
          <td>Semgrep + Trivy + Gitleaks in CI, manual approval before prod deploy</td>
        </tr>
      </tbody>
    </table>
  </section>
  -->

</div>
</body>
</html>
```

## SVG Rendering Instructions

For each diagram DOT definition above:

1. Parse nodes and edges mentally
2. Apply approximate Graphviz layout (left-to-right for LR, top-down for TB)
3. Render each node as an SVG `<rect>` + `<text>` element
4. Render each edge as an SVG `<line>` or `<path>` with `<text>` for labels
5. Render clusters as `<rect>` with a `<text>` label at top
6. Use the `fillcolor` values from the DOT definition for `fill` attributes
7. Set `width` and `height` on the root `<svg>` element to fit the diagram

Keep SVG simple and readable. Accuracy of layout matters more than pixel-perfect rendering.

## Output

Create the `devops/report/` directory if it doesn't exist. Write the completed HTML to `devops/report/index.html`.

After writing, confirm:

```
Report generated: devops/report/index.html
  Sections: 8 (+ Before/After for review scenario)
  Diagrams: 4 (Architecture, Deployment, CI/CD Pipeline, Dev Environments)
  Security findings: N total (C critical, H high, M medium, L low)

Open with: open devops/report/index.html
```
```

- [ ] **Step 3: Run baseline pressure scenario**

Dispatch a subagent with this prompt:

> "You have `devops/working/analysis.json` (TypeScript Express, AWS, GitHub Actions, PostgreSQL + Redis, Containers) and `devops/working/security-findings.json` (2 Critical, 1 High, 3 Medium). Generate the complete `devops/report/index.html`. Show me: (a) the executive summary section, (b) the CI/CD pipeline diagram as SVG, and (c) the security report table."

Document: Does the agent generate a self-contained HTML? Does it include inline SVG diagrams? Does it populate findings from the JSON?

- [ ] **Step 4: Verify skill compliance**

With skill loaded, verify:
- `devops/report/index.html` is self-contained (no external CSS or JS links)
- All 4 diagrams appear as embedded SVG, not as placeholders
- Security findings table populated from security-findings.json
- Severity counts shown (Critical/High/Medium/Low)
- Review scenario: Before vs After section present when scenario = "review"

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills
git add devops-report/SKILL.md
git commit -m "feat: add devops-report HTML report generation skill"
```

---

## Task 6: Integration Test — Full Pipeline End-to-End

This task verifies all 5 skills work together as a complete pipeline.

- [ ] **Step 1: Create a test fixture project**

```bash
mkdir -p /tmp/devops-test-project/src
cat > /tmp/devops-test-project/src/index.ts << 'EOF'
import express from 'express';
const app = express();
app.get('/health', (req, res) => res.json({ ok: true }));
app.listen(3000);
EOF

cat > /tmp/devops-test-project/package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF

cat > /tmp/devops-test-project/package-lock.json << 'EOF'
{ "name": "test-project", "lockfileVersion": 3, "packages": {} }
EOF
```

- [ ] **Step 2: Run the full devops pipeline from the test project**

Change to the test project directory and invoke the `devops` skill:

```
cd /tmp/devops-test-project
# Invoke: /devops
```

Expected behavior:
1. Dispatcher detects Scenario 2 (Code-complete: source code, no devops/ folder)
2. Detects TypeScript, Express
3. Confirms scenario with user
4. Calls `devops-analyze` → produces `devops/working/analysis.json`
5. Calls `devops-security` → produces `devops/working/security-findings.json`
6. Calls `devops-generate` → produces all files in `devops/working/`
7. Calls `devops-report` → produces `devops/report/index.html`

- [ ] **Step 3: Verify all output files exist**

```bash
ls devops/working/analysis.json
ls devops/working/security-findings.json
ls devops/working/containers/Dockerfile
ls devops/working/containers/Dockerfile.dev
ls devops/working/compose/docker-compose.yml
ls devops/working/ci/github-actions/ci.yml
ls devops/working/ci/gitlab-ci/.gitlab-ci.yml
ls devops/working/ci/circleci/.circleci/config.yml
ls devops/working/scripts/setup-local.sh
ls devops/report/index.html
```

All should exist. If any are missing, check which sub-skill failed to generate it.

- [ ] **Step 4: Verify HTML report is self-contained**

```bash
# No external links should appear in the HTML
grep -E "(http|https)://" devops/report/index.html | grep -v "<!-- " | head -5
# Expected: no matches (all resources inline)
```

- [ ] **Step 5: Verify Dockerfile is production-safe**

```bash
grep -i "USER" devops/working/containers/Dockerfile
# Expected: line with USER instruction (non-root)

grep "FROM.*latest" devops/working/containers/Dockerfile
# Expected: no matches (no latest tags)

grep -c "FROM" devops/working/containers/Dockerfile
# Expected: 3 (multi-stage: deps, build, prod)
```

- [ ] **Step 6: Verify CI pipeline has security stages**

```bash
grep "trivy\|semgrep\|gitleaks" devops/working/ci/github-actions/ci.yml
# Expected: at least 3 matches (one per tool)

grep "manual\|approval\|environment:.*production" devops/working/ci/github-actions/ci.yml
# Expected: manual approval gate present
```

- [ ] **Step 7: Commit integration test results**

```bash
cd ~/.claude/skills
git add .
git commit -m "test: verify devops skills pipeline end-to-end integration"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Scenario 1 (Design-stage) — covered in `devops` dispatcher and `devops-analyze`
- [x] Scenario 2 (Code-complete) — covered in `devops` dispatcher and `devops-analyze`
- [x] Scenario 3 (DevOps-review) — covered in `devops` dispatcher, `devops-security`, `devops-report` Before vs After
- [x] Security checklist (8 categories) — covered in `devops-security`
- [x] Security tooling in CI — covered in `devops-security` tool selection + `devops-generate` CI templates
- [x] Local dev environment (Docker Compose) — covered in `devops-generate`
- [x] Team dev environment (layered: Compose + devcontainer + optional k8s) — covered in `devops-generate`
- [x] All 3 CI platforms (GitHub Actions, GitLab CI, CircleCI) — covered in `devops-generate`
- [x] All cloud providers (AWS, GCP, Azure) — covered in `devops-generate` Terraform section
- [x] HTML report with 4 inline SVG diagrams — covered in `devops-report`
- [x] `devops/working/` output folder — covered in `devops-generate`
- [x] `devops/report/index.html` output — covered in `devops-report`
- [x] `security-findings.json` persisted and read by report — covered in both skills

**Placeholder scan:** All steps contain actual SKILL.md content. No "TBD" or "implement later". All file paths are exact.

**Type consistency:** `analysis.json` fields used in `devops-generate` and `devops-report` match the structure written by `devops-analyze`. `security-findings.json` written by `devops-security` and read correctly by `devops-report`.
