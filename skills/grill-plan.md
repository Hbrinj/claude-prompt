---
Name: grill-plan
Version: 1.0.0
Description: Use when the user wants to plan a feature, design a change, break work into vertical slices, or says "plan this" / "design this" / "let's break this down" / "grill me on a plan". Outputs to `tasks/<slug>.md`. Strict TDD shape for software work (vertical slices with one Red/Green/Refactor cycle each); plain ordered steps for non-software work.
---

## Starting state

The user has invoked `/grill-plan` with an optional topic as args. The `tasks/` directory may or may not exist. A task file at `tasks/<slug>.md` may or may not exist for this topic. A `## Requirements` section (written by `agents/issue-liaison.md`) may or may not be present in that file.

## Target state

`tasks/<slug>.md` exists and contains a fully populated structure: `## Context` (codebase facts and constraints learned during grilling), `## Decisions` (resolved questions with reasoning), either `## Slices` (software work, strict one-cycle TDD per slice) or `## Steps` (non-software work, ordered steps with binary acceptance), and `## Open Questions` (anything grilling could not resolve). Any `## Requirements` section present at invocation is preserved unchanged.

---

## Entry behaviour — execute in order

### Step E1 — Topic and slug

If args were provided, treat them as the topic. Otherwise, ask: *"What's the topic of the plan?"*

Derive a kebab-case slug proposal from the topic with this exact algorithm:

1. Lowercase the topic.
2. Replace any run of non-alphanumeric characters with a single `-`.
3. Collapse repeated `-` into a single `-`.
4. Trim leading and trailing `-`.
5. If the result exceeds 50 characters, truncate to 50 and re-trim trailing `-`.

Present the slug to the user: *"Proposed slug: `<slug>` → file: `tasks/<slug>.md`. Accept, or provide an alternative slug?"* Use the confirmed value. NEVER write to a file path the user has not confirmed.

### Step E2 — Resume vs restart

Check whether `tasks/<confirmed-slug>.md` exists.

- **Does not exist** → create `tasks/` if missing. Proceed to Step E3.
- **Exists** → read it fully. Print a one-line summary in this exact format:
  > `Found existing plan — Decisions: N · Slices/Steps: N · Open Questions: N · Requirements: present|absent · Last updated: <date>`

  Then ask: *"Resume from open items, or restart fresh (overwrites the file)?"* Wait for explicit "resume" or "restart". On `restart`, overwrite all sections except `## Requirements` (if present). On `resume`, jump to Step E5 with `## Open Questions` as the starting grilling agenda.

### Step E3 — Surface requirements (if any)

If the file exists and contains a `## Requirements` section (written by `agents/issue-liaison.md`), print the requirements verbatim under the heading:

> *"This plan has existing requirements from issue-liaison. Grilling will work toward addressing them — flag any to deprioritise before we start."*

Do NOT write to or modify `## Requirements` at any point in this skill. It is owned by `issue-liaison`.

### Step E4 — Software vs non-software discriminator

Ask exactly: *"Is this software work that produces executable behaviour, or something else (docs, RFC, infra config, vendor selection, design exploration)?"*

Record the answer as **Mode**: `software` or `general`. The mode determines the output template (`## Slices` or `## Steps`) and is included in every status postscript.

### Step E5 — Grill

Begin the grilling loop (see *Grilling rules* below). Continue until the user declares the plan should be written (see *Termination*).

---

## Grilling rules

- **One question at a time.** Never bundle multiple questions into a single turn.
- **For each question, provide your recommended answer** with reasoning, the way `/grill-me` does. The user is choosing among options, not generating answers from scratch.
- **Walk the decision tree in dependency order.** Resolve foundational decisions before dependent ones. If the user picks an option that invalidates a downstream branch, abandon that branch.
- **Always delegate codebase exploration to the `Explore` subagent.** Never run inline `Read`, `grep`, `find`, or `Bash` to inspect the codebase during grilling. When you need a codebase fact:
  - Invoke the `Agent` tool with `subagent_type: "Explore"`, `model: "sonnet"`, `description: <short>`, and a focused `prompt`.
  - Instruct the subagent to return a synthesised 1-2 paragraph answer, NOT raw tool output. Example prompt: *"Find where X is currently handled in this repo. Return a 1-2 paragraph synthesis with file:line references — do not paste full file contents."*
  - The Sonnet model (Decision 21) is the right capability/cost point for read-and-synthesise work; Opus is overkill, Haiku is under-powered.
- **Write incrementally to the task file.** As soon as a decision is resolved, append it to `## Decisions` in `tasks/<slug>.md`. As soon as a codebase fact is confirmed, append it to `## Context`. The conversation is scratch; the file is the source of truth. This makes `/clear` safe between sessions.

### Status postscript

After every 5th grilled question, OR whenever the user types "status", "where are we", or "summary", append this one-line postscript after your next question:

```
Status — Mode: <software|general> · Decisions: N · Slices: N (M complete) · Open Q: N · Requirements: N/M · File: tasks/<slug>.md
```

If the file has no `## Requirements`, omit the `Requirements: N/M` field. The postscript does not consume a turn — it tags onto the next normal grilling message.

---

## Termination

When the user says any of: *"write the plan"*, *"finalise"*, *"that's enough"*, *"go"*, or any clear directive to stop grilling — finalise the file:

1. Confirm all decisions are recorded in `## Decisions`.
2. Write the `## Slices` (software) or `## Steps` (general) section per the templates below.
3. Move any unresolved branches into `## Open Questions` with a one-line description each.
4. Print a final summary: file path, mode, counts (decisions, slices/steps, open questions).

The skill exits after the final summary.

---

## Output templates

### Software mode — `## Slices`

Strict one-cycle TDD per slice. If a slice would need more than one Red→Green→Refactor cycle, split it into multiple slices.

```markdown
## Slices

### Slice 1 — <one-sentence user-facing outcome>
**Outcome:** What the user can do once this slice ships.
**Test (Red):** <test name + behaviour under test, described not coded>. File: `path/to/test.ext`.
**Implementation (Green):** Minimum production code to pass. Files: `path/to/file.ext`.
**Refactor:** <explicit refactor opportunity, or "none expected">.
**Acceptance:** <binary criterion — true/false after slice ships>.

### Slice 2 — ...
```

### General mode — `## Steps`

Ordered numbered steps. Each step names exact files to touch and binary acceptance.

```markdown
## Steps

### 1. <Step title>
<What to do, in 1-3 sentences.>
- Files: `path/to/file` (CREATE | UPDATE | DELETE).
- Acceptance: <binary criterion>.

### 2. <Step title>
...
```

---

## File schema

The full task file structure produced by this skill:

```markdown
# <slug>

<Optional 1-2 sentence preamble about the change.>

## Requirements
<owned by issue-liaison — DO NOT modify if present>

## Context
_Codebase facts and constraints learned during grilling._
- ...

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **<short title>** — <decision and reasoning>.
2. ...

## Slices  ← OR ## Steps depending on Mode
...

## Open Questions
- <unresolved branch + recommendation for follow-up>
```

---

## Allowed actions

- Run the `Agent` tool with `subagent_type: "Explore"` and `model: "sonnet"` for any codebase exploration.
- Create the `tasks/` directory if it does not exist.
- Read and write `tasks/<confirmed-slug>.md`.
- Read existing `tasks/*.md` files to derive context if the user references prior work by slug.

## Forbidden actions

- NEVER read, grep, or otherwise inspect the codebase inline during grilling. Always delegate to `Explore`.
- NEVER pass `model: "opus"` or `model: "haiku"` to the `Explore` subagent — Sonnet only (Decision 21).
- NEVER write to `## Requirements` — it is owned by `agents/issue-liaison.md`.
- NEVER overwrite the task file without explicit user "restart" confirmation in Step E2.
- NEVER write to a file path whose slug the user has not confirmed in Step E1.
- NEVER batch multiple grilling questions into a single turn.
- NEVER skip the software-vs-general discriminator (Step E4) — the output template depends on it.

## Stop and ask before

- The topic is ambiguous and a meaningful slug cannot be derived even after one clarification.
- An `Explore` subagent returns a contradiction with a prior `## Decisions` entry — surface the contradiction and ask the user which is authoritative.
- The user provides a slug that would overwrite an unrelated existing task file (different topic).
- The user invokes `restart` on a file that contains `## Requirements` — confirm that requirements are preserved and only other sections are wiped.
