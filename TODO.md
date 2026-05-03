# TODO

Future-state work not part of any active feature branch.

## Make developer agents slice-aware

The `grill-plan` skill produces plans with a `## Slices` section (one vertical slice per TDD cycle). Today, TDD/slice discipline is enforced only by the coordinator via the workflow in `SYSTEM_PROMPT.md` (synced into `~/.claude/CLAUDE.md`) — the developer agent definitions themselves (`agents/android-developer.md`, `agents/ios-developer.md`, `agents/flutter-developer.md`, `agents/kotlin-backend-developer.md`) say nothing about slices or test-first execution.

This works as long as `grill-plan` is invoked inside the coordinator workflow. A user who invokes `/grill-plan` standalone gets the slice-shaped plan without any agent-side enforcement.

**Action**: extend each developer agent with a "Slice-aware execution" section — when the brief contains `## Slices`, execute one slice per commit in order: write the failing test first, then the minimum implementation, then refactor. Commit per slice with a message that names the slice.

**Why deferred**: the `grill-plan` skill change was scoped to replacing the researcher + planner agents. Touching 4 developer agent definitions would have ballooned that diff and the review cost. Tracked here for a follow-up change.

**Note**: a `go-developer` agent is referenced in some out-of-repo coordinator docs but does not yet exist in this repo. When/if it is added, this TODO should be extended to cover it.
