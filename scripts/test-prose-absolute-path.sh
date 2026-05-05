#!/usr/bin/env bash
# Slice 4 test: skill prose + README document the absolute-path fallback
# chain for the dispatch wrapper.
#
# After install.sh, the clone lives at one of:
#   - <project>/.claude/claude-prompt/        (project install)
#   - ~/.claude/claude-prompt/                (global install)
# install.sh does NOT symlink scripts/ into the consumer repo, so the wrapper
# must be invoked via its absolute clone path. This test guards the prose
# from drifting back to the obsolete relative-path idiom.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SKILL="skills/parallel-docker-dispatch.md"
README="README.md"

[ -f "$SKILL" ]  || { echo "FAIL: $SKILL missing"; exit 1; }
[ -f "$README" ] || { echo "FAIL: $README missing"; exit 1; }

# 1. Skill names both install paths.
grep -q '\.claude/claude-prompt/scripts/dispatch-docker-worker\.sh' "$SKILL" \
  || { echo "FAIL: $SKILL does not reference the project-install wrapper path (.claude/claude-prompt/scripts/dispatch-docker-worker.sh)"; exit 1; }
grep -q '~/\.claude/claude-prompt/scripts/dispatch-docker-worker\.sh' "$SKILL" \
  || { echo "FAIL: $SKILL does not reference the global-install wrapper path (~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh)"; exit 1; }

# 2. Skill no longer documents the obsolete relative-path precheck.
if grep -qF '[ -x scripts/dispatch-docker-worker.sh ]' "$SKILL"; then
  echo "FAIL: $SKILL still references the obsolete relative-path precheck"
  exit 1
fi

# 3. README references the global-install absolute invocation path.
grep -q '~/\.claude/claude-prompt/scripts/dispatch-docker-worker\.sh' "$README" \
  || { echo "FAIL: $README does not reference ~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh"; exit 1; }

echo "PASS: skill prose and README document the absolute-path fallback chain."
