#!/usr/bin/env bash
# Slice 5 test: parallel dispatch of 4 canary copies through a host-side
# semaphore of 3. Verifies the wrapper is safe to invoke concurrently and
# that, while running, the host never sees more than 3 claude-worker
# containers simultaneously.
#
# Skips if CLAUDE_CODE_OAUTH_TOKEN is not set.
set -euo pipefail

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "SKIP: CLAUDE_CODE_OAUTH_TOKEN not set; parallel dispatch test cannot run."
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SLUGS=(_canary_a _canary_b _canary_c _canary_d)
CAP=3

EVENT_LOG=$(mktemp)

cleanup() {
  for s in "${SLUGS[@]}"; do
    git worktree remove --force "$REPO_ROOT/../wt-$s" 2>/dev/null || true
    git branch -D "feature/$s" 2>/dev/null || true
    rm -rf "$REPO_ROOT/../wt-$s" 2>/dev/null || true
    rm -f "$REPO_ROOT/tasks/$s.md"
  done
  docker ps -a --filter "name=claude-worker-_canary_" -q | xargs -r docker rm -f >/dev/null 2>&1 || true
  rm -f "$EVENT_LOG"
}
trap cleanup EXIT
cleanup
: > "$EVENT_LOG"  # recreate after cleanup wiped it

# Generate canary fixtures with unique CANARY-<slug>.txt names so worktrees stay
# distinct in any post-hoc inspection.
for s in "${SLUGS[@]}"; do
  cp "$REPO_ROOT/tasks/_canary.md" "$REPO_ROOT/tasks/$s.md"
  sed -i.bak "s/CANARY.txt/CANARY-${s}.txt/g" "$REPO_ROOT/tasks/$s.md"
  rm "$REPO_ROOT/tasks/$s.md.bak"
done

# Concurrency assertion strategy: instead of polling `docker ps` (which can
# miss sub-sample-interval bursts), every dispatch invocation writes a START
# line before docker run and an END line after. Lines are appended atomically
# under flock; post-hoc we walk the log in order and track peak depth.
log_event() {
  local kind="$1" slug="$2"
  ( flock 9; printf '%s %s\n' "$kind" "$slug" >> "$EVENT_LOG" ) 9>"${EVENT_LOG}.lock"
}
export -f log_event
export EVENT_LOG

# Fan out with semaphore of $CAP using a FIFO. Each free slot is one token.
SEM=$(mktemp -u)
mkfifo "$SEM"
exec 3<>"$SEM"
rm "$SEM"
for ((i=0; i<CAP; i++)); do echo >&3; done

PIDS=()
for s in "${SLUGS[@]}"; do
  read -u 3
  (
    log_event START "$s"
    bash "$REPO_ROOT/scripts/dispatch-docker-worker.sh" "$s"
    rc=$?
    log_event END "$s"
    echo >&3
    exit "$rc"
  ) &
  PIDS+=($!)
done

EXIT_CODE=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || EXIT_CODE=1
done

# Peak concurrent depth from the lifecycle log (exact, not sampled).
PEAK=$(awk '{ if ($1=="START") d++; else if ($1=="END") d--; if (d>m) m=d } END { print m+0 }' "$EVENT_LOG")
rm -f "${EVENT_LOG}.lock"

[ "$EXIT_CODE" -eq 0 ]                            || { echo "FAIL: at least one worker did not return APPROVE"; exit 1; }
[ "$PEAK" -le "$CAP" ]                            || { echo "FAIL: peak concurrent dispatches $PEAK > cap $CAP"; cat "$EVENT_LOG"; exit 1; }

# Verify all 4 worktrees, branches, result files
for s in "${SLUGS[@]}"; do
  WT="$REPO_ROOT/../wt-$s"
  [ -d "$WT" ]                                    || { echo "FAIL: worktree missing for $s"; exit 1; }
  [ -f "$WT/CANARY-$s.txt" ]                      || { echo "FAIL: CANARY-$s.txt missing in $s worktree"; exit 1; }
  [ -f "$WT/.worker-result.json" ]                || { echo "FAIL: result file missing for $s"; exit 1; }
  STATUS=$(jq -r .status "$WT/.worker-result.json")
  [ "$STATUS" = "APPROVE" ]                       || { echo "FAIL: $s status=$STATUS"; exit 1; }
done

echo "PASS: 4 canary workers ran through cap-of-3 semaphore. Peak concurrent = $PEAK."
