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
