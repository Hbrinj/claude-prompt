# Checkpoint: integrate-mattpocock-skills

## Status
Step 2 — Implement — IN PROGRESS (PR-A built; awaiting review gate to open PR-A)

## Completed steps
- [x] Step 1 — Plan (plan at `tasks/integrate-mattpocock-skills.md`; decisions via AskUserQuestion 2026-06-12)
- [~] Step 2 — Implement (PR-A done; PR-B pending)

## Resumption notes
- All four open questions resolved on 2026-06-12 (see plan `## Resolved`): remove parallel-dispatch entirely; issue-tracker as source of truth; delete `architecture` + `grill-plan`; two-PR phasing.
- **PR-A (this branch, additive — committed):** vendored all 10 Pocock skills (31 files @ upstream 694fa30) + `skills/NOTICE.md` + catalogue rows; scoped vendored dirs out of `prompt-definition-reviewer` + the implement-feature routing gate. prompt-definition-reviewer + general-reviewer ran (cycle 1 → REQUEST CHANGES; cycle-1 fixes applied). Next: re-review (cycle 2), then user review gate to open PR-A.
- **PR-B (next, separate branch):** Steps 4–7 invasive rewire — rewrite Step 1/2 to the issues contract, clean up 7 developer agents to defer to `/tdd`, narrow `issue-liaison`, delete `architecture`/`grill-plan`/dispatch (`docker/` + 9 scripts), then refresh `~/.claude/CLAUDE.md`.

## Last updated
2026-06-12
