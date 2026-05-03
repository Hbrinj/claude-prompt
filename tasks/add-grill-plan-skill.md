# add-grill-plan-skill

Convert the Research + Plan workflow steps (currently delegated to `agents/researcher.md` and `agents/planner.md`) into a single grill-style skill (`skills/grill-plan.md`) that produces a TDD/vertical-slice plan for software work and an ordered-steps plan for non-software work. Update both system prompts to a 2-step workflow.

This plan was produced by manual grilling using the schema designed during the grilling session (it dogfoods what `grill-plan` will produce). This change's deliverables are markdown files, not executable code, so per the runtime-branching rule (Decision 5) the output uses `## Steps`, not `## Slices`.

---

## Context

_Codebase facts learned during grilling._

- Skills in this repo live in `skills/` and become global slash commands via the `~/.claude/commands/` symlink that `sync-upstream` maintains.
- Two skill formats exist: single-file (`skills/sync-upstream.md`) and directory-style (`skills/prompt-master/`). Anthropic recommends keeping `SKILL.md` under 500 lines; no hard technical limit.
- `agents/researcher.md` and `agents/planner.md` define the current 2-agent flow that writes `## Research` and `## Plan` sections to `tasks/<slug>.md`.
- `agents/issue-liaison.md` writes a `## Requirements` section to the same file when work originates from a GitHub issue. This section is orthogonal to research/plan.
- Developer agents (`android-developer`, `ios-developer`, `flutter-developer`, `kotlin-backend-developer`, `go-developer`) are passed the task file as a brief and don't reference any specific section names — so a schema rewrite doesn't require touching them.
- `agents/code-reviewer.md` doesn't reference the task file schema either.
- `SYSTEM_PROMPT.md` (interactive, with review gates) and `AUTONOMOUS_SYSTEM_PROMPT.md` (no gates, end-to-end) are both live source-of-truth for the workflow. Both reference `researcher` and `planner`.
- `~/.claude/CLAUDE.md` is the synced target — its content between `<!-- SYSTEM_PROMPT:START/END -->` markers is overwritten from `SYSTEM_PROMPT.md` by `sync-upstream`. Editing `~/.claude/CLAUDE.md` directly would be clobbered.
- `install.sh` lets the user pick between `SYSTEM_PROMPT.md` and `AUTONOMOUS_SYSTEM_PROMPT.md` at install time, so both files are live.
- The `Explore` subagent is purpose-built for codebase queries and is the right delegate for in-skill exploration.

---

## Decisions

_Resolved through grilling. Each entry references the question number from the session._

1. **Replace, not augment** — the skill supersedes researcher + planner; both agent files are deleted. (Q1)
2. **Context strategy** — three mitigations: subagent isolation for codebase exploration, incremental writes to the task file, resume protocol on re-invocation. No question budget, no `/compact` suggestions, no round-based summarisation. (Q2)
3. **Task file schema** — new shape: `## Context / ## Decisions / ## Slices` (software) or `## Steps` (non-software) `/ ## Open Questions`. Retires `## Research` and `## Plan`. (Q3)
4. **Slice template** — strict one-cycle TDD per slice. Fields: Outcome, Test (Red, described not coded), Implementation (Green, minimum code), Refactor, Acceptance. If a slice needs more than one cycle, split it. (Q4)
5. **Software vs non-software** — runtime branching: first grill question discriminates. Software → `## Slices` with TDD; non-software → `## Steps` with binary acceptance. (Q5)
6. **Skill name** — `grill-plan`. (Q6)
7. **Termination** — hybrid status. Skill prints a status postscript every 5 grilling rounds OR on user trigger words. User declares "write the plan" to stop. Unresolved items at write time go to `## Open Questions`. (Q7)
8. **Resume protocol** — on invocation, if `tasks/<slug>.md` exists, skill prints a one-liner summary and asks "resume from open items / restart fresh". Resume picks up by grilling `## Open Questions` first. (Q8)
9. **TDD enforcement location** — lives in `SYSTEM_PROMPT.md` Step 2 (synced into `~/.claude/CLAUDE.md` via `sync-upstream`): "if plan contains `## Slices`, developer agent must execute one slice per commit, in order, test-first." Developer agent definitions NOT updated in this change — tracked in `TODO.md`. (Q9)
10. **Skill format** — single file `skills/grill-plan.md`, target ≤ 250 lines, ceiling 500 (Anthropic guideline). (Q10)
11. **Subagent rule** — always delegate codebase exploration to `Explore`. Never read inline. Skill must instruct `Explore` to return synthesised 1-2 paragraph answers, not raw tool output. (Q11)
12. **Workflow restructure** — collapse to 2 steps: Step 1 Plan (invoke `/grill-plan`, review gate), Step 2 Implement (branch, code, review loop, push, PR, CI). Both system prompts get the rewrite; autonomous variant has no review gates. (Q12)
13. **Invocation arguments** — `/grill-plan <topic>` is optional. With args: derive slug, confirm slug with user before any file writes. Without args: first grill question is "what's the topic?". (Q13)
14. **Requirements coexistence** — if `## Requirements` is present at invocation, skill surfaces a one-screen summary at session start. Skill never writes or modifies that section. Status postscript includes `Requirements: N/M addressed`. (Q14)
15. **Status format** — one-line postscript appended after a grill question: `Status — Mode: software · Decisions: N · Slices: N (M complete) · Open Q: N · Requirements: N/M · File: tasks/<slug>.md`. Trigger: every 5 rounds OR on user words "status" / "where are we" / "summary". (Q15)
16. **Cleanup scope (verified)** — full inventory in Step 8 below. (Q16)
17. **Skill frontmatter** — imperative trigger-list style matching `sync-upstream`. Mentions output file path and both output modes. (Q17)
18. **Autonomous mode** — `AUTONOMOUS_SYSTEM_PROMPT.md` is **deleted** in this change. Rationale: `/grill-plan` is interactive by design and incompatible with non-interactive autonomous flow. Rather than corrupt the skill body with a dual-mode branch (option a) or reintroduce a separate `auto-planner` agent (option c — partially defeats Decision 1), drop autonomous mode entirely. Single autonomous-mode commit (`7cb1bfe`) is the only history; low risk of established users depending on it. `install.sh` degrades gracefully — its system prompt picker (line 372) auto-skips when only one `*SYSTEM_PROMPT*.md` file is found. No install.sh change required. (OQ1)
19. **Slug derivation** — naive algorithm (lowercase, replace non-alphanumeric with `-`, collapse repeats, trim, cap at 50 chars) generates the proposal. User confirms or edits before any file write (per Decision 13). The algorithm is advisory; the human is authoritative. No stopword filtering, no LLM derivation. (OQ2)
20. **Standalone discoverability** — skill body does NOT include a pointer back to `SYSTEM_PROMPT.md` or the broader workflow. The skill's contract is producing `tasks/<slug>.md`; downstream usage is decoupled. Frontmatter `Description` field (Decision 17) already names the output file as the integration contract. (OQ3)
21. **Subagent model = Sonnet** — when the skill delegates codebase exploration to the `Explore` subagent (per Decision 11), it MUST pass `model: "sonnet"` (model ID `claude-sonnet-4-6`) on the Agent tool call. Rationale: codebase exploration is read-heavy synthesis work — Sonnet is the right capability/cost point; Opus is overkill, Haiku is under-powered for non-trivial codebase reasoning. Skill body must spell this out so it's not left to default behaviour.

---

## Steps

### 1. Branch
Create `feature/add-grill-plan-skill` from `main`. The current branch (`main`) is already up to date.
- Acceptance: `git branch --show-current` returns `feature/add-grill-plan-skill`.

### 2. Write `skills/grill-plan.md`
Single file, target ≤ 250 lines. Sections in this order:

1. **Frontmatter** (per Decision 17):
   ```
   ---
   Name: grill-plan
   Version: 1.0.0
   Description: Use when the user wants to plan a feature, design a change, break work into vertical slices, or says "plan this" / "design this" / "let's break this down" / "grill me on a plan". Outputs to `tasks/<slug>.md`. Strict TDD shape for software work (vertical slices with one Red/Green/Refactor cycle each); plain ordered steps for non-software work.
   ---
   ```
2. **Starting state / Target state** (matches existing skill conventions).
3. **Entry behaviour**:
   - Accept optional topic as args. If no args, first question: "What's the topic?" (Decision 13)
   - Derive kebab-case slug via naive algorithm (Decision 19): lowercase the topic, replace any non-alphanumeric run with `-`, collapse repeated `-`, trim leading/trailing `-`, cap at 50 chars. Present the proposal to the user for confirmation or edit; use the confirmed value for the file write.
   - Check if `tasks/<slug>.md` exists. If yes, print one-liner summary and prompt resume/restart (Decision 8).
   - If `## Requirements` present, surface one-screen summary at session start (Decision 14).
   - First substantive grill question is the software discriminator (Decision 5): "Is this software work that produces executable behaviour, or something else (docs, RFC, infra config, vendor selection)?"
4. **Grilling rules**:
   - One question at a time.
   - **Always** delegate codebase exploration to the `Explore` subagent — never read or grep inline. Pass `model: "sonnet"` on every Agent tool call (Decision 21). Instruct Explore to return a synthesised 1-2 paragraph answer, not raw tool output. (Decisions 11, 21)
   - Write resolved decisions and discovered context to `tasks/<slug>.md` immediately as they're resolved — file is the source of truth, conversation is scratch. (Decision 2)
5. **Status postscript spec** (Decision 15):
   - Format: `Status — Mode: software|general · Decisions: N · Slices: N (M complete) · Open Q: N · Requirements: N/M · File: tasks/<slug>.md`
   - Trigger: every 5 grilling rounds OR on user words "status" / "where are we" / "summary".
   - Append as a postscript line after the next grill question — does not consume a turn.
6. **Termination** (Decision 7): when user declares "write the plan" or equivalent, finalise the file. Any unresolved items become `## Open Questions` entries.
7. **Two output templates**:
   - **Software (`## Slices`)** — strict one-cycle TDD per slice. Each slice has Outcome, Test (Red, described not coded), Implementation (Green, minimum code), Refactor, Acceptance. (Decision 4)
   - **Non-software (`## Steps`)** — ordered numbered steps, each with file scope and binary acceptance criteria.
8. **File schema** (Decision 3): `## Context / ## Decisions / ## Slices` (or `## Steps`) `/ ## Open Questions`. Skill MUST NOT write to or modify `## Requirements` if present.
9. **Allowed actions / Forbidden actions / Stop and ask** sections.

- Files: `skills/grill-plan.md` (CREATE).
- Acceptance: file exists, frontmatter is valid YAML, body covers all nine sections above, line count ≤ 250.

### 3. Update `skills/README.md`
Add a row for `grill-plan` linking to the new file with a one-line description matching the frontmatter intent.
- Files: `skills/README.md` (UPDATE).
- Acceptance: README catalogue table contains a `grill-plan` row.

### 4. Rewrite `SYSTEM_PROMPT.md` to the 2-step workflow
Specific edits:
- Workflow heading: `## Workflow — 3 steps in order` → `## Workflow — 2 steps in order`.
- Checkpoint template: list 2 steps (Plan, Implement) instead of 3.
- Delete the entire `### Step 1 — Research` section.
- Replace `### Step 2 — Plan` body with `### Step 1 — Plan`: invoke the `/grill-plan` skill (`skills/grill-plan.md`); skill writes to `tasks/<slug>.md`. Keep the review gate prompt updated to reference grilling.
- Renumber `### Step 3 — Implement` → `### Step 2 — Implement`. Inside it, add this line under "Code": *"If the plan contains `## Slices`, the developer agent MUST execute one slice per commit, in order, writing the failing test before the implementation, then the minimum code to pass, then the refactor."*
- Architecture-impact branch: keep, but reword from "If the planner flags architectural impact" → "If grilling surfaces architectural impact".
- Agent index table: remove `researcher` and `planner` rows.
- Add a small "Skill index" line above or below the Agent index referencing `grill-plan` (`skills/grill-plan.md`).

- Files: `SYSTEM_PROMPT.md` (UPDATE).
- Acceptance: `grep -E "researcher|planner" SYSTEM_PROMPT.md` returns no matches; workflow has exactly 2 numbered steps; TDD/slice enforcement line is present in Step 2.

### 5. Delete `AUTONOMOUS_SYSTEM_PROMPT.md`
Per Decision 18 — autonomous mode is incompatible with grill-plan's interactive design. Drop the autonomous prompt entirely rather than corrupt grill-plan with dual-mode logic or reintroduce a separate auto-planner agent. `install.sh` auto-skips its system prompt picker when only one `*SYSTEM_PROMPT*.md` file remains (line 372), so no install.sh change is needed.
- Files: `AUTONOMOUS_SYSTEM_PROMPT.md` (DELETE).
- Acceptance: file no longer exists; `install.sh` still discovers `SYSTEM_PROMPT.md` and skips the picker (manual smoke test).

### 6. Delete `agents/researcher.md` and `agents/planner.md`
- Files: `agents/researcher.md` (DELETE), `agents/planner.md` (DELETE).
- Acceptance: `git status` shows both files deleted.

### 7. Update `agents/README.md`
Drop the `researcher` and `planner` rows from the agent catalogue table.
- Files: `agents/README.md` (UPDATE).
- Acceptance: README table contains no rows for `researcher` or `planner`.

### 8. Verify cleanup — grep for orphan references
Run: `grep -rnE "researcher|planner" agents/ skills/ SYSTEM_PROMPT.md`.
Expected: zero matches. `AUTONOMOUS_SYSTEM_PROMPT.md` is deleted in Step 5 so it's not in the grep set. Historical `tasks/*.md` files are intentionally left untouched (per Decision 16) and not part of the grep set.
- Acceptance: command returns no matches.

### 9. Final review and PR
Per `~/.claude/CLAUDE.md` workflow:
- Run `code-reviewer` agent up to 3 times; fix CRITICAL and MAJOR findings each round.
- Append a row to `features/all_features.md` (create file if missing) with status `In Review`. Commit on the feature branch.
- Push branch.
- Open PR with this `tasks/add-grill-plan-skill.md` as the body.
- Monitor CI to green.

- Acceptance: PR is open with passing CI; `features/all_features.md` has the new row.

---

## Open Questions

_None remaining. All three open questions from the initial draft were resolved in a follow-up grilling round and folded into Decisions 18, 19, 20 above._
