# DevOps Skills Design

**Date:** 2026-04-28  
**Status:** Approved  

---

## Overview

A set of 5 Claude Code skills that establish DevOps setup, workflows, and deployment configurations for a project. The system works across three scenarios — design-stage, code-complete, and DevOps-review — and produces both working config files and an HTML report with diagrams.

---

## Scenarios

| Scenario | Signal | What's available |
|---|---|---|
| 1. Design-stage | No codebase, design/arch docs exist | Architecture docs, ADRs, tech decisions |
| 2. Code-complete | Codebase exists, no `devops/` folder | Full source code, no existing DevOps setup |
| 3. DevOps-review | Codebase + `devops/` folder both exist | Source code + existing DevOps configs |

All three scenarios run the same pipeline; only the inputs differ.

---

## Skill Architecture

**5 skill files in `~/.claude/skills/`:**

```
devops/SKILL.md            ← entry dispatcher
devops-analyze/SKILL.md    ← codebase analysis + guided questions
devops-security/SKILL.md   ← security checklist + CI tool integration
devops-generate/SKILL.md   ← config file generation
devops-report/SKILL.md     ← HTML report + diagrams
```

**Pipeline (same for all scenarios):**

```
User invokes `devops`
        ↓
Scenario detection (codebase? devops/? design docs?)
        ↓
devops-analyze   → analysis.json
        ↓
devops-security  → security findings + tool selections
        ↓
devops-generate  → devops/working/ (all config files)
        ↓
devops-report    → devops/report/index.html
```

---

## Skill 1: `devops` — Entry Dispatcher

**Trigger:** User invokes `/devops` on any project.

**Responsibilities:**
1. Detect which scenario applies by scanning the working directory
2. Announce detected scenario and stack to the user; confirm before proceeding
3. Call sub-skills in sequence: analyze → security → generate → report

**Scenario detection rules:**
- Design docs found, no source code → Scenario 1 (Design-stage)
- Source code found, no `devops/` folder → Scenario 2 (Code-complete)
- Source code + `devops/` both found → Scenario 3 (DevOps-review)
- Ambiguous → ask user to confirm

**Context object passed to all sub-skills:**
```json
{
  "scenario": "design | codebase | review",
  "detected_stack": {
    "language": "",
    "framework": "",
    "database": "",
    "existing_infra": ""
  },
  "source": {
    "design_docs": [],
    "source_files": [],
    "existing_devops_files": []
  }
}
```

---

## Skill 2: `devops-analyze` — Analysis & Guided Questions

**Trigger:** Called by `devops` dispatcher after scenario detection.

**Analysis — what it reads per scenario:**

| Scenario | Sources |
|---|---|
| Design-stage | Architecture docs, ADRs, tech decision records, dependency lists |
| Code-complete | Language/runtime, frameworks, env vars, exposed ports, external service calls, existing Dockerfiles |
| DevOps-review | Everything above + existing CI/CD configs, docker-compose files, infra-as-code |

**Guided questions (asked in order, with detected defaults):**

1. **Cloud provider** — AWS / GCP / Azure / Multi-cloud / Self-hosted  
   *(suggested from SDK imports, e.g., `boto3` → AWS)*
2. **CI/CD platform** — GitHub Actions / GitLab CI / CircleCI  
   *(suggested from `.github/`, `.gitlab-ci.yml` presence)*
3. **Deployment target** — Containers (ECS/Cloud Run/ACA) / Kubernetes / Serverless / VMs  
   *(suggested from existing Dockerfiles or k8s manifests)*
4. **Database / stateful services** — confirmed or detected from ORM config, connection strings
5. **Secrets management** — AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault / env files
6. **Team size / deployment frequency** — affects pipeline complexity

**Output:** `devops/working/analysis.json` — structured record of all detected + confirmed answers, consumed by all downstream sub-skills.

---

## Skill 3: `devops-security` — Security Review & CI Tooling

**Trigger:** Called by `devops` dispatcher after `devops-analyze` completes.

**Runs before `devops-generate`** so security tool choices are baked into generated CI configs, not added after.

**Two outputs:**
1. `devops/working/security-findings.json` — findings with severity, category, and remediation
2. Security tool configs written to `devops/working/ci/` and `devops/working/containers/`

### Security Checklist

| Category | What's checked |
|---|---|
| Secrets & credentials | Hardcoded secrets, `.env` committed, secrets in CI logs |
| Container security | Running as root, `latest` tag, unnecessary packages, exposed ports |
| Network exposure | Public endpoints, missing rate limiting, overly permissive CORS |
| Dependencies | Known CVEs, outdated packages, no lockfile |
| CI/CD pipeline | Unprotected branches, no approval gates for prod, artifact integrity |
| Cloud IAM | Overly broad roles, missing least-privilege, public storage buckets |
| OWASP Top 10 | Reviewed against detected framework |
| Secrets management | Env vars vs secrets manager, rotation policy |

**Severity ratings:** Each finding rated Critical / High / Medium / Low with a specific remediation recommendation.

### Security Tooling Integrated into CI

| Tool | Purpose | CI Stage |
|---|---|---|
| Trivy | Container image CVE scanning | `security-scan` |
| Semgrep / CodeQL | SAST — static code analysis | `lint` |
| Dependabot / Snyk | Dependency vulnerability alerts | PR gate |
| Gitleaks | Secrets detection in commits | pre-commit + CI |
| OWASP ZAP | DAST — dynamic scan against staging | post-deploy staging |

---

## Skill 4: `devops-generate` — Config File Generation

**Trigger:** Called by `devops` dispatcher after `devops-security` completes.

**Reads:** `devops/working/analysis.json` + security findings  
**Writes:** All files to `devops/working/`

### Output Folder Structure

```
devops/working/
├── analysis.json                          ← from devops-analyze
├── security-findings.json                 ← from devops-security
├── ci/
│   ├── github-actions/                    ← .github/workflows/ compatible YAMLs
│   ├── gitlab-ci/                         ← .gitlab-ci.yml
│   └── circleci/                          ← .circleci/config.yml
├── containers/
│   ├── Dockerfile                         ← production, multi-stage
│   ├── Dockerfile.dev                     ← local dev variant
│   └── .dockerignore
├── compose/
│   ├── docker-compose.yml                 ← local dev (single machine)
│   ├── docker-compose.team.yml            ← team dev (extends local)
│   └── docker-compose.prod.yml            ← production-like reference
├── k8s/                                   ← only if Kubernetes selected
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── configmap.yaml
├── infra/                                 ← only if cloud infra selected
│   ├── terraform/                         ← or pulumi/ based on preference
│   └── environments/                      ← dev, staging, prod variable files
├── devcontainer/
│   └── .devcontainer/
│       ├── devcontainer.json
│       └── docker-compose.devcontainer.yml
└── scripts/
    ├── setup-local.sh                     ← one-command local dev setup
    └── setup-team.sh                      ← one-command team dev setup
```

### CI Pipeline Structure

Generated pipeline stages (all platforms):
```
lint → test → build → security-scan → push-image → deploy-staging → [approval] → deploy-prod
```

- Production deploy gated on manual approval
- Separate dev / staging / prod environment configs with scoped secrets and resource limits
- Security tools (Trivy, Semgrep, Gitleaks) injected at appropriate stages

### Dev Environments

**Local dev** (`docker-compose.yml`):
- All services (app + db + cache + queue) on one machine
- Hot-reload enabled
- Dev secrets in `.env.local` (gitignored)
- Single command: `./scripts/setup-local.sh`

**Team dev** (`docker-compose.team.yml` + devcontainer):
- Extends local compose
- Optional `kind`/`k3d` local cluster config for k8s-deploying projects
- VS Code devcontainer for reproducible team dev environment
- Mirrors staging as closely as possible
- Single command: `./scripts/setup-team.sh`

---

## Skill 5: `devops-report` — HTML Report & Diagrams

**Trigger:** Called by `devops` dispatcher after `devops-generate` completes.

**Reads:** `devops/working/analysis.json` + `devops/working/security-findings.json` + all generated files  
**Writes:** `devops/report/index.html` (self-contained, no external dependencies)

### Report Sections

| Section | Content |
|---|---|
| Executive Summary | Detected stack, scenario, key decisions, top 3 security risks |
| Architecture Overview | C4 container-level diagram: services, dependencies, data flow |
| Deployment Architecture | Cloud resources, networking, environment topology |
| CI/CD Workflow | Full pipeline stages, gates, approval steps |
| Dev Environments | Local vs team env topology; setup instructions |
| Generated Artifacts | Table of all files in `devops/working/` with descriptions |
| Security Report | Findings table sorted by severity; remediation checklist |
| Recommendations | Prioritized improvement list |

**Scenario 3 addition:** "Before vs After" section comparing existing config issues with recommended improvements.

### Diagrams

Claude generates each diagram as a Graphviz DOT or Mermaid definition, then renders it to an SVG string and embeds it directly inline in the HTML. No JavaScript runtime required — diagrams are static SVG, fully offline.

- **Architecture diagram** — C4 container level (services + dependencies)
- **Deployment topology** — cloud resources + networking
- **CI/CD pipeline flowchart** — stages, gates, approvals
- **Dev environment topology** — local vs team environment structure

### Report Format

- Single self-contained `index.html` — all CSS inline, diagrams as embedded SVG
- No JavaScript runtime dependencies
- Works offline, shareable without a server
- Prints cleanly to PDF

---

## Output Summary

```
devops/
├── working/               ← all generated config files
│   ├── analysis.json
│   ├── ci/
│   ├── containers/
│   ├── compose/
│   ├── k8s/               ← conditional
│   ├── infra/             ← conditional
│   ├── devcontainer/
│   └── scripts/
└── report/
    └── index.html         ← self-contained HTML report with diagrams
```

---

## Supported Platforms

| Category | Options |
|---|---|
| CI/CD | GitHub Actions, GitLab CI, CircleCI |
| Cloud | AWS, GCP, Azure, Self-hosted |
| Containers | Docker + Docker Compose |
| Orchestration | Kubernetes (EKS / GKE / AKS / self-hosted), ECS, Cloud Run, ACA |
| Serverless | AWS Lambda, GCP Cloud Functions, Azure Functions |
| Infra-as-code | Terraform, Pulumi |
| Secrets | AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault, env files |
| Local k8s | kind, minikube, k3d |

---

## Constraints & Decisions

- All skills stored in `~/.claude/skills/` as personal skills
- Sub-skills are called sequentially by the dispatcher; they do not invoke each other directly
- `devops-security` runs before `devops-generate` so security tooling is baked into generated configs
- Generated configs are templates — the user is expected to review and adapt them to their project
- The HTML report is the primary human-readable output; config files are the actionable artifacts
- The skill system detects defaults but always confirms with the user before generating
