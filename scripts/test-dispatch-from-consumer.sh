#!/usr/bin/env bash
# Test for the location-independent dispatch wrapper.
#
# Slice 1 — `--dry-run` flag: invoking the wrapper from the clone root with
#   `--dry-run _canary` exits 0 and prints five resolved-path lines to stdout.
# Slice 2 — REPO_ROOT from `git rev-parse --show-toplevel`: invoking from a
#   temp consumer git repo via absolute path resolves REPO_ROOT to the
#   consumer, not the clone.
# Slice 3 — SCRIPT_DIR for build context: BUILD_CONTEXT always points inside
#   the clone regardless of caller CWD.
#
# This test is dry-run only; it does NOT require docker or
# CLAUDE_CODE_OAUTH_TOKEN.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/dispatch-docker-worker.sh"

[ -x "$WRAPPER" ] || { echo "FAIL: wrapper not executable at $WRAPPER"; exit 1; }

# ---------------------------------------------------------------------------
# Slice 1 — from the clone root, `--dry-run _canary` exits 0 with five
# resolved-path lines.
# ---------------------------------------------------------------------------
cd "$REPO_ROOT"
OUT=$(bash "$WRAPPER" --dry-run _canary)

echo "$OUT" | grep -q "^REPO_ROOT=${REPO_ROOT}$" \
  || { echo "FAIL: dry-run from clone did not print REPO_ROOT=$REPO_ROOT"; echo "OUTPUT:"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "^SCRIPT_DIR=" \
  || { echo "FAIL: dry-run missing SCRIPT_DIR= line"; echo "OUTPUT:"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "^BUILD_CONTEXT=" \
  || { echo "FAIL: dry-run missing BUILD_CONTEXT= line"; echo "OUTPUT:"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "^WT_DIR=" \
  || { echo "FAIL: dry-run missing WT_DIR= line"; echo "OUTPUT:"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "^BRANCH=feature/_canary$" \
  || { echo "FAIL: dry-run missing BRANCH=feature/_canary"; echo "OUTPUT:"; echo "$OUT"; exit 1; }

# ---------------------------------------------------------------------------
# Slice 2 — invoke from temp consumer git repo via absolute path; REPO_ROOT
# resolves to the consumer, not the clone.
# ---------------------------------------------------------------------------
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

CONSUMER="$TMP/consumer"
mkdir -p "$CONSUMER/tasks"
git -C "$CONSUMER" init -q
git -C "$CONSUMER" -c user.email=test@test -c user.name=test \
  commit -q --allow-empty -m init

# Use a slug whose .md exists ONLY in the consumer (not in the clone), so the
# assertion is unambiguous.
cat > "$CONSUMER/tasks/_consumer_only.md" <<'EOF'
# _consumer_only

Test fixture used by scripts/test-dispatch-from-consumer.sh — dry-run only.
EOF

cd "$CONSUMER"
OUT=$(bash "$WRAPPER" --dry-run _consumer_only)

# `git rev-parse --show-toplevel` may resolve symlinks (e.g. /tmp -> /private/tmp
# on macOS). Compute the same canonical form for comparison.
EXPECTED_REPO=$(git -C "$CONSUMER" rev-parse --show-toplevel)

echo "$OUT" | grep -q "^REPO_ROOT=${EXPECTED_REPO}$" \
  || { echo "FAIL: dry-run from consumer did not print REPO_ROOT=$EXPECTED_REPO"; echo "OUTPUT:"; echo "$OUT"; exit 1; }

# ---------------------------------------------------------------------------
# Slice 3 — BUILD_CONTEXT must point inside the CLONE, not the consumer.
# ---------------------------------------------------------------------------
echo "$OUT" | grep -q "^BUILD_CONTEXT=${REPO_ROOT}/" \
  || { echo "FAIL: BUILD_CONTEXT from consumer did not point inside clone $REPO_ROOT"; echo "OUTPUT:"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -qv "^BUILD_CONTEXT=${EXPECTED_REPO}/" \
  || { echo "FAIL: BUILD_CONTEXT from consumer pointed at consumer $EXPECTED_REPO"; echo "OUTPUT:"; echo "$OUT"; exit 1; }

echo "PASS: dispatch wrapper resolves REPO_ROOT from caller CWD and BUILD_CONTEXT from script location."
