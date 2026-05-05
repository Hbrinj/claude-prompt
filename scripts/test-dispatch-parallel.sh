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

cleanup() {
  for s in "${SLUGS[@]}"; do
    git worktree remove --force "$REPO_ROOT/../wt-$s" 2>/dev/null || true
    git branch -D "feature/$s" 2>/dev/null || true
    rm -rf "$REPO_ROOT/../wt-$s" 2>/dev/null || true
    rm -f "$REPO_ROOT/tasks/$s.md"
  done
  docker ps -a --filter "name=claude-worker-_canary_" -q | xargs -r docker rm -f >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

# Generate canary fixtures
for s in "${SLUGS[@]}"; do
  cp "$REPO_ROOT/tasks/_canary.md" "$REPO_ROOT/tasks/$s.md"
  # Make CANARY.txt name unique per slug to avoid file collisions in any shared
  # state (worktrees are isolated, but be explicit).
  sed -i.bak "s/CANARY.txt/CANARY-${s}.txt/g" "$REPO_ROOT/tasks/$s.md"
  rm "$REPO_ROOT/tasks/$s.md.bak"
done

# Concurrency monitor (background): every 0.5s record the count of running
# claude-worker containers. We assert peak <= CAP at the end.
PEAK_FILE=$(mktemp)
echo 0 > "$PEAK_FILE"
(
  while true; do
    count=$(docker ps --filter "name=claude-worker-_canary_" -q | wc -l | tr -d ' ')
    peak=$(cat "$PEAK_FILE")
    if [ "$count" -gt "$peak" ]; then echo "$count" > "$PEAK_FILE"; fi
    sleep 0.5
  done
) &
MONITOR_PID=$!
trap 'kill $MONITOR_PID 2>/dev/null || true; cleanup' EXIT

# Fan out with semaphore of $CAP using a FIFO. Each free slot is one token.
SEM=$(mktemp -u)
mkfifo "$SEM"
exec 3<>"$SEM"
rm "$SEM"
for ((i=0; i<CAP; i++)); do echo >&3; done

PIDS=()
for s in "${SLUGS[@]}"; do
  read -u 3
  ( bash "$REPO_ROOT/scripts/dispatch-docker-worker.sh" "$s"; echo >&3 ) &
  PIDS+=($!)
done

EXIT_CODE=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || EXIT_CODE=1
done

kill $MONITOR_PID 2>/dev/null || true

PEAK=$(cat "$PEAK_FILE")
rm -f "$PEAK_FILE"

[ "$EXIT_CODE" -eq 0 ]                            || { echo "FAIL: at least one worker did not return APPROVE"; exit 1; }
[ "$PEAK" -le "$CAP" ]                            || { echo "FAIL: peak concurrent containers $PEAK > cap $CAP"; exit 1; }

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
