---
name: implement-feature
version: 2.0.0
description: Step 2 of the coordinator workflow — implements one approved issue. Use when Step 1 (/grill-with-docs → /to-prd → /to-issues) has produced an approved issue on the tracker and the user has approved implementation. Owns the full sub-step sequence — feature branch, /tdd implementation via the stack developer agent, file-type reviewer routing gate, feature log, push, review gate, PR, CI monitoring.
---

## Starting state

An approved issue exists on the tracker (Step 1 complete: `/grill-with-docs` → `/to-prd` → `/to-issues`) and the user has explicitly approved implementation. No `feature/<slug>` branch exists yet for this issue.

## Target state

A pushed feature branch whose diff every triggered reviewer has APPROVED, a feature-log row with status `In Review`, a checkpoint with status COMPLETE, and — after the user approves at the review gate — an open PR with CI passing.

## Execute in this exact order

1. **Branch** — create `feature/<issue-slug>` or `fix/<issue-slug>`.

2. **Code + self-review** — delegate to the developer agent matching the tech stack (see `## Developer-agent routing` below). Pass the issue (number/URL/body) as its brief.
   - The developer agent follows `/tdd` for the red-green-refactor loop: one vertical slice per cycle, failing test first → minimum implementation to pass → refactor, applying its own stack-specific testing rules within that loop. Each slice is one commit naming the slice.
   - The developer agent owns its own self-review loop per its agent prompt (`## Self-review before return`): after the last slice/commit, it invokes `code-reviewer`, applies CRITICAL+MAJOR findings, and repeats up to 3 cycles or until APPROVE before returning. The coordinator does NOT run `code-reviewer` separately.

3. **File-type routing gate** — after the developer-agent self-review completes (or in lieu of it for non-code work), inspect the diff. For each touched file-type bucket, ensure the corresponding reviewer has APPROVED; run any missing reviewer now in its own self-review loop (≤3 cycles, apply CRITICAL+MAJOR each round, surface MINOR/SUGGESTION once at the end):
   - Files under `agents/` or `skills/` → run `prompt-definition-reviewer` (`agents/prompt-definition-reviewer.md`), EXCEPT files under a vendored skill directory listed in `skills/NOTICE.md` (third-party — not gated here).
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

7. **PR** — open a pull request; link the issue it implements (e.g. "Closes #N") and summarise the slices delivered.

8. **Pipeline** — monitor CI until it passes; if any check fails, read the failure, fix the root cause, push again, re-monitor; NEVER skip or bypass failing checks.

## Developer-agent routing

| Stack | Agent |
|-------|-------|
| Android/Kotlin mobile | `agents/android-developer.md` |
| iOS/Swift | `agents/ios-developer.md` |
| Flutter/Dart | `agents/flutter-developer.md` |
| Kotlin backend/AWS | `agents/kotlin-backend-developer.md` |
| Go (CLI tools, services, libraries) | `agents/go-developer.md` |
| Bash/shell scripts + the adjacent markdown prose documenting them | `agents/shell-developer.md` |
| React + TypeScript web (SPA, components, hooks, client-side logic) | `agents/react-typescript-developer.md` |

Each developer agent follows `/tdd` for the red-green-refactor loop and supplies only its stack-specific testing/idiom rules.

Supporting agents and skills: `skills/tdd/` (the red-green-refactor methodology every developer agent follows), `agents/code-reviewer.md` (invoked by the developer agent's self-review loop), `agents/prompt-definition-reviewer.md` and `agents/general-reviewer.md` (invoked by the routing gate in step 3), `agents/issue-liaison.md` (posts status + the PR link on GitHub-issue-driven work), `agents/security-reviewer.md` (on demand). Step 1 skills (`/grill-with-docs`, `/to-prd`, `/to-issues`) and supporting skills (`/diagnose`, `/improve-codebase-architecture`, `/triage`, `/prototype`, `/zoom-out`) are coordinator-invoked outside this skill.

## Allowed actions

- Create and switch to the feature branch; commit on it.
- Dispatch developer and reviewer agents and read their reports.
- Edit `features/all_features.md` and `features/<feature_name>.checkpoint.md`; apply reviewer CRITICAL+MAJOR findings to files in the diff.
- Push the feature branch to origin; open the PR after explicit user approval; monitor CI.

## Forbidden actions

- NEVER push to main/master.
- NEVER push any branch before every reviewer triggered by the diff has returned APPROVE.
- NEVER open a PR without passing tests, or before the user approves at the review gate (step 6).
- NEVER write implementation code directly — delegate to the matching developer agent.
- NEVER stage or commit files unrelated to this feature.

## Stop and ask before

- Proceeding when no developer agent matches the tech stack.
- Continuing past a reviewer loop that still returns REQUEST CHANGES after 3 cycles.
- Any destructive git operation (rebase, force-push, history rewrite).
- Opening the PR — the step 6 review gate is mandatory.

## Checkpoint format

This skill writes a checkpoint at the end of Step 2 (Implement). The same format is used by the coordinator for the Step 1 — Plan checkpoint; it is defined here as the canonical reference:

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
