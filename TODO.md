# TODO

Future-state work not part of any active feature branch.

## Make remaining developer agents slice-aware

The `grill-plan` skill produces plans with a `## Slices` section (one vertical slice per TDD cycle). `agents/go-developer.md` ships with its own `## Slice-aware execution` section as the reference implementation. The other four developer agents (`agents/android-developer.md`, `agents/ios-developer.md`, `agents/flutter-developer.md`, `agents/kotlin-backend-developer.md`) do NOT yet have an equivalent section — slice/TDD discipline for those stacks is enforced only by the coordinator via `SYSTEM_PROMPT.md` (synced into `~/.claude/CLAUDE.md`).

This works as long as `grill-plan` is invoked inside the coordinator workflow. A user who invokes `/grill-plan` standalone gets the slice-shaped plan without any agent-side enforcement (for those four stacks).

**Action**: copy the `## Slice-aware execution` section from `agents/go-developer.md` into each of the four other developer agents, with stack-appropriate adjustments to commands and test verbs.

**Why deferred**: the `grill-plan` and `go-developer` changes were each scoped to bound their diffs; converging four more agents in those PRs would have ballooned review cost. Tracked here for a follow-up change that touches all four together.

## Clean up kotlin-backend AWS rules section

`agents/kotlin-backend-developer.md` consolidates its domain-specific opinions in a single `## AWS rules — ALWAYS enforce` section. The newer `agents/go-developer.md` (Decision 10 of `tasks/add-go-developer.md`) instead uses three top-level sections (`## Error handling — ALWAYS enforce`, `## Concurrency — ALWAYS enforce`, `## Module hygiene — ALWAYS enforce`) on the grounds that sharp discoverability beats consolidated-with-subsections, and that a "Go rules" / "AWS rules" name is a fuzzy boundary.

The two agents now have a structural mismatch.

**Action**: split kotlin-backend's `## AWS rules — ALWAYS enforce` into separate top-level sections following go-developer's precedent. Likely candidates: `## AWS SDK conventions`, `## IAM rules`, `## Lambda handlers`, `## Persistence` (DynamoDB / RDS) — exact split to be determined when the cleanup is done.

**Why deferred**: out of scope for the `add-go-developer` change. Tracked so the structural mismatch is explicit and addressable.
