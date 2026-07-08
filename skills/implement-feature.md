---
name: implement-feature
version: 3.0.0
description: Step 2 of the coordinator workflow — implements one approved issue in the standard or high-risk lane. Use when Step 1 has produced an approved issue on the tracker and the user has approved implementation. Owns the full sub-step sequence — feature branch, developer-agent implementation with enforced TDD outcomes, verification by execution, single fresh-context reviewer pass, review-evidence record, issue status comments, push, review gate, PR, CI monitoring.
---

## Starting state

An approved issue exists on the tracker (Step 1 complete) and the user has explicitly approved implementation. The lane is known: standard, or high-risk (which adds `security-reviewer` and human diff review — see step 4). No `feature/<slug>` branch exists yet for this issue. Express-lane work does not enter this skill — it is handled inline per `SYSTEM_PROMPT.md`.

## Target state

A pushed feature branch with a review-evidence record matching HEAD, a status comment trail on the issue, and — after the user approves at the review gate — an open PR carrying the evidence summary, with CI passing.

## Execute in this exact order

1. **Branch** — create `feature/<issue-slug>` or `fix/<issue-slug>`.

2. **Implement** — dispatch the `developer` agent (`agents/developer.md`) with the issue (number/URL/body) as its brief and the stack brief path from `## Stack-brief routing` below. The developer follows `/tdd` with enforced outcomes — every test observed failing before the code that passes it, one slice per commit — and returns an evidence report (red/green output per slice, full-suite run, verification-command status). It does NOT run a review loop.

3. **Verify by execution** — before any review:
   - Run the full test suite yourself; capture the summary output.
   - Drive the affected flow end-to-end — run the app/CLI/service and exercise the change the way a user would, not only through the tests. Capture what you observed.
   - If the diff has no runtime surface to drive (pure docs/config), record that and why.

4. **Review — one fresh-context pass, plus one confirm re-pass after fixes** — dispatch the `reviewer` agent (`agents/reviewer.md`) with the issue brief, the developer's evidence report, and your verification output. It returns claims-with-evidence findings and a verdict.
   - Apply CRITICAL and MAJOR findings (route code fixes through the `developer` agent), then re-invoke `reviewer` ONCE to confirm the fixes. Surface MINOR/SUGGESTION findings to the user unapplied.
   - If the confirm pass still returns REQUEST CHANGES, stop and ask the user.
   - **High-risk lane only**: also dispatch `security-reviewer`; any new CRITICAL or HIGH finding in files the diff touches blocks until resolved.

5. **Review-evidence record** — write `.claude/review-evidence/<branch-slug>.md` (slug = branch name with `/` → `-`; schema below). The `guard-push-review` hook blocks pushing a `feature/*`/`fix/*` branch without a record matching HEAD — any new commit invalidates the record, so re-run steps 3–5 after applying changes. The record is local state: gitignored, NEVER committed.

6. **Status comment** — post a status comment on the issue (via `issue-liaison` for GitHub; tracker-appropriate otherwise) using `## Status comment format` below. These comments are the workflow's pause/resume state — there are no local checkpoint files.

7. **Push** — push the feature branch to origin. NEVER push main/master.

8. **Review gate** — present to the user:

   ```
   ## Implementation complete — review required before PR

   ### Branch
   <branch name> (<commit list>)

   ### Evidence
   - Tests: <full-suite summary line>
   - Flow driven: <what was exercised and observed>
   - Reviewer verdict: <APPROVE / findings applied>
   - Red/green: <one line per slice>

   ### What was done
   <bullet summary>
   ```

   High-risk lane: explicitly request human review of the diff itself, not just the evidence. Stop and ask: *"Implementation is complete. Approve to open the PR, or provide feedback to address first."* MUST wait for explicit approval.

9. **PR** — open a pull request; link the issue (e.g. "Closes #N") and include the evidence summary from step 8 in the body.

10. **Pipeline** — monitor CI until it passes; if any check fails, read the failure, fix the root cause (route code fixes through `developer`, re-running steps 3–5), push again, re-monitor. NEVER skip or bypass failing checks.

## Stack-brief routing

| Stack | Brief |
|-------|-------|
| Android/Kotlin mobile | `skills/stacks/android.md` |
| iOS/Swift | `skills/stacks/ios.md` |
| Flutter/Dart | `skills/stacks/flutter.md` |
| Kotlin backend/AWS | `skills/stacks/kotlin-backend.md` |
| Go (CLI tools, services, libraries) | `skills/stacks/go.md` |
| Bash/shell scripts + the adjacent markdown prose documenting them | `skills/stacks/shell.md` |
| React + TypeScript web (SPA, components, hooks, client-side logic) | `skills/stacks/react-typescript.md` |

Supporting agents and skills: `skills/tdd/SKILL.md` (the red-green-refactor methodology the developer follows), `agents/reviewer.md` (step 4 gate), `agents/security-reviewer.md` (step 4, high-risk lane; on demand otherwise), `agents/issue-liaison.md` (status comments + PR link on GitHub-issue-driven work). Step 1 skills (`/grill-with-docs`, `/to-prd`, `/to-issues`) and supporting skills (`/diagnose`, `/improve-codebase-architecture`, `/triage`, `/prototype`, `/zoom-out`) are coordinator-invoked outside this skill.

## Review-evidence record schema

```
# Review evidence: <branch>

HEAD: <full commit sha>
Lane: express | standard | high-risk
Date: YYYY-MM-DD

## Verification
<commands run + key output lines: test totals, flow driven and what was observed>

## Review
Verdict: APPROVE (<N> findings applied) | express-lane self-verified
<one line per applied finding, or "no findings">
```

The `guard-push-review` hook checks only that the record exists for the branch and that its `HEAD:` line matches the current commit — the content discipline is this skill's contract.

## Status comment format

```
**Status — <implementing | in review | pushed | PR opened #N | blocked>**
Branch: <name> @ <short sha>
<one sentence on what just completed or started>
<resumption notes when pausing: decisions, open questions, next action>
```

## Allowed actions

- Create and switch to the feature branch; commit on it.
- Dispatch `developer`, `reviewer`, `security-reviewer`, and `issue-liaison` agents and read their reports.
- Run the test suite and drive the affected flow for step 3 verification.
- Write `.claude/review-evidence/<branch-slug>.md`; apply reviewer findings to files in the diff (code fixes via `developer`).
- Push the feature branch to origin; open the PR after explicit user approval; monitor CI.

## Forbidden actions

- NEVER push to main/master.
- NEVER push a `feature/*`/`fix/*` branch without a review-evidence record matching HEAD.
- NEVER commit `.claude/review-evidence/` — it is local state.
- NEVER open a PR before the user approves at the review gate (step 8).
- NEVER write implementation code directly — delegate to the `developer` agent.
- NEVER weaken, delete, or disable a test to get to green — that is a blocking finding, not a fix.
- NEVER stage or commit files unrelated to this feature.

## Stop and ask before

- Proceeding when no stack brief matches the tech stack.
- Continuing past a reviewer confirm pass that still returns REQUEST CHANGES.
- Any destructive git operation (rebase, force-push, history rewrite).
- Opening the PR — the step 8 review gate is mandatory.
