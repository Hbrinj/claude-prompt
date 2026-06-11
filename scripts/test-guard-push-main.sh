#!/usr/bin/env bash
# Slice 2 test: guard-push-main.sh PreToolUse hook.
#
# Denies Bash commands containing a `git push` that targets main/master:
# explicit destinations (refspecs, with or without flags) and implicit pushes
# (`git push`, `git push origin`, `git push --force`) while the cwd repo is on
# main/master. Quotes and backslashes cannot dodge the match (`git push origin
# "main"`, `git push origin ma\in`, `\git push origin main`), shell wrappers
# are seen through (`sh -c 'git push origin main'`), and
# `--all`/`--mirror`/`--branches` pushes are denied outright. Allows
# everything else — non-push commands, feature-branch destinations, and branch
# names that merely contain "main" as a substring.
# Compound commands (&&, ;, ||): any denied segment denies the whole command.
#
# Requires: jq, git.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/guard-push-main.sh"
DENY_REASON="Pushing to main/master is blocked"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required to run this test"; exit 1; }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# Fake HOME so nothing from the real ~/.claude leaks into the hook.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME"

mkdir -p "$TMP/repo-main" "$TMP/repo-feature" "$TMP/plain"
git -C "$TMP/repo-main" init -q -b main
git -C "$TMP/repo-feature" init -q -b feature/x

bash_json() { # <command> <cwd>
  jq -cn --arg cmd "$1" --arg cwd "$2" \
    '{session_id:"s", cwd:$cwd, hook_event_name:"PreToolUse",
      tool_name:"Bash", tool_input:{command:$cmd}}'
}

run_hook() { # <stdin payload>
  printf '%s' "$1" | HOME="$FAKE_HOME" bash "$HOOK"
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

FEAT="$TMP/repo-feature"
MAIN="$TMP/repo-main"

# ── Deny: explicit main/master destinations (cwd irrelevant) ────────────────
assert_deny "git push origin main" \
  "$(bash_json 'git push origin main' "$FEAT")"
assert_deny "git push origin master" \
  "$(bash_json 'git push origin master' "$FEAT")"
assert_deny "git push origin HEAD:main" \
  "$(bash_json 'git push origin HEAD:main' "$FEAT")"
assert_deny "git push origin feature/x:main" \
  "$(bash_json 'git push origin feature/x:main' "$FEAT")"
assert_deny "git push --force origin main" \
  "$(bash_json 'git push --force origin main' "$FEAT")"
assert_deny "git push -u origin main" \
  "$(bash_json 'git push -u origin main' "$FEAT")"
assert_deny "git push -f origin HEAD:master" \
  "$(bash_json 'git push -f origin HEAD:master' "$FEAT")"
assert_deny "git push origin refs/heads/main" \
  "$(bash_json 'git push origin refs/heads/main' "$FEAT")"

# ── Deny: quoted refspecs (quotes must not dodge the match) ─────────────────
assert_deny 'git push origin "main" (double-quoted)' \
  "$(bash_json 'git push origin "main"' "$FEAT")"
assert_deny "git push origin 'master' (single-quoted)" \
  "$(bash_json "git push origin 'master'" "$FEAT")"
assert_deny 'git push origin HEAD:"main" (quoted destination)' \
  "$(bash_json 'git push origin HEAD:"main"' "$FEAT")"

# ── Deny: backslash escapes (the shell resolves them, so must we) ───────────
assert_deny 'git push origin ma\in (escaped refspec)' \
  "$(bash_json 'git push origin ma\in' "$FEAT")"
assert_deny '\git push origin main (escaped command name)' \
  "$(bash_json '\git push origin main' "$FEAT")"

# ── Deny: shell wrappers (sh/bash/zsh -c) ───────────────────────────────────
assert_deny "sh -c 'git push origin main'" \
  "$(bash_json "sh -c 'git push origin main'" "$FEAT")"
assert_deny 'bash -c "git push origin main"' \
  "$(bash_json 'bash -c "git push origin main"' "$FEAT")"
assert_deny "zsh -c 'git push origin master'" \
  "$(bash_json "zsh -c 'git push origin master'" "$FEAT")"

# ── Deny: --all / --mirror / --branches push every branch, main included ────
assert_deny "git push --all origin (on a feature branch)" \
  "$(bash_json 'git push --all origin' "$FEAT")"
assert_deny "git push --mirror origin (on a feature branch)" \
  "$(bash_json 'git push --mirror origin' "$FEAT")"
assert_deny "git push --branches origin (on a feature branch)" \
  "$(bash_json 'git push --branches origin' "$FEAT")"
assert_deny "bare git push --all (on a feature branch)" \
  "$(bash_json 'git push --all' "$FEAT")"

# ── Deny: implicit pushes while the cwd repo is on main/master ──────────────
assert_deny "bare git push on main" \
  "$(bash_json 'git push' "$MAIN")"
assert_deny "git push origin (no refspec) on main" \
  "$(bash_json 'git push origin' "$MAIN")"
assert_deny "git push --force (no refspec) on main" \
  "$(bash_json 'git push --force' "$MAIN")"

# ── Deny: compound commands with one bad segment ────────────────────────────
assert_deny "compound &&" \
  "$(bash_json 'echo build ok && git push origin main' "$FEAT")"
assert_deny "compound ;" \
  "$(bash_json 'git add . ; git commit -m x ; git push origin main' "$FEAT")"
assert_deny "compound ||" \
  "$(bash_json 'true || git push origin master' "$FEAT")"

# ── Allow: feature-branch destinations ──────────────────────────────────────
assert_allow "git push origin feature/x" \
  "$(bash_json 'git push origin feature/x' "$MAIN")"
assert_allow "git push origin HEAD:feature/x" \
  "$(bash_json 'git push origin HEAD:feature/x' "$MAIN")"
assert_allow "git push -u origin feature/x" \
  "$(bash_json 'git push -u origin feature/x' "$MAIN")"
assert_allow "git push --force-with-lease origin feature/x" \
  "$(bash_json 'git push --force-with-lease origin feature/x' "$MAIN")"
assert_allow "push local main to a feature branch" \
  "$(bash_json 'git push origin main:feature/backport' "$MAIN")"

# ── Allow: quoted/wrapped pushes to feature branches stay allowed ───────────
assert_allow 'git push origin "feature/x" (quoted feature ref)' \
  "$(bash_json 'git push origin "feature/x"' "$MAIN")"
assert_allow "sh -c 'git push origin feature/x'" \
  "$(bash_json "sh -c 'git push origin feature/x'" "$MAIN")"
assert_allow "sh -c 'git status' (wrapped non-push)" \
  "$(bash_json "sh -c 'git status'" "$MAIN")"

# ── Allow: "main"/"master" as substring, not whole refspec segment ──────────
assert_allow "git push origin feature/main-page" \
  "$(bash_json 'git push origin feature/main-page' "$MAIN")"
assert_allow "git push origin domain-fix" \
  "$(bash_json 'git push origin domain-fix' "$MAIN")"
assert_allow "git push origin maintenance" \
  "$(bash_json 'git push origin maintenance' "$MAIN")"

# ── Allow: implicit push on a feature branch / non-repo cwd ─────────────────
assert_allow "bare git push on feature branch" \
  "$(bash_json 'git push' "$FEAT")"
assert_allow "bare git push outside a repo fails open" \
  "$(bash_json 'git push' "$TMP/plain")"

# ── Allow: non-push commands ────────────────────────────────────────────────
assert_allow "git status" \
  "$(bash_json 'git status' "$MAIN")"
assert_allow "commit message mentioning push to main" \
  "$(bash_json 'git commit -m "push to main"' "$MAIN")"
assert_allow "echo main" \
  "$(bash_json 'echo main' "$MAIN")"
assert_allow "compound without a bad push" \
  "$(bash_json 'git status && git push origin feature/x' "$MAIN")"

# ── Allow: other tools and malformed input fail open ────────────────────────
assert_allow "non-Bash tool passes through" \
  "$(jq -cn '{tool_name:"Edit", tool_input:{file_path:"/x"}}')"
assert_allow "malformed JSON fails open" "this is not json"
assert_allow "empty stdin fails open" ""
assert_allow "missing command fails open" \
  '{"tool_name":"Bash","tool_input":{}}'

# ── Fail open: hook deployed without its sibling lib.sh ─────────────────────
mkdir -p "$TMP/lonely"
cp "$HOOK" "$TMP/lonely/"
if ! out="$(printf '%s' "$(bash_json 'git push origin main' "$FEAT")" \
  | HOME="$FAKE_HOME" bash "$TMP/lonely/guard-push-main.sh")"; then
  echo "FAIL: missing lib.sh — hook exited nonzero"; exit 1
fi
[ -z "$out" ] || { echo "FAIL: missing lib.sh — expected allow, got: $out"; exit 1; }
echo "  ok: missing sibling lib.sh fails open (allowed)"

echo "PASS: guard-push-main.sh — all cases behaved as expected."
