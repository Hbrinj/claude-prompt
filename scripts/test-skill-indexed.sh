#!/usr/bin/env bash
# Slice 4 test: parallel-docker-dispatch.md exists, is indexed in
# skills/README.md and SYSTEM_PROMPT.md, and its prose covers the 12 grilled
# decisions (probed via keyword grep).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SKILL="skills/parallel-docker-dispatch.md"

[ -f "$SKILL" ]                                                   || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "parallel-docker-dispatch" skills/README.md                || { echo "FAIL: skills/README.md does not link parallel-docker-dispatch"; exit 1; }
grep -q "parallel-docker-dispatch" SYSTEM_PROMPT.md                || { echo "FAIL: SYSTEM_PROMPT.md does not reference parallel-docker-dispatch"; exit 1; }

# Decision-coverage probes. Each must appear in the skill prose.
needles=(
  "in containers"               # trigger phrasing (Decision 11)
  "claude-worker"               # image (Decision 7)
  "CLAUDE_CODE_OAUTH_TOKEN"     # auth (Decision 3)
  "worktree"                    # filesystem (Decision 4)
  "--print"                     # in-container process (Decision 2)
  "--dangerously-skip-permissions"  # also Decision 2
  ".worker-result.json"         # result return (Decision 5)
  "1800"                        # 30-min default timeout (Decision 9)
  "--rm"                        # always cleanup (Decision 9)
  "_canary"                     # verification (Decision 12)
  "cap of 3"                    # concurrency (Decision 10)
  "one whole feature"           # unit of work (Decision 1)
)
missing=0
for needle in "${needles[@]}"; do
  if ! grep -qF -e "$needle" "$SKILL"; then
    echo "FAIL: skill prose missing keyword: $needle"
    missing=$((missing+1))
  fi
done
[ $missing -eq 0 ]                                                || exit 1

echo "PASS: skill exists, indexed, and covers all 12 decisions by keyword."
