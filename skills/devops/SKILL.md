---
name: devops
description: Use when a user asks to set up CI/CD, Dockerize a project, add a deployment pipeline, configure GitHub Actions / GitLab CI / CircleCI, review existing DevOps config, or says "we have no CI", "no pipeline", "need to containerize this", or "help with deployments". Proactively suggest when source code is present but no devops/ folder or CI config files exist.
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

**Design docs signals:** files named `*.md` containing architecture, ADR, design decision keywords; files in `docs/`, `design/`, `spec/` folders; no `.py`/`.ts`/`.js`/`.go`/`.java`/`.rb`/`.rs`/`.cs` source files present.

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
Detected scenario: [show only the detected scenario name, e.g. "2. Code-complete"]
Detected stack: [language] + [framework] | DB: [database] | Cloud: [cloud or "none detected"]

I will now:
1. Analyze the project and ask a few targeted questions → devops/report/analysis.json
2. Run a security review → devops/report/security-findings.json
3. Generate config files → devops/working/
4. Produce an HTML report → devops/report/index.html

Proceed? (yes/no)
```

Wait for confirmation before proceeding.
If the user declines, summarize the detected scenario and stack, and stop. Do not generate any files.

## Pipeline

Call these sub-skills in order. State flows through files on disk — `devops/report/analysis.json` (written by devops-analyze) and `devops/report/security-findings.json` (written by devops-security) — not through Skill tool args. Each sub-skill reads the files left by the previous one.

1. Invoke `devops-analyze`
2. Invoke `devops-security`
3. Invoke `devops-generate`
4. Invoke `devops-report`

## Output Locations

- Config files: `devops/working/` (relative to project root)
- JSON data files: `devops/report/` (analysis.json, security-findings.json)
- HTML report: `devops/report/index.html`
- Create both directories if they don't exist.
