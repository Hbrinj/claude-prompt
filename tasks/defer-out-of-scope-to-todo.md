# defer-out-of-scope-to-todo

Ensure that when work is deferred as "out of scope" during a feature, it is captured automatically — first in the per-feature plan, then consolidated into a central TODO at the end of planning.

## Context
_Codebase facts and constraints learned during grilling._
- This repo is the agent and skills library. Behavioural rules live in `agents/*.md`, `skills/*.md`, and `~/.claude/CLAUDE.md` (workflow) / `CLAUDE.md` (repo conventions).
- Existing per-feature artefacts: `tasks/<slug>.md` (plan, owned by `grill-plan`), `features/<feature>.checkpoint.md` (pause/resume state), `features/all_features.md` (status ledger).
- `grill-plan` already writes `## Open Questions` to `tasks/<slug>.md` at termination — the natural sibling for a `## Deferred (out of scope)` section.
- A `/TODO.md` already exists at repo root with one free-form deferred item from `add-go-developer` (lint-vs-test wording fix in `agents/go-developer.md:61`). Migrated to the new schema during implementation (Step 7).
- Audit result (Step 8): no external agent/skill makes a schema-completeness claim that the new `## Deferred` section would contradict. Developer agents read `## Slices` only; `issue-liaison` only writes `## Requirements`. The only inconsistency was within `grill-plan.md` itself (the "Target state" paragraph at line 13) — fixed during implementation.

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **Two-stage capture** — During work, deferred-as-out-of-scope items are appended to a `## Deferred (out of scope)` section in `tasks/<slug>.md`. At the end of planning, those items are consolidated into a central `TODO.md`. Reasoning: per-feature capture preserves context at the moment of deferral; central consolidation gives one place to triage across features.
2. **Capture scope: Step 1 (grill-plan) only** — The deferral-capture rule applies during grill-plan, not during Step 2 (implementation). Reasoning: "out of scope" is a planning concept — the output of grilling. Implementation should execute the agreed plan; in-flight discoveries should pause to update the plan, not silently grow a TODO. Keeps the rule in one skill instead of duplicated across five developer agents.
3. **Capture trigger: any "not this feature" resolution** — A `## Deferred` entry is written whenever (a) the user explicitly defers ("defer", "out of scope", "save for later", "not now"), or (b) a grilling branch gets abandoned because the user chose a path that prunes it AND the user wants the pruned branch kept for later. The grill-plan rule *"If the user picks an option that invalidates a downstream branch, abandon that branch"* is modified to ask: drop entirely, keep as Open Question, or defer. Reasoning: keeps the three sections semantically distinct — Decisions (resolved, in scope) / Open Questions (unresolved) / Deferred (resolved as "not now").
4. **`TODO.md` schema** — Flat markdown file at repo root, grouped by source feature, five-column table per group: `Item | Why deferred | Related decision | Added | Status (Open / Picked up / Dropped)`. Reasoning: grouping by feature preserves provenance; five columns is the minimum to triage without reopening the source plan; consistent with `features/all_features.md` table style; Status column preserves history without deletion.
5. **Source of truth post-consolidation: source plan keeps the entry** — Items in `## Deferred` are NOT removed when consolidated into `TODO.md`. The flow is one-way and additive. Idempotency: re-running consolidation only appends rows not already in `TODO.md`, matched by `(source slug, item text)`. Existing rows (and their hand-edited `Status`) are never overwritten. Reasoning: the source plan is the historical record of grilling outcomes; wiping it post-consolidation would make the plan lie about its own past.
6. **Consolidation mechanism: inline in `grill-plan` Termination** — A new sub-step `4a` runs between writing `## Open Questions` and printing the final summary: if `## Deferred` has entries, read `TODO.md` (create if missing), append rows for any `(slug, item text)` not already present under the feature's heading, preserve existing rows verbatim. Final summary reports `Deferred consolidated: N (M new)`. Reasoning: the skill is already in the right context; no new skill, hook, or agent needed. Hooks can't do markdown-section matching; this is model-judgment work.
7. **`## Deferred` capture format: three-column table** — `Item | Why deferred | Related decision`. No `Added` or `Status` columns at capture time. Consolidation stamps `Added` = today and `Status` = `Open` on the `TODO.md` row. Reasoning: minimise grilling friction — only substantive fields written by hand; bookkeeping fields filled deterministically.
8. **`TODO.md` location: repo root** — `/TODO.md`. Reasoning: discoverable triage list; mirrors `README.md` / `CLAUDE.md` root convention; distinct from `tasks/` (per-feature plans) and `features/` (status ledger).
9. **Visibility: extend status postscript and resume summary with `Deferred: N`** — Status postscript becomes `Status — Mode: <m> · Decisions: N · Slices: N (M complete) · Open Q: N · Deferred: N · Requirements: N/M · File: tasks/<slug>.md`. Resume summary becomes `Found existing plan — Decisions: N · Slices/Steps: N · Open Questions: N · Deferred: N · Requirements: present|absent · Last updated: <date>`. Reasoning: user must know deferral count is non-zero so they can review before terminating; prevents silent accumulation.
10. **Migration: forward-only, no backfill** — The skill change applies to grilling sessions from this point on. Existing `tasks/*.md` files are not retroactively edited. `TODO.md` starts empty. Reasoning: backfill would require fragile model judgment over historical plans; cost of inconsistency is near-zero since old plans are archives.

## Steps

### 1. Extend `skills/grill-plan.md` schema with `## Deferred (out of scope)`
Add `## Deferred (out of scope)` to the *File schema* block as a sibling to `## Open Questions`. Show its three-column table shape inline (Decision 7): `| Item | Why deferred | Related decision |`. Add a one-line description: *"Items resolved as 'not this feature' during grilling. Consolidated to `/TODO.md` at termination."*
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: the *File schema* section lists `## Deferred (out of scope)` between `## Slices`/`## Steps` and `## Open Questions`, with an example three-column table and the one-line description.

### 2. Modify the branch-abandonment rule in *Grilling rules*
The existing rule *"If the user picks an option that invalidates a downstream branch, abandon that branch"* (in Step E5 / Grilling rules) becomes: *"If the user picks an option that invalidates a downstream branch, ask whether to (a) drop entirely, (b) keep as an Open Question, or (c) defer to `## Deferred`."* Add an adjacent rule: *"If the user uses explicit deferral phrasing — 'defer', 'out of scope', 'save for later', 'not now' — append to `## Deferred` directly."* (Decision 3.)
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: both rules are present in the Grilling rules section; the original abandonment rule no longer appears verbatim.

### 3. Update the status postscript template
In the *Status postscript* sub-section, replace the existing template line with: `Status — Mode: <software|general> · Decisions: N · Slices: N (M complete) · Open Q: N · Deferred: N · Requirements: N/M · File: tasks/<slug>.md`. The omit-`Requirements`-when-absent rule still applies; the `Deferred: N` field is always present (zero when empty). (Decision 9.)
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: the postscript template line includes `Deferred: N`; the surrounding rules text is unchanged otherwise.

### 4. Update the Step E2 resume summary template
In Step E2, replace the existing one-line summary template with: `Found existing plan — Decisions: N · Slices/Steps: N · Open Questions: N · Deferred: N · Requirements: present|absent · Last updated: <date>`. (Decision 9.)
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: the Step E2 summary template includes `Deferred: N`; restart/resume branching logic is unchanged.

### 5. Add Termination sub-step 4a for consolidation into `/TODO.md`
Insert a new sub-step `4a` in the *Termination* section, between current step 3 (move unresolved branches into `## Open Questions`) and the final summary step: *"If `## Deferred` has entries, read `/TODO.md` (create if missing), and for every row not already present under the feature's heading (matched by `(slug, item text)`) append a row with columns `Item | Why deferred | Related decision | Added (today's date) | Status (Open)`. Existing rows in `/TODO.md` — including hand-edited `Status` values — are preserved verbatim. The `## Deferred` section in the source plan is NOT modified or removed."* Update the final summary step to include `Deferred consolidated: N (M new)`. (Decisions 5, 6.)
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: sub-step 4a exists with the verbatim behaviour above; the final summary step lists `Deferred consolidated: N (M new)`; the source-plan-preservation rule is explicit.

### 6. Add `/TODO.md` to *Allowed actions*
The *Allowed actions* list explicitly enumerates files the skill may touch. Add: *"Read and write `/TODO.md` (create if missing) — only during Termination sub-step 4a."* (Decision 6/8.)
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: the *Allowed actions* list includes the `/TODO.md` line; the *Forbidden actions* list does not contradict it.

### 7. Create `/TODO.md` at repo root with header and empty state
Create the file with a top-of-file header explaining its purpose and one empty placeholder. No feature groups yet (forward-only — Decision 10).
- Files: `TODO.md` (CREATE).
- Acceptance: `/TODO.md` exists at repo root; contains `# TODO`, the one-line description (*"Items deferred as out-of-scope from feature planning. Triage manually."*), and an empty-state line (*"_No deferred items yet._"*).

### 8. Audit other skills and agents for schema references
Scan `skills/*.md` and `agents/*.md` for any reference to the `tasks/<slug>.md` schema (Decisions / Slices / Steps / Open Questions / Requirements). Confirm none of them assert the schema is exhaustive in a way that contradicts the new `## Deferred` section. If any do, file a follow-up note here — do NOT silently edit unrelated files.
- Files: read-only audit; no edits unless contradiction is found.
- Acceptance: either (a) no contradictions found and a one-line note is added to `## Context`, or (b) contradictions listed in `## Open Questions` for the user to triage.

## Open Questions
_None at finalisation. Sub-step 8 may surface follow-ups during execution._

