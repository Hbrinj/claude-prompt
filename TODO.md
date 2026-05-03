# TODO

Items deferred as out-of-scope from feature planning. Triage manually.

## From feature/add-go-developer
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Fix `lint` → `test` wording in `agents/go-developer.md:61` (line reads *"the lint step also runs `go test -race ./...`"* but `-race` runs under the test step, not the lint step) | Surfaced as SUGGESTION in cycle 1 review of `add-go-developer` (workflow rule: apply only CRITICAL/MAJOR). Then rejected from `extend-slice-aware-to-other-agents` to keep bounded scope (Decision 4 there). Should be addressed in a future micro-PR. | `tasks/extend-slice-aware-to-other-agents.md` Decision 4 | 2026-05-03 | Open |
