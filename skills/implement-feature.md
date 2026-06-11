---
name: implement-feature
version: 1.0.0
description: Step 2 of the coordinator workflow — implements one planned feature. Use when an approved plan exists at tasks/<slug>.md and the user has approved implementation. Owns the full sub-step sequence - feature branch, developer-agent delegation with TDD slices, file-type reviewer routing gate, feature log, push, review gate, PR, CI monitoring. For ≥2 features dispatched together, use parallel-dispatch instead (it reuses this flow per feature).
---

## Starting state

An approved plan exists at `tasks/<feature-slug>.md` (Step 1 complete) and the user has explicitly approved implementation. No `feature/<slug>` branch exists yet for this feature.

## Target state

A pushed feature branch whose diff every triggered reviewer has APPROVED, a feature-log row with status `In Review`, a checkpoint with status COMPLETE, and — after the user approves at the review gate — an open PR with CI passing.

## Execute in this exact order

1. **Branch** — create `feature/<feature_name>` or `fix/<issue_name>`.

2. **Code + self-review** — delegate to the developer agent matching the tech stack (routing table in the system prompt). Pass the task file (`tasks/<feature-slug>.md`) as its brief.
   - **If the plan contains `## Slices`**, the developer agent MUST execute one slice per commit, in order: write the failing test first, then the minimum implementation to pass, then the refactor. Each commit message names the slice.
   - The developer agent owns its own self-review loop per its agent prompt (`## Self-review before return`): after the last slice/commit, it invokes `code-reviewer`, applies CRITICAL+MAJOR findings, and repeats up to 3 cycles or until APPROVE before returning. The coordinator does NOT run `code-reviewer` separately in serial mode.

3. **File-type routing gate** — after the developer-agent self-review completes (or in lieu of it for non-code work), inspect the diff. For each touched file-type bucket, ensure the corresponding reviewer has APPROVED; run any missing reviewer now in its own self-review loop (≤3 cycles, apply CRITICAL+MAJOR each round, surface MINOR/SUGGESTION once at the end):
   - Files under `agents/` or `skills/` → run `prompt-definition-reviewer` (`agents/prompt-definition-reviewer.md`).
   - Files matching the general allowlist (`*.md` outside `agents/`/`skills/`; `*.json` / `*.yml` / `*.yaml` / `*.toml`; `tasks/*.md`; `features/*.md`) → run `general-reviewer` (`agents/general-reviewer.md`).
   - Pure-code diffs are already covered by the developer-agent self-review and need no extra run here.
   - Mixed diffs run every reviewer whose bucket is touched. Push is blocked until every triggered reviewer returns APPROVE.

4. **Feature log** — append one row to `features/all_features.md` (create if missing) with status `In Review`; commit on the feature branch before the PR is opened. Schema:

   ```
   # All Features

   | Feature | Branch | Summary | Status | Merged |
   |---------|--------|---------|--------|--------|
   | <feature_name> | feature/<name> | One sentence summary | In Review | YYYY-MM-DD |
   ```

5. **Push** — push the feature branch to origin. NEVER push main/master.

6. **Review gate** — write the checkpoint with status COMPLETE, then present:

   ```
   ## Implementation complete — review required before PR

   ### Branch
   <branch name>

   ### Commits on branch
   <list>

   ### Feature log entry
   <the row added to features/all_features.md>

   ### What was done
   <bullet summary>
   ```

   Stop and ask: *"Implementation is complete. Approve to open the PR, or provide feedback to address first."* MUST wait for explicit approval before continuing.

7. **PR** — open a pull request with the plan from `tasks/<feature-slug>.md` as the PR description.

8. **Pipeline** — monitor CI until it passes; if any check fails, read the failure, fix the root cause, push again, re-monitor; NEVER skip or bypass failing checks.

## Checkpoint format

Every step (including Step 1 — Plan) ends by writing a checkpoint to `features/<feature_name>.checkpoint.md`:

```
# Checkpoint: <feature_name>

## Status
Step <N> — <step name> — COMPLETE | IN PROGRESS | BLOCKED

## Completed steps
- [ ] Step 1 — Plan
- [ ] Step 2 — Implement

## Resumption notes
<decisions, open questions, or state the next session needs to know>

## Last updated
<YYYY-MM-DD>
```
