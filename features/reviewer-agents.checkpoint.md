# Checkpoint: reviewer-agents

## Status
Step 2 — Implement — IN PROGRESS

## Completed steps
- [x] Step 1 — Plan (approved by user)
- [ ] Step 2 — Implement

## Resumption notes
Plan finalised at `tasks/reviewer-agents.md` with 9 decisions, 6 implementation steps, 0 open questions. 5 deferrals consolidated into `/TODO.md` under `## From feature/reviewer-agents`.

Branch `feature/reviewer-agents` created from `main`. Implementation in progress: writing two new agent files (`agents/prompt-definition-reviewer.md`, `agents/general-reviewer.md`), updating `agents/README.md`, updating `SYSTEM_PROMPT.md` (non-negotiable rule, Step 2 routing sub-step, Agent index), appending to `features/all_features.md`.

Bootstrap caveat acknowledged at Step 1 hand-off: the new reviewers cannot self-review on their first introduction (chicken-and-egg). For this feature only, the existing `code-reviewer` will run against the diff as a manual bootstrap — flagged in the PR description.

Will pause at the Step 2 review gate (after commit, before push) to confirm push and PR with the user.

## Last updated
2026-05-04
