#!/usr/bin/env bash
# Dispatch one feature to a docker worker.
#
# Usage: scripts/dispatch-docker-worker.sh <slug> [base-branch]
#
# Required env:
#   CLAUDE_CODE_OAUTH_TOKEN — claude auth token, forwarded to the container.
#
# Optional env:
#   WORKER_TIMEOUT  — wall-clock seconds (default: 1800).
#   WORKER_IMAGE    — image tag (default: claude-worker:test).
#
# Produces:
#   ../wt-<slug>/                    — git worktree on branch feature/<slug>
#   ../wt-<slug>/.worker-result.json — structured result file
set -euo pipefail

SLUG="${1:?slug required}"
BASE="${2:-main}"
TIMEOUT_SECONDS="${WORKER_TIMEOUT:-1800}"
IMAGE="${WORKER_IMAGE:-claude-worker:test}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "ERROR: CLAUDE_CODE_OAUTH_TOKEN env var is required." >&2
  exit 2
fi

if [ ! -f "tasks/${SLUG}.md" ]; then
  echo "ERROR: tasks/${SLUG}.md not found." >&2
  exit 2
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE …"
  docker build -t "$IMAGE" "$REPO_ROOT/docker/" >/dev/null
fi

WT_DIR="$(cd "$REPO_ROOT/.." && pwd)/wt-${SLUG}"
BRANCH="feature/${SLUG}"
CONTAINER_NAME="claude-worker-${SLUG}-$$"

if [ ! -d "$WT_DIR" ]; then
  if git rev-parse --verify --quiet "$BRANCH" >/dev/null; then
    git worktree add "$WT_DIR" "$BRANCH"
  else
    git worktree add "$WT_DIR" -b "$BRANCH" "$BASE"
  fi
fi

USER_FLAG=()
if [ "$(uname -s)" = "Linux" ]; then
  USER_FLAG=(--user "$(id -u):$(id -g)")
fi

set +e
timeout "$TIMEOUT_SECONDS" docker run --rm \
  --name "$CONTAINER_NAME" \
  "${USER_FLAG[@]}" \
  -v "$WT_DIR:/workspace" \
  -e SLUG="$SLUG" \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  "$IMAGE"
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 124 ]; then
  jq -n --arg branch "$BRANCH" \
    '{status:"BLOCKED",branch:$branch,commits:[],summary:"worker timed out",blockers:["wall-clock timeout"]}' \
    > "$WT_DIR/.worker-result.json"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  echo "WORKER TIMEOUT: $SLUG (worktree: $WT_DIR)"
  exit 1
fi

if [ ! -f "$WT_DIR/.worker-result.json" ]; then
  echo "WORKER MISSING RESULT: $SLUG (exit=$EXIT_CODE; worktree: $WT_DIR)"
  exit 1
fi

STATUS=$(jq -r .status "$WT_DIR/.worker-result.json")
echo "WORKER ${STATUS}: $SLUG (worktree: $WT_DIR)"

[ "$STATUS" = "APPROVE" ]
