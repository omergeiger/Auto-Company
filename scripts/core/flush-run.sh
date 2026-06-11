#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$REPO_ROOT/config/auto-company.local.env"

# Guardrail 1: active project config must exist
if [[ ! -f "$ENV_FILE" ]]; then
  echo "WARNING: No active project config at config/auto-company.local.env. Aborting."
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${ACTIVE_PROJECT:-}" ]]; then
  echo "WARNING: ACTIVE_PROJECT is not set in config/auto-company.local.env. Aborting."
  exit 1
fi

PROJECT_DIR="$REPO_ROOT/projects/$ACTIVE_PROJECT"
TRACKING_DIR="$PROJECT_DIR/auto-company-tracking"

# Guardrail 2: project directory and tracking folder must exist
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "WARNING: Project directory $PROJECT_DIR does not exist. Aborting."
  exit 1
fi

if [[ ! -d "$TRACKING_DIR" ]]; then
  echo "WARNING: Tracking folder $TRACKING_DIR does not exist. Artifacts may not have been synced. Aborting."
  exit 1
fi

# Guardrail 3: project directory must be a git repo
if [[ ! -d "$PROJECT_DIR/.git" ]]; then
  echo "WARNING: $PROJECT_DIR is not a git repository. Aborting."
  exit 1
fi

# Guardrail 4: project repo must have a clean working tree
if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain)" ]]; then
  echo "WARNING: $ACTIVE_PROJECT has uncommitted changes. Commit and push all artifacts before flushing. Aborting."
  exit 1
fi

# Guardrail 5: project repo must have an upstream and no unpushed commits
UPSTREAM="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$UPSTREAM" ]]; then
  echo "WARNING: $ACTIVE_PROJECT has no upstream remote configured. Cannot verify sync status. Aborting."
  exit 1
fi

UNPUSHED="$(git -C "$PROJECT_DIR" log '@{u}..HEAD' --oneline 2>/dev/null || true)"
if [[ -n "$UNPUSHED" ]]; then
  echo "WARNING: $ACTIVE_PROJECT has unpushed commits. Push to remote before flushing. Aborting."
  exit 1
fi

# All guardrails passed
echo "Guardrails passed. Flushing run artifacts for project: $ACTIVE_PROJECT"

# Loop state files
rm -f "$REPO_ROOT/.auto-loop-state"
rm -f "$REPO_ROOT/.auto-loop.pid"
echo "  - loop state cleared"

# Logs
rm -f "$REPO_ROOT/logs/auto-loop.log"
rm -f "$REPO_ROOT/logs"/cycle-*.log
echo "  - logs cleared"

# Agent outputs under docs/ (files only, preserve directory structure)
find "$REPO_ROOT/docs" -type f ! -name '.gitkeep' -delete
echo "  - docs cleared"

# Consensus memories
rm -f "$REPO_ROOT/memories/consensus.md"
rm -f "$REPO_ROOT/memories/consensus.md.bak"
rm -f "$REPO_ROOT/memories"/consensus-step-*.md
echo "  - memories cleared"

# Active project config
rm -f "$ENV_FILE"
echo "  - active project config cleared"

echo "Flush complete. Ready for next project."
