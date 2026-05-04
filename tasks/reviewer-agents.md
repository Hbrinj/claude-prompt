# reviewer-agents

Add a coherent set of reviewer agents covering software code, skill/agent prompt definitions, and general (non-software) artifacts. Decide how the new agents relate to the existing `code-reviewer` and `security-reviewer`, and how each fits into the workflow.

## Context
_Codebase facts and constraints learned during grilling._
- `agents/code-reviewer.md` already exists. Diff-scoped (`git diff HEAD` / `--staged`), output is `[SEVERITY] file:line` blocks ordered Critical → Major → Minor → Suggestion, ends with summary table + binary `APPROVE / REQUEST CHANGES` verdict.
- `code-reviewer` is invoked in two places today: every developer agent's `## Self-review before return` loop (up to 3 cycles), and `skills/parallel-dispatch.md` combined-diff pass.
- `agents/security-reviewer.md` exists — full-repo scanner, persistent `SECURITY-ISSUES.md` log, severity CRITICAL→HIGH→MEDIUM→LOW, on-demand only (not wired into Step 2).
- `agents/architecture.md` has a "Mode 2 — Change Review" that emits `ARCHITECTURE COMPATIBLE / ARCHITECTURE IMPACTED`.
- All agents follow a common skeleton: YAML frontmatter, role, Starting/Target state, NEVER list, domain rules, Allowed actions, Steps, Stop-and-ask. Reviewer agents omit `## Role` header and skip `## Self-review` (they ARE the reviewers).
- `agents/README.md` is a one-line-per-agent catalogue. `SYSTEM_PROMPT.md` is the workflow source of truth — it has a Skill index and Agent index.
- `skills/` contains: `grill-plan.md`, `parallel-dispatch.md`, `sync-upstream.md`, plus the multi-file `prompt-master/` sub-package. No skill currently reviews skill or agent definitions.

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **Existing code-reviewer stays untouched** — Add two new siblings (`prompt-definition-reviewer`, `general-reviewer`) alongside the existing `agents/code-reviewer.md`. No rename, no rewrite. The "software code reviewer" in the original ask = the existing agent. Reason: it's load-bearing (developer agents + parallel-dispatch), and renaming it for cosmetic consistency would touch every developer agent, SYSTEM_PROMPT.md, agents/README.md, and consumer repos — mechanical churn for no functional gain.
2. **prompt-definition-reviewer scope = both `skills/` and `agents/`** — Reviews any changed markdown prompt definition (skill OR agent file). Named `prompt-definition-reviewer` to signal scope honestly (not just skills). Distinct from `prompt-master` skill: this reviewer checks *structural and convention compliance* (skeleton sections, frontmatter, kebab-case filename, README catalogue updated, no inline codebase reads where `Explore` is required, etc.); `prompt-master` handles *prompt content quality* (positional doctrine, credit-killing patterns). The two are complementary and may both run on the same diff.
3. **general-reviewer scope = catch-all with file-type allowlist** — Reviews diffs to: `*.md` outside `agents/`/`skills/`, `*.json` / `*.yml` / `*.yaml` / `*.toml`, `tasks/*.md`, `features/*.md`. Explicitly excludes source code (defer to `code-reviewer`) and prompt definitions (defer to `prompt-definition-reviewer`). Heuristics: clarity, completeness, internal consistency, broken cross-doc references, contradictions with sibling docs. Reason: gives the agent a concrete remit so feedback is anchored, not generic.
4. **Input scope = diff-triggered, full-file context (option B)** — For both `prompt-definition-reviewer` and `general-reviewer`: use the diff to identify *which* files changed, then read each changed file in full plus its conventional siblings (e.g. new `agents/<x>.md` → also read `agents/README.md` and `SYSTEM_PROMPT.md` Agent index to verify catalogue/index entries). Findings may reference any line in the changed file or its siblings. Reason: prompt definitions and docs are coherent wholes — diff-only would routinely miss "you forgot to update the catalogue" and intra-file contradictions.
5. **Invocation = coordinator auto-invokes by file-type (option B of Q5)** — Step 2 push gate gains a routing sub-step (see Decision 8). Both new reviewers are auto-triggered when the diff matches their file-type rule; otherwise they're no-ops for the run. Reason: if reviewers aren't auto-invoked the user has to remember them, which won't happen consistently — defeats the point of building them.
6. **Output format = mirror code-reviewer shape, tune severity anchors per domain (option B of Q6)** — Same headers, same `[SEVERITY] file:line` block layout, same Critical/Major/Minor/Suggestion ladder, same final binary `APPROVE / REQUEST CHANGES` verdict line. Each reviewer documents its own anchors for what counts as Critical vs Major in its domain (e.g. for `prompt-definition-reviewer`: Critical = missing required frontmatter, broken catalogue entry, internal contradictions in NEVER list; for `general-reviewer`: Critical = broken cross-doc reference that breaks workflow, contradictions with SYSTEM_PROMPT.md). Reason: uniform shape keeps the coordinator gate simple; tuned anchors prevent "everything in docs is Suggestion-only" calibration drift.
7. **Self-review loop = mirror developer-agent loop (option A of Q7)** — Coordinator runs reviewer; applies CRITICAL+MAJOR; re-runs; up to 3 cycles or until APPROVE. MINOR/SUGGESTION surfaced once at the end. Same semantics across all three reviewers (code, prompt-definition, general). Reason: consistency with existing pattern; the 3-cycle cap is the existing safety rail.
8. **Step 2 routing = single generalised gate (option C of Q8)** — In SYSTEM_PROMPT.md Step 2, after the developer-agent self-review (if it ran), the coordinator inspects the diff and ensures, for each touched file-type bucket (code / prompt-definition / general), that the corresponding reviewer has APPROVED. Any missing reviewer is run now in its own self-review loop. Non-negotiable rule generalises to: *"NEVER push without all relevant reviewers having APPROVED."* Pure-code PRs are already covered by the developer-agent dev loop; pure-prompt and pure-doc PRs gain coverage; mixed PRs run both. Reason: single rule covers all permutations; smallest spec change vs (B); sharper than (A).
9. **`~/.claude/CLAUDE.md` propagation = reminder only (option B of Q9)** — The plan's final Step includes a one-line reminder that the user must manually copy SYSTEM_PROMPT.md to `~/.claude/CLAUDE.md` to activate the workflow change in their active session. Not performed by the plan. Reason: matches existing repo convention; user controls timing of global-config refresh.

## Steps

### 1. Create `agents/prompt-definition-reviewer.md`
Author the new reviewer agent. Skeleton: YAML frontmatter (`name`, `description`), opening role prose (omit `## Role` header per existing reviewer convention), `## Starting state`, `## Target state`, `## NEVER do these`, `## Scope` (changed files in `agents/` or `skills/`; diff-triggered, full-file context including conventional siblings — `agents/README.md` for new agents, `skills/README.md` for new skills, `SYSTEM_PROMPT.md` Agent/Skill index for any agent or skill add/rename), `## Severity anchors` (Critical = missing required frontmatter, broken catalogue/index entry, internal contradiction in NEVER list or workflow steps, kebab-case violation in filename; Major = skeleton sections missing/out-of-order, inline codebase reads where `Explore` is required by other agents/skills, drift between frontmatter `description` and body; Minor = inconsistent header levels, duplicated guidance; Suggestion = wording/phrasing), `## Output format` (mirror `code-reviewer`: `[SEVERITY] file:line` blocks ordered Critical → Major → Minor → Suggestion, summary table, binary `APPROVE / REQUEST CHANGES` verdict on the final line), `## Allowed actions` (Read on changed files and conventional siblings; never Edit/Write/Bash-mutation), `## Steps`, `## Stop and ask before`.
- Files: `agents/prompt-definition-reviewer.md` (CREATE).
- Acceptance: file exists, opens with valid frontmatter, includes all listed sections, ends with explicit `APPROVE / REQUEST CHANGES` verdict-line spec.

### 2. Create `agents/general-reviewer.md`
Author the new reviewer agent with the same skeleton as Step 1. Scope: diffs to `*.md` outside `agents/`/`skills/`, `*.json` / `*.yml` / `*.yaml` / `*.toml`, `tasks/*.md`, `features/*.md`. Excludes source code (defer to `code-reviewer`) and prompt definitions (defer to `prompt-definition-reviewer`). Severity anchors: Critical = broken cross-doc reference that breaks workflow, contradiction with `SYSTEM_PROMPT.md` or project `CLAUDE.md`, malformed JSON/YAML/TOML; Major = unclear or incomplete acceptance criteria in plan/feature-log files, missing required columns in feature log, stale references to renamed/removed files; Minor = inconsistent formatting, missing trailing newline; Suggestion = wording/phrasing. Output format mirrors `code-reviewer` (block layout, severity ordering, summary table, binary `APPROVE / REQUEST CHANGES` verdict).
- Files: `agents/general-reviewer.md` (CREATE).
- Acceptance: file exists, opens with valid frontmatter, includes all listed sections, file-type allowlist matches Decision 3 verbatim, ends with explicit `APPROVE / REQUEST CHANGES` verdict-line spec.

### 3. Update `agents/README.md`
Append one-line catalogue entries for both new agents, alphabetically sorted into the existing list per repo convention.
- Files: `agents/README.md` (UPDATE).
- Acceptance: both `prompt-definition-reviewer` and `general-reviewer` appear as one-liner entries in the README; existing entries are preserved verbatim.

### 4. Update `SYSTEM_PROMPT.md`
Three coordinated edits to the workflow source of truth:
1. **Non-negotiable rules** — generalise the existing rule *"NEVER push code without first ensuring `code-reviewer` has run"* to: *"NEVER push without all relevant reviewers having APPROVED. The relevant reviewers are determined by the file-type buckets touched in the diff: code → `code-reviewer` (via developer-agent self-review or `parallel-dispatch` combined-diff pass); prompt definitions in `agents/`/`skills/` → `prompt-definition-reviewer`; general allowlist (docs, configs, plan and feature-log files) → `general-reviewer`."*
2. **Step 2 routing sub-step** — between the existing developer-agent self-review sub-step and the feature-log sub-step, insert a coordinator-level routing sub-step: *"Inspect the diff. For each touched file-type bucket (code / prompt-definition / general), ensure the corresponding reviewer has APPROVED. Run any missing reviewer now in its own self-review loop (≤3 cycles, apply CRITICAL+MAJOR each round, surface MINOR/SUGGESTION once at the end)."*
3. **Agent index** — add rows for `prompt-definition-reviewer` and `general-reviewer` with `Called in` = "Step 2 — invoked by the coordinator's file-type routing gate."
- Files: `SYSTEM_PROMPT.md` (UPDATE).
- Acceptance: all three edits land; the non-negotiable rule reads as the new generalised version verbatim; the Step 2 routing sub-step appears in the right position; Agent index has both new rows.

### 5. Verify no other files need edits
Confirm `skills/sync-upstream.md`, project `CLAUDE.md`, and `agents/code-reviewer.md` need NO changes. Sync-upstream auto-copies all `agents/`/`skills/` files recursively (already verified); project `CLAUDE.md` is repo conventions only and has no Agent index; the existing `code-reviewer` is unchanged per Decision 1.
- Files: none modified.
- Acceptance: a final pre-commit `git status` shows changes only in `agents/prompt-definition-reviewer.md`, `agents/general-reviewer.md`, `agents/README.md`, `SYSTEM_PROMPT.md`, `tasks/reviewer-agents.md`, `TODO.md`, and `features/all_features.md`.

### 6. Reminder — manual `~/.claude/CLAUDE.md` copy
Print a one-line reminder to the user (do NOT perform the copy as part of this feature): *"Reminder: copy `SYSTEM_PROMPT.md` into `~/.claude/CLAUDE.md` manually to activate the workflow change in your active session — `sync-upstream` does not touch global config."*
- Files: none.
- Acceptance: reminder is printed in the final hand-off / Step 2 review-gate summary.

## Deferred (out of scope)
_Items resolved as "not this feature" during grilling. Consolidated to `/TODO.md` at termination._

| Item | Why deferred | Related decision |
|------|--------------|------------------|
| test-quality reviewer agent | Strong follow-on candidate; reviews test code (coverage gaps, brittle assertions, mocking abuse). Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape |
| dependency reviewer agent | Strong follow-on candidate; reviews new package adds (license, maintenance, supply-chain). Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape |
| PR / commit-message reviewer agent | Strong follow-on candidate; reviews PR description and commit-message hygiene. Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape |
| Wire `security-reviewer` into the Step 2 gate | Different review strategy (full-repo, persistent log); changing the gate's contract beyond what the trinity needs. Stays on-demand. | Q10 (i) |
| Extract a shared `agents/_reviewer-skeleton.md` template | Premature abstraction at 3 reviewers; existing reviewer agents converge on a skeleton organically. Revisit once the deferred trio above lands and the count is closer to 5. | Q10 (ii) |

## Open Questions
_None — all decisions resolved during grilling._
