#!/usr/bin/env bash
# guard-main-edit.sh — Claude Code PreToolUse hook: block Edit/Write/NotebookEdit
# while the target file's git repo is on main/master.
#
# Hook contract (stdin/stdout):
#   stdin : JSON {"session_id", "cwd", "hook_event_name", "tool_name", "tool_input"}
#           Target path: tool_input.file_path (Edit/Write) or
#           tool_input.notebook_path (NotebookEdit).
#   deny  : print {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#           "permissionDecision":"deny","permissionDecisionReason":"…"}}, exit 0.
#   allow : exit 0 with no output.
#
# The target may not exist yet (Write creates files): the hook walks up the
# dirname chain to the nearest existing directory before asking git.
#
# Allows (fail open): missing jq, malformed stdin JSON, missing target path,
# non-git paths, repos on any branch other than main/master, detached HEAD,
# and any target under a prefix listed in ~/.claude/hooks-exceptions
# (one path prefix per line; leading `~`, `$HOME`, or `${HOME}` expanded;
# blank lines and `#` comments ignored; the file may not exist).
#
# Dependencies: jq, git.
set -euo pipefail

DENY_REASON="On main/master — create a feature branch first"

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

case "$tool_name" in
  Edit|Write)   path_filter='.tool_input.file_path // empty' ;;
  NotebookEdit) path_filter='.tool_input.notebook_path // empty' ;;
  *)            allow ;;
esac

target="$(printf '%s' "$input" | jq -r "$path_filter" 2>/dev/null || true)"
[[ -n "$target" ]] || allow

# Resolve relative targets against the session cwd.
if [[ "$target" != /* ]]; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
  [[ -n "$cwd" ]] || cwd="$PWD"
  target="${cwd%/}/$target"
fi

# Exceptions file: allow any target at or under a listed path prefix.
exceptions_file="${HOME}/.claude/hooks-exceptions"
if [[ -f "$exceptions_file" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim surrounding whitespace; skip blanks and comments.
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Expand leading ~, $HOME, ${HOME}. The single quotes are deliberate:
    # we match the LITERAL strings as written in the exceptions file.
    # shellcheck disable=SC2088,SC2016
    case "$line" in
      '~')         line="${HOME}" ;;
      '~/'*)       line="${HOME}/${line#'~/'}" ;;
      '$HOME')     line="${HOME}" ;;
      '$HOME/'*)   line="${HOME}/${line#'$HOME/'}" ;;
      '${HOME}')   line="${HOME}" ;;
      '${HOME}/'*) line="${HOME}/${line#'${HOME}/'}" ;;
    esac
    prefix="${line%/}"
    if [[ "$target" == "$prefix" || "$target" == "$prefix"/* ]]; then
      allow
    fi
  done < "$exceptions_file"
fi

# Walk up to the nearest existing directory (the target may not exist yet).
dir="$(dirname "$target")"
while [[ ! -d "$dir" && "$dir" != "/" ]]; do
  dir="$(dirname "$dir")"
done

# symbolic-ref fails outside a repo and on detached HEAD — both allow.
branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
case "$branch" in
  main|master) deny ;;
esac

allow
