#!/usr/bin/env bash
# Test: guard-push-review.sh PreToolUse hook.
#
# Denies Bash commands containing a `git push` of a feature/* or fix/* branch
# unless <repo-root>/.claude/review-evidence/<branch-slug>.md exists and its
# `HEAD:` line matches the branch's current sha (slug = branch with `/` → `-`;
# see skills/implement-feature.md step 5). The branch being pushed is the
# explicit refspec source (`origin branch`, `origin src:dst`, `HEAD` resolved
# to the current branch) or, for implicit pushes, the current branch. Allows:
# matching records, non-feature/fix branches (main/master are
# guard-push-main.sh's concern), deletion pushes (`--delete`/`-d`/`:branch`),
# `--all`/`--mirror`/`--branches` (guard-push-main.sh denies those outright),
# unknown local branches, non-repo cwds, detached HEAD, and any malformed
# input (fail open). Quotes/backslashes/wrappers cannot dodge the match, and
# any denied segment of a compound command denies the whole command.
#
# Requires: jq, git.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/guard-push-review.sh"
DENY_SNIPPET="no review-evidence record matching HEAD"

[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required to run this test"; exit 1; }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# Fake HOME so nothing from the real ~/.claude leaks into the hook.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"

git_c() { # <dir> <git args…> — git with a throwaway identity
  local dir="$1"; shift
  git -C "$dir" -c user.email=t@t -c user.name=t "$@"
}

# ── Fixture: repo on feature/x with a record matching HEAD ──────────────────
OK="$TMP/repo-ok"
mkdir -p "$OK"
git -C "$OK" init -q -b feature/x
git_c "$OK" commit -q --allow-empty -m init
git -C "$OK" branch fix/y
git -C "$OK" branch chore/z
git -C "$OK" branch main
git -C "$OK" branch feature/nohead
OK_SHA="$(git -C "$OK" rev-parse refs/heads/feature/x)"
mkdir -p "$OK/.claude/review-evidence"
printf '# Review evidence: feature/x\n\nHEAD: %s\nLane: standard\n' "$OK_SHA" \
  > "$OK/.claude/review-evidence/feature-x.md"
# Record that exists but has no HEAD: line at all.
printf '# Review evidence: feature/nohead\n\nLane: standard\n' \
  > "$OK/.claude/review-evidence/feature-nohead.md"

# ── Fixture: repo whose record points at a superseded commit ────────────────
STALE="$TMP/repo-stale"
mkdir -p "$STALE"
git -C "$STALE" init -q -b feature/stale
git_c "$STALE" commit -q --allow-empty -m one
STALE_SHA="$(git -C "$STALE" rev-parse HEAD)"
mkdir -p "$STALE/.claude/review-evidence"
printf '# Review evidence: feature/stale\n\nHEAD: %s\nLane: standard\n' "$STALE_SHA" \
  > "$STALE/.claude/review-evidence/feature-stale.md"
git_c "$STALE" commit -q --allow-empty -m two

# ── Fixture: detached HEAD and a plain (non-repo) directory ─────────────────
DETACHED="$TMP/repo-detached"
mkdir -p "$DETACHED"
git -C "$DETACHED" init -q -b feature/loose
git_c "$DETACHED" commit -q --allow-empty -m init
git -C "$DETACHED" checkout -q --detach
mkdir -p "$TMP/plain"

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
  printf '%s' "$out" | grep -qF "$DENY_SNIPPET" \
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

# ── Deny: no record for the branch being pushed ─────────────────────────────
assert_deny "explicit push of a fix/* branch with no record" \
  "$(bash_json 'git push origin fix/y' "$OK")"
assert_deny "src:dst refspec — source has no record" \
  "$(bash_json 'git push origin fix/y:fix/y' "$OK")"
assert_deny "force-marker refspec (+fix/y) with no record" \
  "$(bash_json 'git push origin +fix/y' "$OK")"
assert_deny "refs/heads/-qualified source with no record" \
  "$(bash_json 'git push origin refs/heads/fix/y' "$OK")"
assert_deny "push flags tolerated (-u) with no record" \
  "$(bash_json 'git push -u origin fix/y' "$OK")"
assert_deny "record exists but lacks a HEAD: line" \
  "$(bash_json 'git push origin feature/nohead' "$OK")"

# The deny reason names the branch and the record path to write.
out="$(run_hook "$(bash_json 'git push origin fix/y' "$OK")")"
printf '%s' "$out" | grep -qF 'fix/y' \
  || { echo "FAIL: deny reason does not name the branch: $out"; exit 1; }
printf '%s' "$out" | grep -qF '.claude/review-evidence/fix-y.md' \
  || { echo "FAIL: deny reason does not name the record path: $out"; exit 1; }
echo "  ok: deny reason names the branch and record path"

# ── Deny: record exists but its HEAD: sha is stale ──────────────────────────
assert_deny "explicit push with a stale record" \
  "$(bash_json 'git push origin feature/stale' "$STALE")"
assert_deny "implicit push with a stale record" \
  "$(bash_json 'git push' "$STALE")"

# ── Deny: quoting, wrappers, compound commands, git -C override ─────────────
assert_deny 'git push origin "fix/y" (quoted refspec)' \
  "$(bash_json 'git push origin "fix/y"' "$OK")"
assert_deny "sh -c 'git push origin fix/y' (shell wrapper)" \
  "$(bash_json "sh -c 'git push origin fix/y'" "$OK")"
assert_deny "compound && with one bad segment" \
  "$(bash_json 'echo build ok && git push origin fix/y' "$OK")"
assert_deny "git -C <repo> push from an unrelated cwd" \
  "$(bash_json "git -C $OK push origin fix/y" "$TMP/plain")"

# ── Allow: record matches HEAD ──────────────────────────────────────────────
assert_allow "explicit push with a matching record" \
  "$(bash_json 'git push origin feature/x' "$OK")"
assert_allow "implicit push with a matching record" \
  "$(bash_json 'git push' "$OK")"
assert_allow "git push origin HEAD resolves to the current branch" \
  "$(bash_json 'git push origin HEAD' "$OK")"
assert_allow "HEAD:dst — source is the current branch, record matches" \
  "$(bash_json 'git push origin HEAD:feature/renamed' "$OK")"
assert_allow "src:dst — source has a matching record" \
  "$(bash_json 'git push origin feature/x:feature/other' "$OK")"
assert_allow "git -C <repo> implicit push, record matches" \
  "$(bash_json "git -C $OK push" "$TMP/plain")"

# ── Allow: branches outside the feature/* and fix/* namespaces ──────────────
assert_allow "push of a chore/* branch needs no record" \
  "$(bash_json 'git push origin chore/z' "$OK")"
assert_allow "push of main is guard-push-main's concern" \
  "$(bash_json 'git push origin main' "$OK")"

# ── Allow: deletion pushes ──────────────────────────────────────────────────
assert_allow "git push origin --delete fix/y" \
  "$(bash_json 'git push origin --delete fix/y' "$OK")"
assert_allow "git push -d origin fix/y" \
  "$(bash_json 'git push -d origin fix/y' "$OK")"
assert_allow "empty-source refspec :fix/y (deletion)" \
  "$(bash_json 'git push origin :fix/y' "$OK")"

# ── Allow: multi-branch pushes are guard-push-main's concern ────────────────
assert_allow "git push --all origin (denied by guard-push-main, not here)" \
  "$(bash_json 'git push --all origin' "$OK")"

# ── Allow: unresolvable state fails open ────────────────────────────────────
assert_allow "unknown local branch fails open" \
  "$(bash_json 'git push origin feature/does-not-exist' "$OK")"
assert_allow "implicit push outside a repo fails open" \
  "$(bash_json 'git push' "$TMP/plain")"
assert_allow "implicit push on detached HEAD fails open" \
  "$(bash_json 'git push' "$DETACHED")"

# ── Allow: non-push commands ────────────────────────────────────────────────
assert_allow "git status" \
  "$(bash_json 'git status' "$OK")"
assert_allow "commit message mentioning a push" \
  "$(bash_json 'git commit -m "push fix/y later"' "$OK")"
assert_allow "compound without a bad push" \
  "$(bash_json 'git status && git push origin feature/x' "$OK")"

# ── Allow: other tools and malformed input fail open ────────────────────────
assert_allow "non-Bash tool passes through" \
  "$(jq -cn '{tool_name:"Edit", tool_input:{file_path:"/x"}}')"
assert_allow "malformed JSON fails open" "this is not json"
assert_allow "empty stdin fails open" ""
assert_allow "missing command fails open" \
  '{"tool_name":"Bash","tool_input":{}}'

# ── Exceptions file: repos listed in ~/.claude/hooks-exceptions opt out ─────
EXCEPTED="$TMP/repo-excepted"
mkdir -p "$EXCEPTED"
git -C "$EXCEPTED" init -q -b feature/e
git_c "$EXCEPTED" commit -q --allow-empty -m init
HOME_REPO="$FAKE_HOME/wip-repo"
mkdir -p "$HOME_REPO"
git -C "$HOME_REPO" init -q -b fix/w
git_c "$HOME_REPO" commit -q --allow-empty -m init
cat > "$FAKE_HOME/.claude/hooks-exceptions" <<EOF
# repos not using the review-evidence workflow
$EXCEPTED
~/wip-repo
EOF

assert_allow "implicit push in an excepted repo needs no record" \
  "$(bash_json 'git push' "$EXCEPTED")"
assert_allow "explicit push in an excepted repo needs no record" \
  "$(bash_json 'git push origin feature/e' "$EXCEPTED")"
assert_allow "exception prefix via ~ expansion" \
  "$(bash_json 'git push origin fix/w' "$HOME_REPO")"
assert_deny "non-excepted repo still denied with the exceptions file present" \
  "$(bash_json 'git push origin fix/y' "$OK")"
rm -f "$FAKE_HOME/.claude/hooks-exceptions"

# ── Fail open: hook deployed without its sibling lib.sh ─────────────────────
mkdir -p "$TMP/lonely"
cp "$HOOK" "$TMP/lonely/"
if ! out="$(printf '%s' "$(bash_json 'git push origin fix/y' "$OK")" \
  | HOME="$FAKE_HOME" bash "$TMP/lonely/guard-push-review.sh")"; then
  echo "FAIL: missing lib.sh — hook exited nonzero"; exit 1
fi
[ -z "$out" ] || { echo "FAIL: missing lib.sh — expected allow, got: $out"; exit 1; }
echo "  ok: missing sibling lib.sh fails open (allowed)"

echo "PASS: guard-push-review.sh — all cases behaved as expected."
