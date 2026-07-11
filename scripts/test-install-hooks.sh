#!/usr/bin/env bash
# Slice 3 test: install.sh wires the hooks symlink and prints the settings.json
# snippet in GLOBAL mode only. Dry-run throughout — the real ~/.claude is never
# touched (HOME is overridden to a fixture).
#
# install.sh prompts on /dev/tty in several paths; the fixtures below avoid
# every prompt: an existing "clone" (update path, no clone prompt), existing
# symlink targets, exactly one SYSTEM_PROMPT*.md (no prompt picker), and a
# missing CLAUDE.md (created without asking).
#
# Requires: git.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"

[ -f "$INSTALL" ] || { echo "FAIL: $INSTALL missing"; exit 1; }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# ── Global-mode fixture ─────────────────────────────────────────────────────
FAKE_HOME="$TMP/home"
CLONE="$FAKE_HOME/.claude/claude-prompt"
mkdir -p "$CLONE/.git" "$CLONE/agents" "$CLONE/skills" "$CLONE/scripts/hooks"
printf '# stub prompt\n' > "$CLONE/SYSTEM_PROMPT.md"
RUN_DIR="$TMP/rundir"
mkdir -p "$RUN_DIR"

GLOBAL_OUT="$(cd "$RUN_DIR" && HOME="$FAKE_HOME" bash "$INSTALL" --global --dry-run)" \
  || { echo "FAIL: install.sh --global --dry-run exited nonzero"; exit 1; }

# 1. Global mode plans the hooks symlink ~/.claude/hooks → <clone>/scripts/hooks.
printf '%s' "$GLOBAL_OUT" | grep -qF \
  "Would create hooks symlink: ${FAKE_HOME}/.claude/hooks → ${CLONE}/scripts/hooks" \
  || { echo "FAIL: global dry-run did not plan the hooks symlink"; printf '%s\n' "$GLOBAL_OUT"; exit 1; }
echo "  ok: global mode plans hooks symlink"

# 2. Global mode prints the settings.json wiring snippet (all three guards).
for needle in \
  '"PreToolUse"' \
  '"matcher": "Edit|Write|NotebookEdit"' \
  '"matcher": "Bash"' \
  'guard-main-edit.sh' \
  'guard-push-main.sh' \
  'guard-push-review.sh'; do
  printf '%s' "$GLOBAL_OUT" | grep -qF "$needle" \
    || { echo "FAIL: settings.json snippet missing: $needle"; printf '%s\n' "$GLOBAL_OUT"; exit 1; }
done
echo "  ok: global mode prints the settings.json hooks snippet"

# 3. install.sh must not claim to edit settings.json itself.
if printf '%s' "$GLOBAL_OUT" | grep -qiE '(writing|updating|editing) settings\.json'; then
  echo "FAIL: install.sh claims to edit settings.json"; exit 1
fi
echo "  ok: install.sh does not edit settings.json"

# ── Project-mode fixture ────────────────────────────────────────────────────
PROJ="$TMP/proj"
mkdir -p "$PROJ"
git -C "$PROJ" init -q -b main
PCLONE="$PROJ/.claude/claude-prompt"
mkdir -p "$PCLONE/.git" "$PCLONE/agents" "$PCLONE/skills"
printf '# stub prompt\n' > "$PCLONE/SYSTEM_PROMPT.md"

PROJECT_OUT="$(cd "$PROJ" && HOME="$FAKE_HOME" bash "$INSTALL" --project --dry-run)" \
  || { echo "FAIL: install.sh --project --dry-run exited nonzero"; exit 1; }

# 4. Project mode wires NO hooks symlink and prints NO snippet.
if printf '%s' "$PROJECT_OUT" | grep -qF 'hooks symlink'; then
  echo "FAIL: project dry-run plans a hooks symlink"; printf '%s\n' "$PROJECT_OUT"; exit 1
fi
if printf '%s' "$PROJECT_OUT" | grep -qF 'guard-main-edit.sh'; then
  echo "FAIL: project dry-run prints the settings.json snippet"; printf '%s\n' "$PROJECT_OUT"; exit 1
fi
echo "  ok: project mode wires no hooks and prints no snippet"

echo "PASS: install.sh hooks wiring — global-only symlink and snippet behave as expected."
