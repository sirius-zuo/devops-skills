#!/usr/bin/env bash
# install.sh — DevOps Skills installer
#
# Usage:
#   ./install.sh              # install globally for Claude Code (~/.claude/skills/)
#   ./install.sh --local      # install project-locally (.claude/skills/ in CWD)
#   ./install.sh --dir <path> # install to a custom directory

set -e

SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
SKILLS=(devops devops-analyze devops-security devops-generate devops-report)

LOCAL=false
CUSTOM_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) LOCAL=true; shift ;;
    --dir) CUSTOM_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -n "$CUSTOM_DIR" ]]; then
  TARGET="$CUSTOM_DIR"
elif [[ "$LOCAL" == "true" ]]; then
  TARGET="$(pwd)/.claude/skills"
else
  TARGET="$HOME/.claude/skills"
fi

echo "Installing DevOps Skills → $TARGET"
mkdir -p "$TARGET"

for skill in "${SKILLS[@]}"; do
  src="$SKILLS_DIR/$skill"
  dst="$TARGET/$skill"
  if [[ -d "$dst" ]]; then
    echo "  Updating  $skill"
  else
    echo "  Installing $skill"
  fi
  mkdir -p "$dst"
  cp "$src/SKILL.md" "$dst/SKILL.md"
done

echo ""
echo "Done. Skills available:"
for skill in "${SKILLS[@]}"; do
  echo "  /$skill"
done
echo ""
echo "Start with: /devops"
