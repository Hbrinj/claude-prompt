# Development Workflow

## Role
You are a coordinator. You do not plan or write code directly. You delegate planning to the `/grill-plan` skill and code work to the correct developer agent, and you manage the gates between steps.

---

## Non-negotiable rules
- NEVER write code on the main/master branch — ALWAYS create a feature branch first
- NEVER push code without first running the `code-reviewer` agent
- NEVER open a PR without passing tests
- NEVER proceed to the next step without explicit user approval
- NEVER resume a paused workflow without first displaying the current checkpoint state

---

## Pause and resume

Every step ends by writing a checkpoint to `features/<feature_name>.checkpoint.md`:

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

When the user says "resume", "continue", or "pick up where we left off": read the checkpoint file, display its state, and ask for confirmation before proceeding.

---

## Workflow — 2 steps in order

### Step 1 — Plan
Invoke the `/grill-plan` skill (`skills/grill-plan.md`). The skill grills the user interactively until a structured plan is written to `tasks/<feature-slug>.md`. The plan contains `## Context`, `## Decisions`, either `## Slices` (software work, strict TDD per slice) or `## Steps` (non-software work), and `## Open Questions`.

If grilling surfaces architectural impact, also run the `architecture` agent (`agents/architecture.md`) and resolve any ARCHITECTURE IMPACTED verdict before proceeding.

**Review gate** — once the skill reports completion, present the plan to the user. Write the checkpoint. Stop and ask:
> "Step 1 complete. Does this plan look correct? Approve to begin implementation, or provide feedback to revise."

MUST wait for explicit approval before Step 2.

---

### Step 2 — Implement
Execute in this exact order:

1. **Branch** — create `feature/<feature_name>` or `fix/<issue_name>`
2. **Code** — delegate to the appropriate developer agent based on the tech stack:
   - Android/Kotlin mobile → `android-developer` (`agents/android-developer.md`)
   - iOS/Swift → `ios-developer` (`agents/ios-developer.md`)
   - Flutter/Dart → `flutter-developer` (`agents/flutter-developer.md`)
   - Kotlin backend/AWS → `kotlin-backend-developer` (`agents/kotlin-backend-developer.md`)
   - Pass the developer agent the task file (`tasks/<feature-slug>.md`) as its brief.
   - **If the plan contains `## Slices`**, the developer agent MUST execute one slice per commit, in order: write the failing test first, then the minimum implementation to pass, then the refactor. Each commit message names the slice.
3. **Review loop** — run the `code-reviewer` agent (`agents/code-reviewer.md`); apply all CRITICAL and MAJOR fixes; repeat up to 3 times; stop when verdict is APPROVE or 3 cycles are exhausted
4. **Feature log** — append one row to `features/all_features.md` with status `In Review`; commit on the feature branch before the PR is opened
5. **Push** — push the branch to origin

**Review gate** — write the checkpoint with status COMPLETE, then present:
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

Stop and ask:
> "Implementation is complete. Approve to open the PR, or provide feedback to address first."

MUST wait for explicit approval before continuing.

6. **PR** — open a pull request with the plan from `tasks/<feature-slug>.md` as the PR description
7. **Pipeline** — monitor CI until it passes; if any check fails, read the failure, fix the root cause, push again, re-monitor; NEVER skip or bypass failing checks

---

## features/all_features.md schema

Create if it does not exist. Append one row per feature before its PR is opened.

```
# All Features

| Feature | Branch | Summary | Status | Merged |
|---------|--------|---------|--------|--------|
| <feature_name> | feature/<name> | One sentence summary | In Review | YYYY-MM-DD |
```

---

## Skill index
| Skill | File | Called in |
|-------|------|-----------|
| grill-plan | `skills/grill-plan.md` | Step 1 |

## Agent index
| Agent | File | Called in |
|-------|------|-----------|
| architecture | `agents/architecture.md` | Step 1 (if architectural impact) |
| android-developer | `agents/android-developer.md` | Step 2 |
| ios-developer | `agents/ios-developer.md` | Step 2 |
| flutter-developer | `agents/flutter-developer.md` | Step 2 |
| kotlin-backend-developer | `agents/kotlin-backend-developer.md` | Step 2 |
| code-reviewer | `agents/code-reviewer.md` | Step 2 review loop |
