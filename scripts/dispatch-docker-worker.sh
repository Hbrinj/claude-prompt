#!/usr/bin/env bash
# Dispatch one feature to a docker worker.
#
# Usage: scripts/dispatch-docker-worker.sh [--dry-run] <slug> [base-branch]
#
# Flags:
#   --dry-run  Print resolved REPO_ROOT, SCRIPT_DIR, BUILD_CONTEXT, WT_DIR,
#              and BRANCH on stable lines and exit 0 without touching docker.
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

DRY_RUN=false
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  else
    ARGS+=("$arg")
  fi
done
# Restore positional args without the consumed flag.
set -- "${ARGS[@]+"${ARGS[@]}"}"

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
BUILD_CONTEXT="$SCRIPT_DIR/../docker/"
cd "$REPO_ROOT"

WT_DIR="$(cd "$REPO_ROOT/.." && pwd)/wt-${SLUG}"
BRANCH="feature/${SLUG}"

if [ "$DRY_RUN" = true ]; then
  printf 'REPO_ROOT=%s\n' "$REPO_ROOT"
  printf 'SCRIPT_DIR=%s\n' "$SCRIPT_DIR"
  printf 'BUILD_CONTEXT=%s\n' "$BUILD_CONTEXT"
  printf 'WT_DIR=%s\n' "$WT_DIR"
  printf 'BRANCH=%s\n' "$BRANCH"
  exit 0
fi

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
  docker build -t "$IMAGE" "$BUILD_CONTEXT" >/dev/null
fi

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
  # entry, so we also have to provide HOME and relocate GOPATH to a writable
  # path. Git author/committer identity is set unconditionally below.
  USER_FLAG=(
    --user "$(id -u):$(id -g)"
    -e HOME=/tmp
    -e GOPATH=/tmp/go
  )
fi

# Bind-mount the host's .git at the same absolute path inside the container.
# The worktree's .git file references <REPO_ROOT>/.git/worktrees/<slug> as an
# absolute path; mounting that exact path makes in-container git resolve it
# transparently, so commits land on feature/<slug> on the host repo instead of
# the agent improvising a fresh `git init` inside /workspace.
set +e
timeout "$TIMEOUT_SECONDS" docker run --rm \
  --name "$CONTAINER_NAME" \
  "${USER_FLAG[@]}" \
  -v "$WT_DIR:/workspace" \
  -v "$REPO_ROOT/.git:$REPO_ROOT/.git" \
  -e SLUG="$SLUG" \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e GIT_AUTHOR_NAME=claude-worker \
  -e GIT_AUTHOR_EMAIL=claude-worker@local \
  -e GIT_COMMITTER_NAME=claude-worker \
  -e GIT_COMMITTER_EMAIL=claude-worker@local \
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
