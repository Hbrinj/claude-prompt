# Checkpoint: integrate-mattpocock-skills

## Status
Step 2 — Implement — IN PROGRESS (PR-A open as #24; PR-B built, awaiting review gate)

## Completed steps
- [x] Step 1 — Plan (plan at `tasks/integrate-mattpocock-skills.md`; decisions via AskUserQuestion 2026-06-12)
- [~] Step 2 — Implement (PR-A open #24; PR-B built on stacked branch, pre-gate)

## Resumption notes
- All four open questions resolved on 2026-06-12 (see plan `## Resolved`) + user directive: remove parallel-dispatch entirely; issue-tracker as source of truth; delete `architecture` + `grill-plan` + `prompt-master`; two-PR phasing.
- **PR-A (`feature/integrate-mattpocock-skills`, additive — OPEN as PR #24):** vendored all 10 Pocock skills (31 files @ upstream 694fa30) + `skills/NOTICE.md` + catalogue rows; scoped vendored dirs out of `prompt-definition-reviewer` + the implement-feature routing gate. Both reviewers APPROVE (2 cycles).
- **PR-B (`feature/rewire-coordinator-workflow`, STACKED on PR-A — built, pre-gate):** rewrote `SYSTEM_PROMPT.md` + `skills/implement-feature.md` to the issue-tracker workflow (Step 1 = /grill-with-docs→/to-prd→/to-issues; Step 2 = /tdd-driven); retargeted 7 developer agents to `/tdd` (via shell-developer); narrowed `issue-liaison` to comms-only; deleted `grill-plan`, both dispatch skills, `docker/`, 9 dispatch scripts, `agents/architecture.md`, `skills/prompt-master/`; scrubbed all references (sweep clean). Next: PR-B reviewer gate → user review gate → open PR-B (base = PR-A branch; retarget to main after PR-A merges).
- **Merge order:** merge PR-A (#24) to main FIRST, then retarget PR-B's base to main and merge. Then Step 8: refresh `~/.claude/CLAUDE.md` from the new `SYSTEM_PROMPT.md`.

## Last updated
2026-06-12
