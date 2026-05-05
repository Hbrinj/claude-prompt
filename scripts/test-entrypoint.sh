#!/usr/bin/env bash
# Slice 2 test: entrypoint reads /workspace/tasks/<slug>.md, runs claude --print,
# and produces /workspace/.worker-result.json with the agreed schema.
#
# Skips if CLAUDE_CODE_OAUTH_TOKEN is not set in the environment (cannot make
# real API calls without it).
set -euo pipefail

if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "SKIP: CLAUDE_CODE_OAUTH_TOKEN not set; cannot run entrypoint smoke test."
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="claude-worker:test"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker build -t "$IMAGE" "$REPO_ROOT/docker/" >/dev/null
fi

TMP_WT=$(mktemp -d)
trap 'rm -rf "$TMP_WT"' EXIT
mkdir -p "$TMP_WT/tasks"
cat > "$TMP_WT/tasks/_smoke.md" <<'EOF'
# _smoke

Smoke fixture for entrypoint slice. Do not edit other files.

## Steps
1. Use the Write tool to create `/workspace/.worker-result.json` with exactly
   this content (a single JSON object):
   `{"status":"APPROVE","branch":null,"commits":[],"summary":"smoke ok","blockers":[]}`
2. Stop.
EOF

docker run --rm \
  -v "$TMP_WT:/workspace" \
  -e SLUG=_smoke \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  "$IMAGE" /entrypoint.sh

RESULT="$TMP_WT/.worker-result.json"
if [ ! -f "$RESULT" ]; then
  echo "FAIL: no .worker-result.json produced"
  exit 1
fi

STATUS=$(jq -r .status "$RESULT")
if [ "$STATUS" != "APPROVE" ]; then
  echo "FAIL: expected status APPROVE, got: $STATUS"
  cat "$RESULT"
  exit 1
fi

for f in status branch commits summary blockers; do
  if ! jq -e "has(\"$f\")" "$RESULT" >/dev/null; then
    echo "FAIL: result missing required field: $f"
    cat "$RESULT"
    exit 1
  fi
done

echo "PASS: entrypoint produced valid result file with status=APPROVE."
cat "$RESULT"
