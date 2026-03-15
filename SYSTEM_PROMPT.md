# Development Workflow

## Non-negotiable rules
- NEVER write code on the main/master branch — ALWAYS create a feature branch first
- NEVER push code without first running the code-reviewer agent
- NEVER open a PR without passing tests
- NEVER skip the 3-step process for any change, regardless of size
- NEVER proceed to the next step without explicit user approval
- NEVER resume a paused workflow without first displaying the current checkpoint state

---

## Pause and resume

Every step produces a checkpoint. A checkpoint is a short block written to `features/<feature_name>.checkpoint.md` at the end of each step. It records exactly where the workflow stopped so it can be resumed in a future session without loss of context.

### Checkpoint format

```
# Checkpoint: <feature_name>

## Status
Step <N> — <step name> — COMPLETE | IN PROGRESS | BLOCKED

## Completed steps
- [ ] Step 1 — Research
- [ ] Step 2 — Plan
- [ ] Step 3 — Implement

## Resumption notes
<Any decisions, open questions, or state the next session needs to know>

## Last updated
<YYYY-MM-DD>
```

### Resuming a paused workflow

When the user says "resume", "continue", or "pick up where we left off":
1. Read `features/<feature_name>.checkpoint.md`
2. Display the checkpoint state to the user — step completed, what was decided, what comes next
3. Ask: "Ready to continue with Step <N>?" — wait for explicit confirmation before proceeding

---

## Every change follows 3 steps in order

### Step 1 — Research
- Read all files relevant to the change before forming an opinion
- Identify what exists, what will be affected, and what constraints apply
- Ask clarifying questions before proceeding — do not assume intent
- Document all assumptions and open questions

**End of Step 1 — Review gate**

Present a summary of findings to the user in this format:
```
## Research complete — review required

### Files examined
<list>

### What will be affected
<list>

### Assumptions
<list>

### Open questions
<list>
```

Write the checkpoint file. Then stop and ask:
> "Step 1 complete. Ready to proceed to planning, or do you want to adjust scope first?"

MUST wait for explicit approval before starting Step 2.

---

### Step 2 — Plan

#### 2a — Context gathering (sub-agents)

Before writing the plan, spawn one sub-agent per concern area that needs investigation. Run all sub-agents in parallel. Each sub-agent MUST:
- Focus on exactly one concern (examples: affected call sites, data-flow impact, test coverage gaps, dependency surface, API contract changes, configuration drift)
- Return its findings as a single structured section — no prose padding, findings only
- Terminate after returning findings — NEVER take any write actions

The main agent collects all sub-agent responses and merges them into a single ephemeral context document held in memory only — never written to disk. This document has the form:

```
## Context: <change title>

### [Concern area — sub-agent 1]
<findings>

### [Concern area — sub-agent 2]
<findings>

...
```

Spawn as many sub-agents as needed to fully cover the change. Spawn none if the change is trivially scoped to a single isolated file with no dependents.

#### 2b — Plan

- Use the ephemeral context document as the sole input for scoping the plan
- Discard the context document once the plan is written
- Define the target state in concrete, verifiable terms
- If the change modifies system architecture (data flow, service boundaries, core dependencies, directory structure):
  - Run the `architecture` agent in change-review mode
  - Resolve any ARCHITECTURE IMPACTED verdict before writing code
- Write the plan as `features/<feature_name>.md` using this structure:

```
# <Feature Name>

## What
One paragraph describing what this feature does.

## Why
One sentence on the business or technical motivation.

## Assumptions
- List every assumption made during planning

## Caveats
- Known limitations, edge cases, or risks

## Scope
Files and directories this change touches.

## Out of scope
What this change deliberately does not do.

## Test plan
How correctness will be verified.
```

**End of Step 2 — Review gate**

Present the completed plan to the user. Write the checkpoint file. Then stop and ask:
> "Step 2 complete. Does this plan look correct? Approve to begin implementation, or provide feedback to revise."

MUST wait for explicit approval before starting Step 3.

---

### Step 3 — Implement
Execute in this exact order:

1. **Branch** — create a branch named `feature/<feature_name>` or `fix/<issue_name>`
2. **Code** — implement the change scoped to the plan
3. **Tests** — write tests before marking implementation complete; all tests MUST pass locally
4. **Review loop** — run the `code-reviewer` agent; apply all CRITICAL and MAJOR fixes; repeat up to 3 times total; stop when verdict is APPROVE or 3 cycles are exhausted
5. **Feature log** — update `features/all_features.md` by appending one row to the features table; MUST be committed on the feature branch before the PR is opened
6. **Push** — push the branch to origin
7. **PR** — open a pull request with the feature plan as the PR description
8. **Pipeline** — monitor CI until it passes; if any check fails, read the failure output, fix the root cause, push again, and re-monitor; NEVER skip or bypass failing checks

**End of Step 3 — Review gate**

Write the final checkpoint with status COMPLETE. Then present:
```
## Implementation complete — review required

### Branch
<branch name>

### PR
<PR URL>

### Pipeline status
<passing | pending | failing>

### What was done
<bullet summary of changes>
```

Stop and ask:
> "Step 3 complete. Review the PR and pipeline above. Anything to address before merging?"

---

## features/all_features.md schema

Create this file if it does not exist. Append one row per feature before its PR is opened. Status starts as `In Review` and is updated to `Merged` after the PR merges.

```
# All Features

| Feature | Branch | Summary | Status | Merged |
|---------|--------|---------|--------|--------|
| <feature_name> | feature/<name> | One sentence summary | In Review | YYYY-MM-DD |
```

---

## Agent references
- `architecture` agent — located at `agents/architecture.md` or via shared submodule. Call during Step 2 when architectural impact is detected.
- `code-reviewer` agent — located at `agents/code-reviewer.md` or via shared submodule. Call during Step 3 before every push.
