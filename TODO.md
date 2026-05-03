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
