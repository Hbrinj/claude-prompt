#!/usr/bin/env bash
# guard-push-review.sh — Claude Code PreToolUse hook: block `git push` of a
# feature/* or fix/* branch without a review-evidence record matching HEAD.
#
# Hook contract (stdin/stdout):
#   stdin : JSON {"session_id", "cwd", "hook_event_name", "tool_name", "tool_input"}
#           Only tool_name == "Bash" is inspected; the command string is
#           tool_input.command.
#   deny  : print {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#           "permissionDecision":"deny","permissionDecisionReason":"…"}}, exit 0.
#   allow : exit 0 with no output.
#
# The workflow's review step (skills/implement-feature.md step 5) writes a
# review-evidence record at <repo-root>/.claude/review-evidence/<slug>.md
# (slug = branch name with `/` → `-`) containing a line `HEAD: <full sha>`.
# This hook enforces the record mechanically:
#
# Denies:
#   - `git push` where EITHER side of a refspec is a feature/* or fix/*
#     branch — the source being pushed (`git push origin feature/x`; `HEAD`
#     resolves to the current branch; the current branch on an implicit
#     `git push`/`git push origin`) or the destination being created
#     (`git push origin chore/z:feature/sneaky`, `git push origin
#     <sha>:feature/x` — rename pushes must not smuggle unreviewed content
#     into the guarded namespaces; force `+` and refs/heads/ prefixes
#     tolerated) — unless the record exists and its HEAD: line matches the
#     sha of the content being pushed (`git rev-parse` of the source). Any
#     new commit invalidates the record. The record may be keyed by the
#     source branch slug or, for rename/raw-sha pushes, the destination slug
#   - quote/backslash stripping, `git -C <dir>` overrides, and
#     compound-command splitting mirror guard-push-main.sh: quoted refspecs,
#     shell wrappers (`sh -c '…'`), and any denied segment of a
#     `&&`/`;`/`||`/`|`/newline chain are caught
#
# Allows (skips):
#   - non-push commands, and pushes of branches outside feature/* and fix/*
#     (main/master are guard-push-main.sh's concern)
#   - deletion pushes: `--delete`/`-d`, or an empty-source `:branch` refspec
#   - `--all`/`--mirror`/`--branches` pushes — guard-push-main.sh denies
#     those outright, so no evidence check is attempted here
#   - repos whose root is at or under a prefix listed in
#     ~/.claude/hooks-exceptions — the opt-out for repos not using the
#     review-evidence workflow (same file and format as guard-main-edit.sh)
#
# Fails open (allows) on: missing jq, malformed stdin JSON, a repo dir that is
# not a git repo, detached HEAD on an implicit/HEAD push, or a refspec source
# that resolves to no local commit (the push itself would fail). The same
# quote-blind tokenization tradeoff as guard-push-main.sh applies (see
# scripts/hooks/README.md).
#
# Dependencies: jq, git, sibling lib.sh (allow/deny/read_hook_input/
# path_in_exceptions).
set -euo pipefail

# Default reason; requires_evidence sets the branch-specific one before deny.
DENY_REASON="push blocked: no review-evidence record matching HEAD — write .claude/review-evidence/<branch-slug>.md at the review step (skills/implement-feature.md step 5)."

# Shared allow/deny/read_hook_input live next to this script; a missing lib
# fails open (a broken hook must never brick the harness).
HOOK_LIB="$(dirname "$0")/lib.sh"
[[ -f "$HOOK_LIB" ]] || exit 0
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$HOOK_LIB"

read_hook_input
[[ "$tool_name" == "Bash" ]] || allow

command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -n "$command_str" ]] || allow

session_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[[ -n "$session_cwd" ]] || session_cwd="$PWD"

# requires_evidence <src-ref> <dst-ref> <repo-dir> — true when the push of
# <src-ref> to <dst-ref> ("" for a bare refspec or an implicit push) from the
# repo at <repo-dir> touches the guarded feature/*/fix/* namespaces on EITHER
# side WITHOUT a review-evidence record matching the sha of the pushed
# content; sets DENY_REASON. The record may be keyed by the source branch
# slug or the destination slug (rename/raw-sha pushes). Anything unresolvable
# — not a repo, detached HEAD for a HEAD push, a source naming no local
# commit — is false (fail open: the push itself would fail).
requires_evidence() {
  local src="$1" dst="$2" repo_dir="$3" branch="" root sha record
  src="${src#refs/heads/}"
  dst="${dst#refs/heads/}"

  # Resolve the source to a local branch when it names one.
  if [[ "$src" == "HEAD" ]]; then
    branch="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" ]] || return 1
  elif git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$src" 2>/dev/null; then
    branch="$src"
  fi

  # A bare refspec (no `:`) pushes to a same-named remote ref.
  [[ -n "$dst" ]] || dst="${branch:-$src}"

  # Guarded when either side is feature/* or fix/*: the local branch being
  # pushed, or the remote branch being created/updated by a rename push.
  if [[ "$branch" != feature/* && "$branch" != fix/* &&
        "$dst"    != feature/* && "$dst"    != fix/*    ]]; then
    return 1
  fi

  root="$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$root" ]] || return 1
  # Opt-out: repos listed in ~/.claude/hooks-exceptions don't use the
  # review-evidence workflow.
  if path_in_exceptions "$root"; then
    return 1
  fi

  # The sha of the content being pushed: the source branch tip, or whatever
  # commit a raw-sha/tag source resolves to.
  if [[ -n "$branch" ]]; then
    sha="$(git -C "$repo_dir" rev-parse --verify --quiet "refs/heads/$branch" 2>/dev/null || true)"
  else
    sha="$(git -C "$repo_dir" rev-parse --verify --quiet "${src}^{commit}" 2>/dev/null || true)"
  fi
  [[ -n "$sha" ]] || return 1

  # Accept a record keyed by the source branch or by the destination.
  local name
  for name in "$branch" "$dst"; do
    [[ -n "$name" ]] || continue
    record="$root/.claude/review-evidence/${name//\//-}.md"
    if [[ -f "$record" ]] && grep -qE "^HEAD: ${sha}[[:space:]]*$" "$record" 2>/dev/null; then
      return 1
    fi
  done

  # Tokenization already strips quotes/backslashes from explicit refspecs;
  # scrub the symbolic-ref path too so the reason stays valid JSON.
  local safe="${branch:-$dst}"
  safe="${safe//\"/}"
  safe="${safe//\\/}"
  DENY_REASON="push blocked: no review-evidence record matching HEAD for ${safe} — write .claude/review-evidence/${safe//\//-}.md at the review step (skills/implement-feature.md step 5); a new commit invalidates the record."
  return 0
}

# segment_denies <segment> — true when the segment is a `git push` of a
# feature/* or fix/* branch lacking a matching review-evidence record.
segment_denies() {
  local -a raw=() words=()
  read -ra raw <<< "$1" || true

  # Strip quote and backslash characters from every token so shell escaping
  # cannot dodge the match (same approach as guard-push-main.sh). Tokens that
  # were only quotes are dropped.
  local k w
  for (( k = 0; k < ${#raw[@]}; k++ )); do
    w="${raw[k]//\"/}"
    w="${w//\'/}"
    w="${w//\\/}"
    if [[ -n "$w" ]]; then
      words+=("$w")
    fi
  done

  local n=${#words[@]} i=0 tok git_dir=""

  # Locate the `git` token (path-qualified invocations and a leading
  # subshell `(` are tolerated).
  while (( i < n )); do
    tok="${words[i]}"
    tok="${tok#"${tok%%[!(]*}"}"
    if [[ "${tok##*/}" == "git" ]]; then
      break
    fi
    i=$((i + 1))
  done
  (( i < n )) || return 1
  i=$((i + 1))

  # Skip git global options to find the subcommand.
  local subcmd=""
  while (( i < n )); do
    tok="${words[i]}"
    case "$tok" in
      -C|-c|--exec-path|--git-dir|--work-tree|--namespace)
        if [[ "$tok" == "-C" && $((i + 1)) -lt $n ]]; then
          git_dir="${words[i + 1]}"
        fi
        i=$((i + 2)) ;;
      -*)
        i=$((i + 1)) ;;
      *)
        subcmd="$tok"
        i=$((i + 1))
        break ;;
    esac
  done
  [[ "$subcmd" == "push" ]] || return 1

  # Split push arguments into flags and positionals (remote, refspecs…).
  local -a positionals=()
  while (( i < n )); do
    tok="${words[i]}"
    case "$tok" in
      --delete|-d)
        # Deletion pushes remove a remote branch — no evidence needed.
        return 1 ;;
      --all|--mirror|--branches)
        # Multi-branch pushes are denied outright by guard-push-main.sh.
        return 1 ;;
      -o|--push-option|--repo|--receive-pack|--exec)
        i=$((i + 2)) ;;
      --)
        i=$((i + 1))
        while (( i < n )); do
          positionals+=("${words[i]}")
          i=$((i + 1))
        done ;;
      -*)
        i=$((i + 1)) ;;
      *)
        positionals+=("${words[i]}")
        i=$((i + 1)) ;;
    esac
  done

  # Effective repo dir: the session cwd, unless overridden via `git -C`.
  local repo_dir="$session_cwd"
  if [[ -n "$git_dir" ]]; then
    [[ "$git_dir" == /* ]] || git_dir="${repo_dir%/}/$git_dir"
    repo_dir="$git_dir"
  fi

  # Explicit refspecs: source names the content pushed, destination the
  # remote ref written.
  if (( ${#positionals[@]} >= 2 )); then
    local j spec src dst
    for (( j = 1; j < ${#positionals[@]}; j++ )); do
      spec="${positionals[j]#+}"
      src="$spec"
      dst=""
      if [[ "$spec" == *:* ]]; then
        src="${spec%%:*}"
        dst="${spec#*:}"
      fi
      # `:branch` (empty source) is a deletion refspec — skip it.
      [[ -n "$src" ]] || continue
      if requires_evidence "$src" "$dst" "$repo_dir"; then
        return 0
      fi
    done
    return 1
  fi

  # Implicit push: the current branch is the one being pushed.
  requires_evidence HEAD "" "$repo_dir"
}

# Split compound commands on &&, ||, ;, |, and newlines; any denied
# segment denies the whole command.
DELIM=$'\x1f'
segments="$command_str"
segments="${segments//&&/$DELIM}"
segments="${segments//\|\|/$DELIM}"
segments="${segments//;/$DELIM}"
segments="${segments//\|/$DELIM}"
segments="${segments//$'\n'/$DELIM}"

while IFS= read -r -d "$DELIM" segment || [[ -n "$segment" ]]; do
  if segment_denies "$segment"; then
    deny
  fi
done <<< "$segments$DELIM"

allow
