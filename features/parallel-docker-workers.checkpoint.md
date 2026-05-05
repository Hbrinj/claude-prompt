# Checkpoint: parallel-docker-workers

## Status
MERGED

## Completed steps
- [x] Step 1 — Plan
- [x] Step 2 — Implement
- [x] PR opened (#17)
- [x] PR merged (origin/main @ f812529)

## Resumption notes
All 6 slices implemented, all three reviewers (code-reviewer,
prompt-definition-reviewer, general-reviewer) APPROVED on cycle 2, PR #17
merged into main on 2026-05-05.

Live macOS run surfaced two follow-ups, logged in /TODO.md:
- Canary fixture missing in worker worktree (worktree cut from `main`,
  fixture lives only on the feature branch) — both dispatch tests come back
  BLOCKED until fixed.
- `test-dispatch-parallel.sh` 4th-worker hang (only 3 of 4 worktrees
  materialise; parent script idles at `wait`). Masked by the fixture issue.

README also gained a "Dispatch scripts — host requirements" section
documenting `brew install coreutils flock` for macOS.

## Last updated
2026-05-05
