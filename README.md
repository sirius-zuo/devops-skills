# DevOps Skills

AI agent skills for setting up CI/CD pipelines, security review, Docker, Kubernetes, Terraform, and deployment workflows — for any project, across three scenarios.

## What it does

Run `/devops` in any project directory. The agent detects which scenario applies and walks you through the full setup:

| Scenario | When | What you get |
|---|---|---|
| **Design-stage** | You have architecture docs but no code yet | DevOps recommendations and config templates based on the planned stack |
| **Code-complete** | You have a codebase but no DevOps setup | Full CI/CD pipelines, Dockerfiles, secrets management, Terraform |
| **Config review** | You have code and existing DevOps configs | Security audit, gap analysis, improved configs, before/after comparison |

### Output

Output is split between `devops/working/` (generated configs) and `devops/report/` (data files + HTML report) at your project root:

```
devops/
├── working/
│   ├── containers/
│   │   ├── Dockerfile             — multi-stage production image
│   │   └── Dockerfile.dev         — dev with hot-reload
│   ├── compose/
│   │   ├── docker-compose.yml     — local dev stack
│   │   ├── docker-compose.team.yml
│   │   └── docker-compose.prod.yml
│   ├── ci/
│   │   ├── github-actions/ci.yml
│   │   ├── gitlab-ci/.gitlab-ci.yml
│   │   └── circleci/.circleci/config.yml
│   ├── k8s/                       — Kubernetes manifests (if selected)
│   ├── infra/terraform/           — Terraform for AWS, GCP, or Azure (if selected)
│   ├── devcontainer/              — VS Code DevContainer
│   └── scripts/
│       ├── setup-local.sh
│       └── setup-team.sh
└── report/
    ├── analysis.json              — detected stack + your choices
    ├── security-findings.json     — security audit results
    └── index.html                 — HTML report with architecture diagrams
```

### Supported stacks

**Languages:** TypeScript, JavaScript, Python, Go, Java, Ruby, Rust, C#

**Cloud:** AWS (ECS Fargate), GCP (Cloud Run), Azure (Container Apps), Kubernetes, Self-hosted

**CI/CD:** GitHub Actions, GitLab CI, CircleCI (all three generated regardless of choice)

**Databases:** PostgreSQL, MySQL, MongoDB, Redis (auto-detected)

**Security tools auto-selected:** Trivy, Semgrep, Gitleaks, CodeQL, Dependabot, Snyk, OWASP ZAP

---

## Installation

### Claude Code (recommended — full skill invocation support)

**Global install** (skills available in every project):

```bash
git clone https://github.com/your-username/devops-skills.git
cd devops-skills
./install.sh
```

**Project-local install** (skills available only in current project):

```bash
./install.sh --local
```

**Verify:**
```bash
# In Claude Code, type:
/devops
```

### Cursor

Cursor does not have named slash-command skills. To use these instructions in Cursor:

1. Copy the skill content you want into `.cursor/rules/devops.mdc` in your project:

```bash
cat skills/devops/SKILL.md skills/devops-analyze/SKILL.md \
    skills/devops-security/SKILL.md skills/devops-generate/SKILL.md \
    skills/devops-report/SKILL.md > .cursor/rules/devops.mdc
```

2. In Cursor Agent mode, prompt: *"Follow the devops skill instructions to set up DevOps for this project."*

### Windsurf

Similar to Cursor. Add the skill content as a Windsurf rule:

```bash
mkdir -p .windsurf/rules
cat skills/devops/SKILL.md skills/devops-analyze/SKILL.md \
    skills/devops-security/SKILL.md skills/devops-generate/SKILL.md \
    skills/devops-report/SKILL.md > .windsurf/rules/devops.md
```

Then prompt Cascade: *"Follow the devops workflow instructions in the rules to set up DevOps for this project."*

### GitHub Copilot

Add to `.github/copilot-instructions.md` in your project:

```bash
cat skills/devops/SKILL.md skills/devops-analyze/SKILL.md \
    skills/devops-security/SKILL.md skills/devops-generate/SKILL.md \
    skills/devops-report/SKILL.md >> .github/copilot-instructions.md
```

Then in Copilot Chat: *"Set up DevOps for this project following the instructions."*

### OpenAI Codex CLI

Add to `AGENTS.md` in your project root, or to `~/.codex/instructions.md` for global use:

```bash
cat skills/devops/SKILL.md skills/devops-analyze/SKILL.md \
    skills/devops-security/SKILL.md skills/devops-generate/SKILL.md \
    skills/devops-report/SKILL.md >> AGENTS.md
```

### Gemini CLI

Add to `GEMINI.md` in your project root:

```bash
cat skills/devops/SKILL.md skills/devops-analyze/SKILL.md \
    skills/devops-security/SKILL.md skills/devops-generate/SKILL.md \
    skills/devops-report/SKILL.md >> GEMINI.md
```

---

## How it works

Five skills run in sequence. Each produces an output file the next one reads — state flows through files on disk, not through the AI's memory.

```
/devops  (dispatcher)
   ↓
devops-analyze    →  devops/report/analysis.json
   ↓
devops-security   →  devops/report/security-findings.json
                      devops/working/ci/security/.gitleaks.toml
   ↓
devops-generate   →  devops/working/** (all config files)
   ↓
devops-report     →  devops/report/index.html
```

The dispatcher detects which scenario applies (design / code-complete / config-review), confirms with you, then calls each sub-skill.

---

## Skills

| File | Purpose |
|---|---|
| `skills/devops/SKILL.md` | Entry dispatcher — detects scenario, calls sub-skills |
| `skills/devops-analyze/SKILL.md` | Reads codebase, asks 6 guided questions, writes `analysis.json` |
| `skills/devops-security/SKILL.md` | Runs 8-category security checklist, selects CI security tools |
| `skills/devops-generate/SKILL.md` | Generates all config files (Dockerfiles, CI/CD, Terraform, K8s) |
| `skills/devops-report/SKILL.md` | Produces HTML report with embedded SVG architecture diagrams |

---

## Updating

```bash
git pull
./install.sh        # re-run to update installed skills
```

## License

MIT
