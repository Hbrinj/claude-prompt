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

# Slug must be safe to use in file paths, branch names, container names, and
# the agent prompt. Reject anything outside [A-Za-z0-9_-].
if ! [[ "$SLUG" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "ERROR: invalid slug '$SLUG' (allowed: A-Za-z0-9 _ -)." >&2
  exit 2
fi

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
  # Map host uid/gid into the container so files in the bind-mounted worktree
  # are owned by the host user, not root. The unmapped uid has no /etc/passwd
  # entry, so we also have to provide HOME and an explicit git identity, and
  # relocate GOPATH from the Dockerfile default (/root/go) to a writable path.
  USER_FLAG=(
    --user "$(id -u):$(id -g)"
    -e HOME=/tmp
    -e GOPATH=/tmp/go
    -e GIT_AUTHOR_NAME=claude-worker
    -e GIT_AUTHOR_EMAIL=claude-worker@local
    -e GIT_COMMITTER_NAME=claude-worker
    -e GIT_COMMITTER_EMAIL=claude-worker@local
  )
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
  # Stop the container BEFORE writing the result file so a still-running
  # agent cannot overwrite it after we synthesise BLOCKED.
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  # Brief settle to let docker release the bind mount.
  sleep 1
  jq -n --arg branch "$BRANCH" \
    '{status:"BLOCKED",branch:$branch,commits:[],summary:"worker timed out",blockers:["wall-clock timeout"]}' \
    > "$WT_DIR/.worker-result.json"
  echo "WORKER TIMEOUT: $SLUG (worktree: $WT_DIR)"
  exit 1
fi

if [ ! -f "$WT_DIR/.worker-result.json" ]; then
  jq -n --arg branch "$BRANCH" --arg ec "$EXIT_CODE" \
    '{status:"BLOCKED",branch:$branch,commits:[],summary:"worker missing result",blockers:["worker exited \($ec) without writing .worker-result.json"]}' \
    > "$WT_DIR/.worker-result.json"
  echo "WORKER MISSING RESULT: $SLUG (exit=$EXIT_CODE; worktree: $WT_DIR)"
  exit 1
fi

STATUS=$(jq -r .status "$WT_DIR/.worker-result.json")
echo "WORKER ${STATUS}: $SLUG (worktree: $WT_DIR)"

[ "$STATUS" = "APPROVE" ]
