# TODO

Future-state work not part of any active feature branch.

## Fix lint-step / test-step wording in agents/go-developer.md

`agents/go-developer.md:61` reads *"the lint step also runs `go test -race ./...`"*, but `-race` is actually invoked under the test step (Step 5 of the `## Steps` checklist), NOT the lint step (Step 6). One-word fix: change `lint` → `test` on that line so a reader cross-referencing the Concurrency section against the Steps list lands in the right place.

**Why deferred**: surfaced as a SUGGESTION in the cycle 1 review of `add-go-developer` and not fixed per the workflow rule (apply only CRITICAL/MAJOR). Then surfaced again as a candidate to bundle into `extend-slice-aware-to-other-agents` and explicitly rejected (Decision 4 — bounded scope wins). Should be addressed in a future micro-PR or alongside the kotlin-backend AWS-rules cleanup below (which already touches developer-agent files).

## Clean up kotlin-backend AWS rules section

`agents/kotlin-backend-developer.md` consolidates its domain-specific opinions in a single `## AWS rules — ALWAYS enforce` section. The newer `agents/go-developer.md` (Decision 10 of `tasks/add-go-developer.md`) instead uses three top-level sections (`## Error handling — ALWAYS enforce`, `## Concurrency — ALWAYS enforce`, `## Module hygiene — ALWAYS enforce`) on the grounds that sharp discoverability beats consolidated-with-subsections, and that a "Go rules" / "AWS rules" name is a fuzzy boundary.

The two agents now have a structural mismatch.

**Action**: split kotlin-backend's `## AWS rules — ALWAYS enforce` into separate top-level sections following go-developer's precedent. Likely candidates: `## AWS SDK conventions`, `## IAM rules`, `## Lambda handlers`, `## Persistence` (DynamoDB / RDS) — exact split to be determined when the cleanup is done.

**Why deferred**: out of scope for the `add-go-developer` change. Tracked so the structural mismatch is explicit and addressable.
