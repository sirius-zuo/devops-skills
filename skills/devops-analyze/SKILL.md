---
name: devops-analyze
description: Use when called by the devops dispatcher to analyze a project and gather DevOps configuration choices through guided questions before generating configs
---

# DevOps Analysis & Guided Questions

## Overview

Reads project sources, detects the tech stack, then asks 6 guided questions with smart defaults. Produces `devops/report/analysis.json` consumed by all downstream sub-skills.

## Step 1: Determine Scenario

Scan the working directory to determine which scenario applies:

| Signal | Scenario |
|---|---|
| Source code files present + `devops/` folder with config files | `review` |
| Source code files present, no `devops/` folder | `codebase` |
| Only `.md` docs/design files, no source code | `design` |

**Source code signals:** `.py`, `.ts`, `.tsx`, `.js`, `.mjs`, `.go`, `.java`, `.rb`, `.rs`, `.cs` files outside of `docs/`.

If `devops/report/analysis.json` already exists and contains a `scenario` field, use that value without re-deriving.

## Step 2: What to Read Per Scenario

| Scenario | Read These |
|---|---|
| design | All `.md` files in `docs/`, `design/`, `spec/`; ADRs; any `package.json`, `requirements.txt`, `go.mod`, `pom.xml` for dependency hints |
| codebase | Source file extensions for language; import statements for framework; ORM config files (`database.yml`, `alembic.ini`, `prisma/schema.prisma`); `.env.example`; existing `Dockerfile` or `docker-compose.yml` if present |
| review | Everything above + `.github/workflows/*.yml`; `.gitlab-ci.yml`; `.circleci/config.yml`; `terraform/` or `pulumi/` directories; existing `docker-compose*.yml` |

## Step 3: Stack Detection Rules

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

For `prisma`: read `prisma/schema.prisma` and look for `provider = "postgresql"` → PostgreSQL, `provider = "mysql"` → MySQL. If not found, default to PostgreSQL.

For `sequelize` or `typeorm`: look for database URL patterns in `.env.example` or config files (`postgresql://` → PostgreSQL, `mysql://` → MySQL). Default to PostgreSQL if not found.

For `sqlalchemy` or `django.db`: look for `DATABASE_URL` in `.env.example` or `settings.py` (`postgresql://` → PostgreSQL, `mysql://` → MySQL). Default to PostgreSQL if not found.

For `mongoose`: MongoDB.

For `redis` package import: Redis.

**Cloud detection** (by SDK imports):
- `boto3`, `@aws-sdk` → AWS
- `google-cloud`, `@google-cloud` → GCP
- `@azure` → Azure

**CI/CD detection** (by directory/file presence):
- `.github/workflows/` → GitHub Actions
- `.gitlab-ci.yml` → GitLab CI
- `.circleci/` → CircleCI

**Container/K8s detection**:
- `Dockerfile` present → set `has_dockerfile: true`
- `k8s/` or `kubernetes/` directory → set `has_k8s_manifests: true`
- `docker-compose.yml` or `docker-compose*.yml` present → set `has_existing_compose: true`
- `devops/` directory exists with at least one config file inside → set `has_existing_devops_folder: true`

**External services detection** (by import names):
- `stripe` → Stripe
- `twilio` → Twilio
- `sendgrid` or `@sendgrid` → SendGrid
- `mailgun` → Mailgun
- `sentry` → Sentry
- `datadog` → Datadog

**Project name resolution** (in priority order):
1. `package.json` → `name` field
2. `pyproject.toml` → `[project].name` field
3. `go.mod` → last segment of the module path
4. `pom.xml` → `<artifactId>` field
5. `*.gemspec` → `spec.name` field
6. Fallback: current directory name

## Step 4: Guided Questions

Ask these one at a time, in order. Show the detected default in [brackets]. Wait for the user's answer before asking the next question.

**If the user says "skip", "unsure", "doesn't matter", or gives no clear answer:** use the detected default. If no default was detected, use the first listed option as the fallback. Do not ask again. Exception: for Q5 (secrets management), if a cloud-provider-derived default exists from the mapping below, use that instead of the first listed option.

**Q1: Cloud provider**
> "Cloud provider [detected: X | none detected]: AWS / GCP / Azure / Multi-cloud / Self-hosted"

**Q2: CI/CD platform**
> "CI/CD platform [detected: X | none detected — GitHub Actions recommended if new]: GitHub Actions / GitLab CI / CircleCI"

**Q3: Deployment target**
> "Deployment target [detected: X | none detected]: Containers (ECS/Cloud Run/ACA) / Kubernetes / Serverless (Lambda/Cloud Functions/Azure Functions) / VMs"

**Q4: Database and stateful services**
> "Confirmed stateful services [detected: postgres, redis | none detected]: (confirm the list or add/remove services)"

**Q5: Secrets management**

First resolve the suggested default using this mapping: AWS → AWS Secrets Manager, GCP → GCP Secret Manager, Azure → Azure Key Vault, none → env files (.env.local gitignored).

Then ask:
> "Secrets management [suggested: X]: AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault / Azure Key Vault / env files (.env.local gitignored)"

**Q6: Team size**
> "Team size (affects pipeline complexity): Solo (<5 devs) / Small team (5-20 devs, daily deploys) / Large team (20+ devs, CI on every PR)"

## Step 5: Write Output

Create `devops/report/` directory if it doesn't exist, then write `devops/report/analysis.json`:

```json
{
  "scenario": "design | codebase | review",
  "project_name": "detected via resolution chain above",
  "stack": {
    "language": "TypeScript",
    "framework": "Express",
    "database": ["PostgreSQL", "Redis"],
    "external_services": ["Stripe"]
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

Substitute all values from actual detection and user answers. Do not leave template placeholder values.

Set `has_existing_ci: true` and `existing_ci_platform: "GitHub Actions"` (or whichever was detected) when a CI config file was found.

Confirm to the user: "Analysis complete. Saved to devops/report/analysis.json."
