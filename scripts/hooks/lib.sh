#!/usr/bin/env bash
# lib.sh — shared helpers for the guard hooks in this directory.
#
# Source from a sibling hook script AFTER defining DENY_REASON:
#   . "$(dirname "$0")/lib.sh"
#
# Provides:
#   allow               — exit 0 with no output (PreToolUse allow)
#   deny                — print the PreToolUse deny object using $DENY_REASON, exit 0
#   read_hook_input     — read stdin into $input and extract $tool_name;
#                         allows (fail open) when jq is missing or stdin is
#                         not valid JSON
#   path_in_exceptions  — true when a path is at or under a prefix listed in
#                         ~/.claude/hooks-exceptions (the guards' opt-out file)
#
# Not meant to be executed directly; inherits the caller's strict mode.

allow() { exit 0; }

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
    "$DENY_REASON"
  exit 0
}

# path_in_exceptions <path> — true when <path> is at, or under, a prefix
# listed in ~/.claude/hooks-exceptions. One path prefix per line; a leading
# `~`, `$HOME`, or `${HOME}` is expanded; blank lines and `#` comments are
# ignored; a missing file matches nothing. Prefixes match whole path
# segments: `~/notes` covers `~/notes/a.md` but not `~/notes-other/a.md`.
path_in_exceptions() {
  local target="$1" exceptions_file="${HOME}/.claude/hooks-exceptions"
  local line prefix
  [[ -f "$exceptions_file" ]] || return 1
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
      return 0
    fi
  done < "$exceptions_file"
  return 1
}

# Sets globals: input, tool_name.
# A broken hook must never brick the harness: no jq → allow; stdin that jq
# cannot parse → allow.
read_hook_input() {
  command -v jq >/dev/null 2>&1 || allow
  input="$(cat || true)"
  # tool_name is consumed by the sourcing hook script, not in this file.
  # shellcheck disable=SC2034
  if ! tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"; then
    allow
  fi
}
