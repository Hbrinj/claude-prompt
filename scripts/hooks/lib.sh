#!/usr/bin/env bash
# lib.sh — shared helpers for the guard hooks in this directory.
#
# Source from a sibling hook script AFTER defining DENY_REASON:
#   . "$(dirname "$0")/lib.sh"
#
# Provides:
#   allow            — exit 0 with no output (PreToolUse allow)
#   deny             — print the PreToolUse deny object using $DENY_REASON, exit 0
#   read_hook_input  — read stdin into $input and extract $tool_name;
#                      allows (fail open) when jq is missing or stdin is
#                      not valid JSON
#
# Not meant to be executed directly; inherits the caller's strict mode.

allow() { exit 0; }

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
    "$DENY_REASON"
  exit 0
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
