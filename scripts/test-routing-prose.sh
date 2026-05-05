#!/usr/bin/env bash
# Slice 6 test: SYSTEM_PROMPT.md describes when to invoke
# parallel-docker-dispatch vs the default parallel-dispatch, in language the
# coordinator can act on.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SP="SYSTEM_PROMPT.md"

[ -f "$SP" ]                                                     || { echo "FAIL: $SP missing"; exit 1; }

# 1. Both skills referenced.
grep -q "parallel-dispatch"        "$SP"                          || { echo "FAIL: $SP does not reference parallel-dispatch"; exit 1; }
grep -q "parallel-docker-dispatch" "$SP"                          || { echo "FAIL: $SP does not reference parallel-docker-dispatch"; exit 1; }

# 2. The Docker trigger paragraph contains both the trigger phrase and the
#    skill name within ~10 lines of each other.
TRIGGER_LINE=$(grep -n "Docker-dispatch trigger" "$SP" | head -1 | cut -d: -f1)
[ -n "$TRIGGER_LINE" ]                                            || { echo "FAIL: no 'Docker-dispatch trigger' heading in $SP"; exit 1; }
WINDOW=$(awk -v start="$TRIGGER_LINE" 'NR>=start && NR<=start+10' "$SP")
echo "$WINDOW" | grep -qE "in containers|with docker|dockerised" || { echo "FAIL: Docker trigger paragraph has no trigger phrase"; exit 1; }
echo "$WINDOW" | grep -q "parallel-docker-dispatch"               || { echo "FAIL: Docker trigger paragraph does not name parallel-docker-dispatch"; exit 1; }

# 3. Skill index row exists.
grep -qE "parallel-docker-dispatch.*Step 2" "$SP"                 || { echo "FAIL: parallel-docker-dispatch missing from the Skill index"; exit 1; }

echo "PASS: SYSTEM_PROMPT.md contains an unambiguous routing rule for parallel-docker-dispatch."
