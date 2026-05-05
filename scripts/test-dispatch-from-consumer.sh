#!/usr/bin/env bash
# Test for the location-independent dispatch wrapper.
#
# Slice 1 — `--dry-run` flag: invoking the wrapper from the clone root with
#   `--dry-run _canary` exits 0 and prints five resolved-path lines to stdout.
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

echo "PASS: dispatch wrapper --dry-run prints five resolved-path lines and exits 0."
