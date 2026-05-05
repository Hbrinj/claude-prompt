#!/usr/bin/env bash
# Slice 1 test: build claude-worker image and verify `claude --version` runs inside.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="claude-worker:test"

cd "$REPO_ROOT"

docker build -t "$IMAGE" docker/ >/dev/null

OUTPUT="$(docker run --rm "$IMAGE" claude --version)"
if ! grep -qE 'Claude Code|claude code|claude-code' <<<"$OUTPUT"; then
  echo "FAIL: 'claude --version' did not look like a Claude Code version string."
  echo "Got: $OUTPUT"
  exit 1
fi

echo "PASS: image builds and claude reports a version."
echo "  $OUTPUT"
