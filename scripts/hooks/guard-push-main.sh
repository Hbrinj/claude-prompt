#!/usr/bin/env bash
# guard-push-main.sh — Claude Code PreToolUse hook: block `git push` to main/master.
#
# Hook contract (stdin/stdout):
#   stdin : JSON {"session_id", "cwd", "hook_event_name", "tool_name", "tool_input"}
#           Only tool_name == "Bash" is inspected; the command string is
#           tool_input.command.
#   deny  : print {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#           "permissionDecision":"deny","permissionDecisionReason":"…"}}, exit 0.
#   allow : exit 0 with no output.
#
# Denies:
#   - explicit destinations: `git push origin main`, `git push origin HEAD:main`,
#     `git push origin feature/x:main`, with or without flags (--force/-f/-u/…);
#     refspec destinations are matched as whole segments (refs/heads/ tolerated),
#     so feature/main-page and domain-fix are NOT denied
#   - implicit pushes (`git push`, `git push origin`, `git push --force`) while
#     the repo at the session cwd (or at a `git -C <dir>` override) is on
#     main/master
#   - compound commands (&&, ;, ||, |, newlines): any denied segment denies all
#
# Allows everything else, and fails open on missing jq, malformed stdin JSON,
# or a cwd that is not a git repo.
#
# Dependencies: jq, git.
set -euo pipefail

DENY_REASON="Pushing to main/master is blocked — the user merges to main manually. Push a feature branch instead."

allow() { exit 0; }

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
    "$DENY_REASON"
  exit 0
}

# A broken hook must never brick the harness: no jq → allow.
command -v jq >/dev/null 2>&1 || allow

input="$(cat || true)"

# Malformed JSON → allow.
if ! tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"; then
  allow
fi
[[ "$tool_name" == "Bash" ]] || allow

command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -n "$command_str" ]] || allow

session_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[[ -n "$session_cwd" ]] || session_cwd="$PWD"

# is_protected_ref <ref> — true when <ref> names main/master as a whole
# segment (force marker `+` and refs/heads/ prefix tolerated).
is_protected_ref() {
  local ref="${1#+}"
  ref="${ref#refs/heads/}"
  [[ "$ref" == "main" || "$ref" == "master" ]]
}

# on_protected_branch <dir> — true when the repo at <dir> is on main/master.
# Not a repo or detached HEAD → false (fail open).
on_protected_branch() {
  local branch
  branch="$(git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [[ "$branch" == "main" || "$branch" == "master" ]]
}

# segment_denies <segment> — true when the segment is a `git push` that
# targets main/master.
segment_denies() {
  local -a words=()
  read -ra words <<< "$1" || true
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

  # Explicit refspecs: destination is the part after `:` (or the whole
  # refspec when there is no `:`).
  if (( ${#positionals[@]} >= 2 )); then
    local j spec
    for (( j = 1; j < ${#positionals[@]}; j++ )); do
      spec="${positionals[j]}"
      if is_protected_ref "${spec##*:}"; then
        return 0
      fi
    done
    return 1
  fi

  # Implicit push: deny when the effective repo is on main/master.
  local repo_dir="$session_cwd"
  if [[ -n "$git_dir" ]]; then
    [[ "$git_dir" == /* ]] || git_dir="${repo_dir%/}/$git_dir"
    repo_dir="$git_dir"
  fi
  on_protected_branch "$repo_dir"
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
