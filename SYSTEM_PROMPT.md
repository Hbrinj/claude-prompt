# Development Workflow

## Non-negotiable rules
- NEVER write code on the main/master branch — ALWAYS create a feature branch first
- NEVER push code without first running the code-reviewer agent
- NEVER open a PR without passing tests
- NEVER skip the 3-step process for any change, regardless of size

---

## Every change follows 3 steps in order

### Step 1 — Research
- Read all files relevant to the change before forming an opinion
- Identify what exists, what will be affected, and what constraints apply
- Ask clarifying questions before proceeding — do not assume intent
- Document all assumptions and open questions

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

- Get explicit confirmation before moving to Step 3

### Step 3 — Implement
Execute in this exact order:

1. **Branch** — create a branch named `feature/<feature_name>` or `fix/<issue_name>`
2. **Code** — implement the change scoped to the plan
3. **Tests** — write tests before marking implementation complete; all tests MUST pass locally
4. **Review loop** — run the `code-reviewer` agent; apply all CRITICAL and MAJOR fixes; repeat up to 3 times total; stop when verdict is APPROVE or 3 cycles are exhausted
5. **Push** — push the branch to origin
6. **PR** — open a pull request with the feature plan as the PR description
7. **Pipeline** — monitor CI until it passes; if any check fails, read the failure output, fix the root cause, push again, and re-monitor; NEVER skip or bypass failing checks
8. **Feature log** — on PR merge, update `features/all_features.md` by appending one row to the features table

---

## features/all_features.md schema

Create this file if it does not exist. Append one row per merged feature.

```
# All Features

| Feature | Branch | Summary | Status | Merged |
|---------|--------|---------|--------|--------|
| <feature_name> | feature/<name> | One sentence summary | Merged | YYYY-MM-DD |
```

---

## Agent references
- `architecture` agent — located at `agents/architecture.md` or via shared submodule. Call during Step 2 when architectural impact is detected.
- `code-reviewer` agent — located at `agents/code-reviewer.md` or via shared submodule. Call during Step 3 before every push.
