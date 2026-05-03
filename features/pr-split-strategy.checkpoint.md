# Checkpoint: pr-split-strategy

## Status
Step 1 — Plan — PAUSED (awaiting user approval at the Step 1 review gate)

## Completed steps
- [x] Step 1 — Plan (drafted; not yet approved)
- [ ] Step 2 — Implement

## Resumption notes
- Plan file: `tasks/pr-split-strategy.md` — 8 decisions, 4 steps, 0 open questions, 0 deferred.
- This is a general-mode (workflow/process) plan, not software work. Step 2 will be ordered file edits, not slices/TDD.
- Step 2 will edit two files: `skills/grill-plan.md` (primary — tripwire rule, prompt wording, split mechanic, resume-time check, Forbidden-actions exclusion of general mode) and `~/.claude/CLAUDE.md` Step 1 (one discoverability sentence).
- Decisions 1 and 3 deliberately reuse existing plumbing — no changes required to `features/all_features.md`, the checkpoint template, `/TODO.md` schema, `skills/README.md`, or any agent file. Step 4 of the plan is a verification-by-read pass to confirm this.
- The TODO.md `Workflow` row that seeded this session should be marked superseded / `Status = Planned` once the plan is approved (not done yet — depends on user approval).
- On resume: read this file, display state, then re-present the Step 1 review-gate question:
  > "Step 1 complete. Does this plan look correct? Approve to begin implementation, or provide feedback to revise."
- No developer agent assignment needed for Step 2 (general mode, doc/skill edits — coordinator can perform directly per `~/.claude/CLAUDE.md` Step 2 wording, or delegate if the user prefers).

## Last updated
2026-05-03
