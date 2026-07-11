#!/usr/bin/env bash
# Slice 1 test: guard-main-edit.sh PreToolUse hook.
#
# Denies Edit/Write/NotebookEdit when the target file's git repo is on
# main/master. Allows: non-git paths, other branches, detached HEAD, targets
# under a prefix listed in ~/.claude/hooks-exceptions, other tools, and any
# malformed input (fail open). Write targets may not exist yet — the hook
# walks up the dirname chain to the nearest existing directory.
#
# Requires: jq, git.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/guard-main-edit.sh"
DENY_REASON="On main/master — create a feature branch first"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required to run this test"; exit 1; }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# Fake HOME so the user's real ~/.claude/hooks-exceptions is never read.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"

make_repo() { # <dir> <branch>
  mkdir -p "$1"
  git -C "$1" init -q -b "$2"
}

make_repo "$TMP/repo-main" main
make_repo "$TMP/repo-master" master
make_repo "$TMP/repo-feature" feature/x
make_repo "$TMP/repo-detached" main
git -C "$TMP/repo-detached" -c user.email=t@t -c user.name=t \
  commit -q --allow-empty -m init
git -C "$TMP/repo-detached" checkout -q --detach
mkdir -p "$TMP/plain"

hook_json() { # <tool_name> <path_key> <path>
  jq -cn --arg tool "$1" --arg key "$2" --arg path "$3" \
    '{session_id:"s", cwd:"/", hook_event_name:"PreToolUse",
      tool_name:$tool, tool_input:{($key):$path}}'
}

run_hook() { # <stdin payload>
  HOME="$FAKE_HOME" bash "$HOOK" <<<"$1"
}

assert_deny() { # <label> <payload>
  local out
  if ! out="$(run_hook "$2")"; then
    echo "FAIL: $1 — hook exited nonzero"; exit 1
  fi
  printf '%s' "$out" | jq -e \
    '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
    || { echo "FAIL: $1 — expected deny, got: ${out:-<empty>}"; exit 1; }
  printf '%s' "$out" | grep -qF "$DENY_REASON" \
    || { echo "FAIL: $1 — deny reason wrong: $out"; exit 1; }
  echo "  ok: $1 (denied)"
}

assert_allow() { # <label> <payload>
  local out
  if ! out="$(run_hook "$2")"; then
    echo "FAIL: $1 — hook exited nonzero"; exit 1
  fi
  [ -z "$out" ] || { echo "FAIL: $1 — expected allow (no output), got: $out"; exit 1; }
  echo "  ok: $1 (allowed)"
}

# ── Deny: main/master repos ─────────────────────────────────────────────────
assert_deny "Edit on main" \
  "$(hook_json Edit file_path "$TMP/repo-main/a.md")"
assert_deny "Write on master" \
  "$(hook_json Write file_path "$TMP/repo-master/a.md")"
assert_deny "NotebookEdit on main" \
  "$(hook_json NotebookEdit notebook_path "$TMP/repo-main/n.ipynb")"
assert_deny "Write to not-yet-existing nested path on main (dirname walk-up)" \
  "$(hook_json Write file_path "$TMP/repo-main/new/deep/dir/file.md")"

# ── Allow: everything else ──────────────────────────────────────────────────
assert_allow "Edit on a feature branch" \
  "$(hook_json Edit file_path "$TMP/repo-feature/a.md")"
assert_allow "Edit outside any git repo" \
  "$(hook_json Edit file_path "$TMP/plain/a.md")"
assert_allow "Edit on detached HEAD" \
  "$(hook_json Edit file_path "$TMP/repo-detached/a.md")"
assert_allow "Other tool names pass through" \
  "$(hook_json Bash file_path "$TMP/repo-main/a.md")"

# ── Exceptions file ─────────────────────────────────────────────────────────
make_repo "$FAKE_HOME/notes" main
make_repo "$FAKE_HOME/also-notes" main
make_repo "$FAKE_HOME/notes-other" main
make_repo "$TMP/vault" main
cat > "$FAKE_HOME/.claude/hooks-exceptions" <<EOF
# comment lines and blanks are ignored

~/notes
\$HOME/also-notes
$TMP/vault
EOF

assert_allow "exception prefix via ~" \
  "$(hook_json Edit file_path "$FAKE_HOME/notes/a.md")"
assert_allow "exception prefix via \$HOME" \
  "$(hook_json Write file_path "$FAKE_HOME/also-notes/a.md")"
assert_allow "exception prefix via absolute path" \
  "$(hook_json Edit file_path "$TMP/vault/a.md")"
assert_deny "exception prefix matches whole path segments only" \
  "$(hook_json Edit file_path "$FAKE_HOME/notes-other/a.md")"

# ── Fail open ───────────────────────────────────────────────────────────────
assert_allow "malformed JSON on stdin fails open" "this is not json"
assert_allow "empty stdin fails open" ""
assert_allow "missing tool_input.file_path fails open" \
  '{"tool_name":"Edit","tool_input":{}}'

# ── Fail open: hook deployed without its sibling lib.sh ─────────────────────
mkdir -p "$TMP/lonely"
cp "$HOOK" "$TMP/lonely/"
if ! out="$(HOME="$FAKE_HOME" bash "$TMP/lonely/guard-main-edit.sh" \
  <<<"$(hook_json Edit file_path "$TMP/repo-main/a.md")")"; then
  echo "FAIL: missing lib.sh — hook exited nonzero"; exit 1
fi
[ -z "$out" ] || { echo "FAIL: missing lib.sh — expected allow, got: $out"; exit 1; }
echo "  ok: missing sibling lib.sh fails open (allowed)"

echo "PASS: guard-main-edit.sh — all cases behaved as expected."
