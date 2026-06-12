# Integrate Matt Pocock engineering skills + rewire coordinator workflow

## Context
- Source: `mattpocock/skills` → `skills/engineering/` (10 skills). Upstream license is **MIT** — vendoring is permitted with attribution + license preservation.
- The 10 skills: `setup-matt-pocock-skills`, `grill-with-docs`, `to-prd`, `to-issues`, `tdd`, `diagnose`, `improve-codebase-architecture`, `triage`, `prototype`, `zoom-out`. Several ship sibling reference files (e.g. `tdd/tests.md`, `grill-with-docs/CONTEXT-FORMAT.md`) and `diagnose/scripts/`; total ≈31 files.
- They use their **own internal structure** (`# Title` + prose, `<what-to-do>`/`<supporting-info>` tags, relative sibling links, cross-skill links like `../grill-with-docs/CONTEXT-FORMAT.md`). They do **not** follow this repo's prompt-definition-reviewer skeleton. Frontmatter keys are already lowercase `name:`/`description:` (Claude Code-parseable); two carry `disable-model-invocation: true` (`setup-matt-pocock-skills`, `zoom-out`).
- **Contract collision (the crux):** the current workflow is `grill-plan → tasks/<slug>.md (## Slices/## Steps) → implement-feature consumes it`. The Pocock pipeline replaces that file-based contract with an **issue-tracker contract**: `grill-with-docs (understand, update CONTEXT.md/ADRs) → to-prd (publish PRD) → to-issues (vertical-slice tracer-bullet issues) → tdd (implement per issue)`. There is no `tasks/<slug>.md`.
- Decisions captured interactively (AskUserQuestion, 2026-06-12), all four at the most invasive setting.

## Decisions
1. **Full replace + rewire** — retire `grill-plan` and redesign Steps 1–2 around the Pocock pipeline (CONTEXT.md/ADRs + issue tracker + TDD). See `## New workflow design`.
2. **Add all 10; skills win over agents** — where a skill overlaps an existing agent, the skill is authoritative and the agent is cleaned up:
   - `tdd` is the TDD authority → strip generic TDD/slice prose from the 7 developer agents; they keep only stack-specific idioms and defer to `/tdd`.
   - `to-prd` + `to-issues` + `triage` own issue creation/breakdown/triage → narrow `issue-liaison` to PR/issue *status comms* only.
   - `improve-codebase-architecture` owns architecture work → retire the `architecture` agent.
3. **Vendor verbatim, flat** — copy each skill unchanged into `skills/<name>/` (preserving sibling + cross-skill relative links), add MIT attribution, and scope the vendored paths **out** of `prompt-definition-reviewer`.
4. **Ship skills only** — no `CONTEXT.md`/`docs/adr/`/tracker scaffolding created in this library repo. `/setup-matt-pocock-skills` is run per real project (store, resume, …).

## New workflow design (the centerpiece — approve this first)
**Per-repo bootstrap (once):** `/setup-matt-pocock-skills` — record issue tracker (GitHub), triage-label vocabulary, domain-doc layout into `docs/agents/*.md` + an `## Agent skills` block.

**Step 1 — Understand → Specify → Slice** (replaces grill-plan):
- `/grill-with-docs` — relentless one-question-at-a-time grilling against the domain model; updates `CONTEXT.md` glossary + offers ADRs inline.
- `/to-prd` — synthesize context into a PRD, publish to the tracker (optional for small work).
- `/to-issues` — break into vertical-slice tracer-bullet issues (HITL/AFK, dependency-ordered).
- **Review gate:** present the issue breakdown; user approves. **New artifact contract = issues on the tracker** (not `tasks/<slug>.md`). Checkpoints reference issue IDs.

**Step 2 — Implement (per issue):**
- Branch per issue → `/tdd` red-green-refactor vertical slices; stack developer agents supply language/framework idioms only.
- Reviewer routing gate (code-reviewer + file-type buckets) unchanged → feature log → push → review gate → PR (links the issue) → CI.

**Supporting skills:** `/diagnose` (bugs/perf), `/improve-codebase-architecture` (deepening refactors), `/triage` (incoming issues), `/prototype` (throwaway design exploration), `/zoom-out` (orientation, manual-only).

## Steps
1. **Vendor the 10 skills verbatim** into `skills/<name>/` (all sibling files + `diagnose/scripts/`), add `skills/NOTICE.md` with upstream URL + MIT license text + commit SHA pinned.
   - Files: `skills/{setup-matt-pocock-skills,grill-with-docs,to-prd,to-issues,tdd,diagnose,improve-codebase-architecture,triage,prototype,zoom-out}/**` (NEW), `skills/NOTICE.md` (NEW)
   - Acceptance: every upstream file present byte-for-byte; all relative + cross-skill links resolve within `skills/`; NOTICE names source repo, SHA, MIT.
2. **Catalogue** — add 10 rows to `skills/README.md`; mark vendored/third-party.
   - Files: `skills/README.md` (UPDATE) — Acceptance: one row per new skill, flagged third-party.
3. **Scope vendored skills out of prompt-definition-reviewer** — add a vendored-paths carve-out (explicit list of the 10 dirs) to `agents/prompt-definition-reviewer.md` and to the routing-gate text in `skills/implement-feature.md`.
   - Files: `agents/prompt-definition-reviewer.md`, `skills/implement-feature.md` (UPDATE) — Acceptance: reviewer instructed to skip the 10 vendored dirs; repo-native skills still reviewed.
4. **Rewrite Step 1/Step 2** in `SYSTEM_PROMPT.md` + `skills/implement-feature.md` to the new workflow (issue-tracker contract; `/grill-with-docs`→`/to-prd`→`/to-issues`→`/tdd`; supporting-skill routing).
   - Files: `SYSTEM_PROMPT.md`, `skills/implement-feature.md` (UPDATE) — Acceptance: no reference to `grill-plan` or `tasks/<slug>.md` as the contract; checkpoints keyed to issues; skeleton still ≤ skeleton-size budget.
5. **Clean up developer agents** (×7) — replace embedded generic `## Slice-aware execution`/TDD prose with a deferral to `/tdd`; keep stack idioms + `## Self-review`.
   - Files: `agents/{android,ios,flutter,kotlin-backend,go,shell,react-typescript}-developer.md` (UPDATE) — Acceptance: each defers TDD discipline to `/tdd`; no duplicated red-green prose.
6. **Narrow `issue-liaison`; retire `architecture`** — issue-liaison → PR/issue status comms only; remove `architecture` agent + its references (Step 1 architectural-impact hook now routes to `/improve-codebase-architecture`).
   - Files: `agents/issue-liaison.md` (UPDATE), `agents/architecture.md` (DELETE), `agents/README.md` (UPDATE), `SYSTEM_PROMPT.md` (UPDATE) — Acceptance: no dangling `architecture` references; issue-liaison scoped to comms.
7. **Retire `grill-plan` + dispatch** — delete `grill-plan.md`, `parallel-dispatch.md`, `parallel-docker-dispatch.md`, `docker/`, and the dispatch scripts; scrub their rows from `skills/README.md` and references elsewhere (full file list in `## Resolved`). All README-row scrubbing for these happens here in PR-B, not PR-A.
   - Files: `skills/grill-plan.md` (DELETE), `skills/README.md`, `skills/parallel-dispatch.md`, `skills/parallel-docker-dispatch.md` (UPDATE) — Acceptance: no dangling `grill-plan`/`tasks/<slug>.md` references; dispatch skills either reworked to issues or explicitly marked deferred.
8. **Propagate to live config** — after approval+push: refresh `~/.claude/CLAUDE.md` from the new `SYSTEM_PROMPT.md`; live clone already symlinks `skills/`, so vendored skills appear on `git pull`.
   - Files: `~/.claude/CLAUDE.md` (outside repo) — Acceptance: a new session shows the new workflow + all 10 skills with parsed descriptions.

## Deferred (out of scope)
- Running `/setup-matt-pocock-skills` inside store/resume/other real repos (done per-repo by the user later).
- Building any `CONTEXT.md`/`docs/adr/` content for claude-prompt itself.

## Resolved (2026-06-12)
- **parallel-dispatch:** REMOVE entirely — not reworked. Delete both dispatch skills plus all related infrastructure: `docker/Dockerfile`, `docker/entrypoint.sh`, `scripts/dispatch-docker-worker.sh`, and the 8 dispatch test scripts (`test-dispatch-single.sh`, `test-dispatch-parallel.sh`, `test-dispatch-from-consumer.sh`, `test-entrypoint.sh`, `test-image.sh`, `test-routing-prose.sh`, `test-skill-indexed.sh`, `test-prose-absolute-path.sh`); scrub references in `README.md`, `SYSTEM_PROMPT.md`, `skills/README.md`, `skills/implement-feature.md`, `TODO.md`.
- **Issue-tracker as source of truth:** Agreed — plans/checkpoints move from in-repo `tasks/` to the GitHub tracker.
- **Delete vs narrow:** Confirmed — delete `architecture` agent and `grill-plan` skill (no legacy fallback).
- **Phasing:** TWO PRs. **PR-A (additive, low-risk) — this branch:** Steps 1–3 only — vendor 10 skills + catalogue + reviewer carve-out. The `grill-plan`/dispatch catalogue rows in `skills/README.md` are intentionally left intact in PR-A and removed in PR-B. **PR-B (invasive rewire, separate branch):** Steps 4–7 — rewrite Step 1/2, clean up developer agents, narrow issue-liaison, delete `architecture`/`grill-plan`/dispatch, then Step 8 live-config propagation.

## Open Questions
None — all four resolved on 2026-06-12; see `## Resolved`.
