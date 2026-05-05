#!/usr/bin/env bash
# Slice 3 test: single-feature dispatch end-to-end via the canary fixture.
# Verifies worktree, branch, commit, CANARY.txt, result file, and container cleanup.
#
# Skips if CLAUDE_CODE_OAUTH_TOKEN is not set.
set -euo pipefail

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "SKIP: CLAUDE_CODE_OAUTH_TOKEN not set; dispatch test cannot run."
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SLUG="_canary"
WT_DIR="$(cd "$REPO_ROOT/.." && pwd)/wt-${SLUG}"
BRANCH="feature/${SLUG}"

cleanup() {
  git worktree remove --force "$WT_DIR" 2>/dev/null || true
  git branch -D "$BRANCH" 2>/dev/null || true
  rm -rf "$WT_DIR" 2>/dev/null || true
}
trap cleanup EXIT
cleanup  # remove leftovers from a previous run

bash "$REPO_ROOT/scripts/dispatch-docker-worker.sh" "$SLUG"

[ -d "$WT_DIR" ]                                || { echo "FAIL: worktree missing at $WT_DIR"; exit 1; }
[ -f "$WT_DIR/CANARY.txt" ]                     || { echo "FAIL: CANARY.txt missing"; exit 1; }
[ -s "$WT_DIR/CANARY.txt" ]                     || { echo "FAIL: CANARY.txt empty"; exit 1; }

COMMITS_AHEAD=$(git -C "$WT_DIR" rev-list --count "main..HEAD")
[ "$COMMITS_AHEAD" -ge 1 ]                      || { echo "FAIL: branch has $COMMITS_AHEAD commits ahead of main"; exit 1; }

[ -f "$WT_DIR/.worker-result.json" ]            || { echo "FAIL: .worker-result.json missing"; exit 1; }
STATUS=$(jq -r .status "$WT_DIR/.worker-result.json")
[ "$STATUS" = "APPROVE" ]                       || { echo "FAIL: result status=$STATUS"; cat "$WT_DIR/.worker-result.json"; exit 1; }

LEFTOVER=$(docker ps -a --filter "name=claude-worker-${SLUG}" --format '{{.Names}}')
[ -z "$LEFTOVER" ]                              || { echo "FAIL: leftover containers: $LEFTOVER"; exit 1; }

echo "PASS: single-feature dispatch produced worktree, commit, CANARY.txt, APPROVE result, clean container state."
echo "  CANARY.txt: $(cat "$WT_DIR/CANARY.txt")"
echo "  commits ahead of main: $COMMITS_AHEAD"
