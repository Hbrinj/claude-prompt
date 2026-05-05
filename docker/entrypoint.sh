#!/usr/bin/env bash
# Worker entrypoint. Runs inside the claude-worker container.
#
# Required env:
#   SLUG                       — task slug; reads /workspace/tasks/<SLUG>.md
#   CLAUDE_CODE_OAUTH_TOKEN    — claude auth token
#
# Contract:
#   On exit, /workspace/.worker-result.json MUST exist with this schema:
#   { "status": "APPROVE" | "BLOCKED",
#     "branch": <string|null>,
#     "commits": [<short sha string>, ...],
#     "summary": <one-sentence string>,
#     "blockers": [<string>, ...] }
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
SLUG="${SLUG:?SLUG env var is required}"
TASK_FILE="$WORKSPACE/tasks/${SLUG}.md"
RESULT_FILE="$WORKSPACE/.worker-result.json"

cd "$WORKSPACE"

write_blocked() {
  jq -n --arg msg "$1" --arg blocker "$2" \
    '{status:"BLOCKED",branch:null,commits:[],summary:$msg,blockers:[$blocker]}' \
    > "$RESULT_FILE"
}

if [ ! -f "$TASK_FILE" ]; then
  write_blocked "task file not found" "missing: tasks/${SLUG}.md"
  exit 1
fi

PROMPT=$(cat <<EOF
You are a worker agent running inside a docker container. Your sandbox is /workspace
and you have full filesystem and shell access there. The host has already created
git branch feature/${SLUG} and checked it out in this worktree — do NOT switch branches.

Your task plan is at /workspace/tasks/${SLUG}.md. Read it now.

Execute the work described in the plan:
- If it has a "## Slices" section, execute each slice in order, one commit per slice
  (write the failing test first, then minimum code to pass, then refactor).
- If it has a "## Steps" section, execute each step in order.
- Make commits with descriptive messages that name the slice/step.

When all work is done — or you are blocked and cannot continue — use the Write tool
to create /workspace/.worker-result.json with EXACTLY this schema:

{
  "status": "APPROVE" | "BLOCKED",
  "branch": "feature/${SLUG}",
  "commits": ["<short sha>", "<short sha>", ...],
  "summary": "<one-sentence summary of what you did>",
  "blockers": ["<reason>", ...]
}

Use "APPROVE" only if every slice/step completed cleanly. Use "BLOCKED" if you could
not finish; populate "blockers" with the reasons. Always populate "commits" with the
short SHAs of the commits you made on this branch.

After writing the result file, stop.
EOF
)

claude --print --dangerously-skip-permissions "$PROMPT" || true

if [ ! -f "$RESULT_FILE" ]; then
  write_blocked "worker exited without writing result file" "no .worker-result.json after claude --print"
  exit 1
fi

if ! jq -e '.status == "APPROVE" or .status == "BLOCKED"' "$RESULT_FILE" >/dev/null 2>&1; then
  write_blocked "worker wrote malformed result file" "status field missing or not APPROVE/BLOCKED"
  exit 1
fi
