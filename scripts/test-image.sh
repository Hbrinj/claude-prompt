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

# claude CLI refuses --dangerously-skip-permissions when running as root, so the
# image's default user must be non-root. macOS dispatch relies on this default
# (no --user flag is passed); Linux dispatch overrides via --user $(id -u):$(id -g).
DEFAULT_UID="$(docker run --rm "$IMAGE" id -u)"
if [ "$DEFAULT_UID" = "0" ]; then
  echo "FAIL: image default user is root (uid 0); claude --dangerously-skip-permissions will refuse."
  exit 1
fi

echo "PASS: image builds, claude reports a version, default user is non-root (uid=$DEFAULT_UID)."
echo "  $OUTPUT"
