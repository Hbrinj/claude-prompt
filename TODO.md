# TODO

Items deferred as out-of-scope from feature planning. Triage manually.

## From feature/add-go-developer
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Fix `lint` → `test` wording in `agents/go-developer.md:61` (line reads *"the lint step also runs `go test -race ./...`"* but `-race` runs under the test step, not the lint step) | Surfaced as SUGGESTION in cycle 1 review of `add-go-developer` (workflow rule: apply only CRITICAL/MAJOR). Then rejected from `extend-slice-aware-to-other-agents` to keep bounded scope (Decision 4 there). Should be addressed in a future micro-PR. | `tasks/extend-slice-aware-to-other-agents.md` Decision 4 | 2026-05-03 | Open |

## Self-evolution
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Design persistent memory of user interactions so Claude can learn lessons across sessions and consolidate new thinking into concrete suggestions for its own evolution (workflow rules, agent definitions, skill prompts). Should specify: what gets captured, where it lives (relative to existing auto-memory at `~/.claude/projects/.../memory/` and this repo's `agents/`/`skills/`), how lessons get reviewed/promoted into committed agent/skill changes, and the trigger cadence (per-session, per-feature, manual). | Out of scope — needs its own grill-plan session; touches the meta-workflow itself, so impacts every future feature. | — | 2026-05-03 | Open |

## Workflow
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Discuss how to split tasks down further so that each pull request stays reviewable. Current `## Slices` convention bundles all slices of a feature into a single PR, which can grow large. Should explore: criteria for when to split a feature into multiple PRs, how slices map to PRs (1:1, grouped, stacked), how `features/all_features.md` and the checkpoint file track multi-PR features, and whether `/grill-plan` should output a PR-split proposal. | Needs its own grill-plan session — affects the core Step 2 workflow and PR conventions. | — | 2026-05-03 | Open |
| Lock down each agent's `tools:` (and possibly `model:`) in its frontmatter so capabilities match the agent's role. Read-only reviewers (`code-reviewer`, `security-reviewer`, `architecture`) should not have Edit/Write/Bash-mutation tools; developer agents should not have GitHub-issue mutation tools; `issue-liaison` should not have code-edit tools. Should specify: per-agent allowed tool list, whether to constrain `model:` per agent, and how to keep the lockdown in sync when new tools appear. | Needs its own grill-plan session — affects every agent definition and could break existing workflows if too restrictive. | — | 2026-05-03 | Open |
| Split tasks into ones where multiple sub-agents can act in parallel. Today the workflow runs one developer agent per task end-to-end; explore decomposing a task/plan into independent units of work that can be dispatched to multiple agents concurrently (e.g. parallel slices, frontend/backend split, independent modules). Should specify: how `/grill-plan` marks parallelizable units, how the coordinator dispatches and joins results, conflict/merge handling on a shared branch, and how the checkpoint + feature log track multi-agent execution. | Needs its own grill-plan session — changes the core Step 2 dispatch model and concurrency semantics. | — | 2026-05-04 | Open |

## From feature/parallel-sub-agents
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Pre-dispatch overlap detection — at the moment the user provides the parallel feature list, coordinator inspects each plan's file references and warns if two plans touch the same path (e.g. *"plans X and Y both touch `agents/foo.md` — dispatch sequentially?"*). Should specify how plans expose their file references (explicit `## Files` section? heuristic scan?), false-positive tolerance, and whether the warning is advisory or blocking. | Discussed during Q7 grilling; chose the standard GitHub merge flow first because it works without new tooling. Worth revisiting if conflicts become a recurring pain. | Decision 7 | 2026-05-04 | Open |
