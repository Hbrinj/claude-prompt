# TODO

Future-state work not part of any active feature branch.

## Fix lint-step / test-step wording in agents/go-developer.md

`agents/go-developer.md:61` reads *"the lint step also runs `go test -race ./...`"*, but `-race` is actually invoked under the test step (Step 5 of the `## Steps` checklist), NOT the lint step (Step 6). One-word fix: change `lint` → `test` on that line so a reader cross-referencing the Concurrency section against the Steps list lands in the right place.

**Why deferred**: surfaced as a SUGGESTION in the cycle 1 review of `add-go-developer` and not fixed per the workflow rule (apply only CRITICAL/MAJOR). Then surfaced again as a candidate to bundle into `extend-slice-aware-to-other-agents` and explicitly rejected (Decision 4 — bounded scope wins). Should be addressed in a future micro-PR.
