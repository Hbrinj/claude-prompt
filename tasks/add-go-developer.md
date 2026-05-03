# add-go-developer

Add `agents/go-developer.md` — a developer agent that produces idiomatic Go code with mandatory tests, mirroring the discipline of the existing four developer agents (android, ios, flutter, kotlin-backend) and adapted to Go's idioms.

This plan is being produced via dogfooding the new `/grill-plan` skill. Mode: **software** (user override of the default — markdown deliverable normally maps to `general`, but the user wants slice-shape with Red/Green/Refactor discipline). Adaptation: "Test (Red)" is reframed as a **verifiable acceptance check** (grep, structural assertion) since markdown has no executable tests.

---

## Context

_Codebase facts learned during grilling._

- All four existing developer agents share the same skeleton, in this order: `## Role`, `## Starting state`, `## Target state`, `## NEVER do these`, `## Testing rules — ALWAYS enforce`, `## Allowed actions`, `## Steps`, `## Stop and ask before`.
- Every Role line opens with: *"You MUST write tests for every piece of logic you produce — no exceptions."*
- The `## Steps` section in every file is a rigid 7-step numbered checklist: scope confirm → context load → write source → write tests → run tests → run linter → report.
- Test framework choices vary by platform: Android/Kotlin-backend use JUnit 5 + MockK, iOS uses XCTest, Flutter uses `flutter_test` + `mocktail`/`mockito` + `bloc_test`.
- File scope rules vary by platform idiom (Android `src/test/` vs `src/androidTest/`, Flutter `test/` mirroring, iOS `*Tests` Xcode target, Kotlin-backend `src/test/kotlin/`).
- The Kotlin-backend agent is the only one with a domain-specific extra section (`## AWS rules — ALWAYS enforce`) covering IAM, SDK versioning, and service preferences. This sets a precedent for adding a Go-specific extra section if there's something analogous.
- Strictest test mandate (kotlin-backend): Testcontainers for integration tests against real DB/queue, no real AWS in unit tests, Lambda handler unit tests with crafted event objects.
- Most permissive (ios): no UI-level test mandate, DIY protocol-based mocking ("no third-party mock frameworks unless already present").
- Per the user's `~/.claude/CLAUDE.md`, this agent's scope is described as "Go (CLI tools, services, libraries)".
- The new `SYSTEM_PROMPT.md` (post `add-grill-plan-skill`) does NOT yet include a `go-developer` row in its Agent index — adding the row will be part of this change.
- `TODO.md` flags that this agent will eventually need a "Slice-aware execution" section (when the brief contains `## Slices`, execute one slice per commit, test-first). Open question whether to include that section now or defer per the existing TODO.

---

## Decisions

_Resolved through grilling. Each entry references the question that produced it._

1. **Mode** — software (user override of the default markdown→general mapping). "Test (Red)" reframed as verifiable acceptance check (grep / structural assertion). (Q1)
2. **Test framework and mocking** — `testing` (stdlib) + `testify/assert` for ergonomic assertions. Mocking is interface stubs only, hand-written test doubles, no `gomock`/`testify/mock`/etc. (mirrors iOS-developer's "no third-party mock frameworks" stance and Go culture's interface-stubbing preference). HTTP testing uses `net/http/httptest` (stdlib). DB/queue integration tests use `testcontainers-go` (mirrors kotlin-backend's Testcontainers stance). Benchmarks use `testing.B` when the brief calls for perf-sensitive code; not mandatory otherwise. (Q2)
3. **Coverage scope and naming** — hybrid mandate: every exported function with non-trivial behaviour MUST have a test, AND every handler/service/repository method (exported or not) MUST have a test. Every package must have at least one `_test.go` file. Naming uses Go-idiomatic `TestFoo` / `TestFoo_subcase` (matches stdlib convention; agent does not impose BDD-style names). Multi-case functions MUST use table-driven tests with a `cases := []struct{...}` pattern. (Q3)
4. **Lint and format toolchain** — `gofmt -l .` (must produce empty output), `go vet ./...` (must exit 0), `golangci-lint run ./...` with project-default config (must exit 0). For code touching `go` keyword, `chan`, `sync.*`, or `context.Context` cancellation, also `go test -race ./...` (must pass). Agent fixes all findings before reporting done. Project-level `.golangci.yml` overrides are respected; agent does not impose stricter linter sets. (Q4)
5. **File scope, package naming, project layout** — mirror existing project layout (agent inspects via Explore subagent before placing files; does not impose `cmd/internal/pkg`). Test files mirror source: `foo.go` ↔ `foo_test.go` in the same package directory. Package names are short, lowercase, no underscores, singular noun. Universal `internal/` rule enforced: agent MUST refuse to import packages under `<module>/internal/` from outside their module subtree. (Q5)
6. **Error handling** — modern hybrid idiom. Internal code wraps with `fmt.Errorf("...: %w", err)` to preserve chain. Public API uses typed errors (`type FooError struct{...}` with `Is(target error) bool`) when callers need to discriminate, plus sentinel errors (`var ErrFoo = errors.New(...)`) for stable identity. Inspection ALWAYS via `errors.Is` / `errors.As`, NEVER via `==` or string matching. Universal sub-rules: NEVER silent drop (`_ = err` requires `//nolint:errcheck` with reason); NEVER `panic(err)` for recoverable errors (only init / programmer errors); ALWAYS early-return on error. (Q6)
7. **Concurrency** — discourage by default; serial code is the starting position. Add goroutines only when the brief explicitly demands parallelism. When concurrency IS used, strict rules apply: every goroutine has an explicit owner (`sync.WaitGroup`, `errgroup.Group`, or context cancellation); every long-running goroutine respects `ctx.Done()`; channel direction in function signatures (`<-chan T` / `chan<- T`); prefer `errgroup.Group` over raw `WaitGroup` when goroutines can fail; `sync.Mutex` for shared mutable state (channels for ownership transfer, not state sync). Universal sub-rules: NEVER fire-and-forget; ALWAYS pass `ctx context.Context` as first parameter to functions that may block, do I/O, or spawn goroutines; NEVER swallow `ctx.Err()` after `select { case <-ctx.Done(): ... }`. (Q7)
8. **Slice-aware execution included in this agent** — the new agent ships with a "Slice-aware execution" section: when the developer brief contains `## Slices`, agent executes one slice per commit, in order, writing the failing test first, then the minimum implementation, then the refactor. Each commit message names the slice. `go-developer` becomes the reference implementation; TODO.md is updated to drop go-developer from its pending list while keeping the same work tracked for the other four developer agents. (Q8)
9. **Module and dependency hygiene** — strict. Always `go mod tidy` after touching imports; always `go mod verify` before reporting done; match the project's Go version (`go.mod` `go 1.X` directive); never silently bump the Go version; never add a dependency without surfacing it in the report; vendoring only when the project already uses it (mirror project); review `go.sum` diff before commit to catch supply-chain surprises. (Q9)
10. **Agent file structure** — three new top-level sections instead of one consolidated "Go rules" block. Final structure: `## Role` / `## Starting state` / `## Target state` / `## NEVER do these` / `## Testing rules — ALWAYS enforce` / `## Error handling — ALWAYS enforce` / `## Concurrency — ALWAYS enforce` / `## Module hygiene — ALWAYS enforce` / `## Slice-aware execution` / `## Allowed actions` / `## Steps` / `## Stop and ask before`. Reasons: sharp discoverability (jump straight to the section you need), natural extension (future Go-specific rules find their home organically), naming clarity ("Go rules" is a fuzzy boundary). Does not mirror kotlin-backend's `## AWS rules — ALWAYS enforce` consolidation — uniformity that's wrong shouldn't be preserved; cleanup of kotlin-backend tracked in TODO.md. (Q10)

---

## Slices

_Strict one-cycle TDD per slice. "Test (Red)" is reframed as a verifiable acceptance check (grep / structural assertion) since markdown has no executable tests — same discipline (define acceptance before writing), different mechanism. Each slice is one commit._

### Slice 1 — Skeleton scaffold
**Outcome:** `agents/go-developer.md` exists with the 7 boilerplate sections (Role, Starting state, Target state, NEVER do these, Allowed actions, Steps, Stop and ask before) populated by mirroring the structural shape of the four existing developer agents — adapted to Go (e.g. Role line opens with the same "You MUST write tests…" sentence; Steps follows the rigid 7-step checklist scope→context→source→tests→run tests→lint→report with Go-specific commands).
**Test (Red — verifiable acceptance check):** `for s in "## Role" "## Starting state" "## Target state" "## NEVER do these" "## Allowed actions" "## Steps" "## Stop and ask before"; do grep -qF "$s" agents/go-developer.md || echo MISSING "$s"; done` produces no `MISSING` output.
**Implementation (Green):** Create `agents/go-developer.md`. Author the 7 boilerplate sections by reading `agents/kotlin-backend-developer.md` (closest precedent — both are backend-style agents with strict testing) and substituting Go-specific terminology, commands, and examples. Steps section commands per Decision 4: `gofmt -l .`, `go vet ./...`, `golangci-lint run ./...`, `go test ./...` (+ `-race` flag if concurrency present), `go mod tidy && go mod verify`.
**Refactor:** Re-read for tone/voice consistency with the four existing developer agents (imperative voice, no hedging, sentence-level parallelism in NEVER lists).
**Acceptance:** Acceptance check above passes; file is between 80 and 200 lines (skeleton-only, before Q6/Q7/Q9 sections); reading the file top-to-bottom yields no obviously copy-pasted Kotlin terminology.

### Slice 2 — Testing rules section
**Outcome:** `## Testing rules — ALWAYS enforce` section exists in `agents/go-developer.md` and codifies Decisions 2 and 3: `testing` + `testify/assert`, no mocking framework, interface stubs only, `httptest` for HTTP, `testcontainers-go` for DB/queue, hybrid coverage mandate, `TestFoo` / `TestFoo_subcase` naming, table-driven for multi-case.
**Test (Red — verifiable acceptance check):** `grep -qF "## Testing rules — ALWAYS enforce" agents/go-developer.md && grep -qF "testify/assert" agents/go-developer.md && grep -qF "testcontainers-go" agents/go-developer.md && grep -qF "table-driven" agents/go-developer.md` exits 0.
**Implementation (Green):** Author the section. Sub-bullets cover framework, mocking stance (interface stubs, no third-party frameworks, mirroring iOS-developer's phrasing), HTTP testing (`net/http/httptest`), integration testing (`testcontainers-go` mirroring kotlin-backend), coverage mandate (hybrid: every exported function with non-trivial logic + every handler/service/repository method, exported or not + every package has at least one `_test.go`), naming convention (`TestFoo` / `TestFoo_subcase`, no BDD-style imposition), table-driven mandate for multi-case functions.
**Refactor:** Cross-check phrasing against android/kotlin-backend testing rules — the parallel structure should be obvious to a reader who reads both files back-to-back.
**Acceptance:** Acceptance check above passes; section is comprehensive enough that a Go developer reading it can predict what test code the agent will produce.

### Slice 3 — Error handling section
**Outcome:** `## Error handling — ALWAYS enforce` section exists in `agents/go-developer.md` and codifies Decision 6: `fmt.Errorf("...: %w", err)` wrapping for internal code, typed errors + sentinel errors at API boundaries, `errors.Is`/`errors.As` for inspection, universal sub-rules (no silent drops, no panic for recoverable errors, early-return on error).
**Test (Red — verifiable acceptance check):** `grep -qF "## Error handling — ALWAYS enforce" agents/go-developer.md && grep -qF "%w" agents/go-developer.md && grep -qF "errors.Is" agents/go-developer.md && grep -qF "errors.As" agents/go-developer.md && grep -qF "ErrFoo" agents/go-developer.md` exits 0.
**Implementation (Green):** Author the section. Subdivide into "Internal code" (wrap with `%w`), "Public API" (typed errors with `Is(target error) bool` method, sentinel errors for stable identity), "Inspection" (`errors.Is` / `errors.As`, never `==` or string matching), and "Universal NEVERs" (silent drop requires `//nolint:errcheck` with reason, never panic on recoverable errors, always early-return).
**Refactor:** Verify the section reads as opinionated guidance, not a Go tutorial. Trim any explanatory prose that a Go developer wouldn't need.
**Acceptance:** Acceptance check above passes; section names all three patterns (wrap / typed / sentinel) and the inspection idiom.

### Slice 4 — Concurrency section
**Outcome:** `## Concurrency — ALWAYS enforce` section exists in `agents/go-developer.md` and codifies Decision 7: discourage by default, strict rules when used, ownership requirement, ctx.Done() respect, channel direction in signatures, errgroup preference, sync.Mutex for shared state, universal sub-rules.
**Test (Red — verifiable acceptance check):** `grep -qF "## Concurrency — ALWAYS enforce" agents/go-developer.md && grep -qF "errgroup" agents/go-developer.md && grep -qF "ctx.Done()" agents/go-developer.md && grep -qF "context.Context" agents/go-developer.md && grep -qF "fire-and-forget" agents/go-developer.md` exits 0.
**Implementation (Green):** Author the section. Lead with "discourage by default" stance. Then the strict rules: ownership (waitgroup/errgroup/context), ctx.Done() respect for long-running goroutines, channel direction in function signatures (`<-chan T` / `chan<- T`), prefer `errgroup.Group` over raw `WaitGroup` when failure is possible, `sync.Mutex` for shared mutable state. Universal NEVERs: no fire-and-forget, ctx as first param for blocking/IO/spawning functions, never swallow `ctx.Err()`.
**Refactor:** Read against Q4's race-detector mandate — make sure the cross-reference to "+ run with -race" is present and clear.
**Acceptance:** Acceptance check above passes; section makes the "default serial, opt-in concurrency with strict rules" stance unmistakable.

### Slice 5 — Module hygiene section
**Outcome:** `## Module hygiene — ALWAYS enforce` section exists in `agents/go-developer.md` and codifies Decision 9: `go mod tidy` after touching imports, `go mod verify` before reporting done, match project's Go version, never silently bump, surface new dependencies in the report, vendoring mirrors project, review go.sum diff.
**Test (Red — verifiable acceptance check):** `grep -qF "## Module hygiene — ALWAYS enforce" agents/go-developer.md && grep -qF "go mod tidy" agents/go-developer.md && grep -qF "go mod verify" agents/go-developer.md && grep -qF "go.sum" agents/go-developer.md` exits 0.
**Implementation (Green):** Author the section. Cover: tidy mandate, verify mandate, Go version respect (read `go.mod` `go 1.X` directive, never silently bump), dependency surfacing (any new dep listed in the report so the user can audit), vendoring policy (mirror what the project already does, don't introduce or remove `vendor/`), supply-chain hygiene (review `go.sum` diff before commit).
**Refactor:** None expected — this section is mechanical.
**Acceptance:** Acceptance check above passes.

### Slice 6 — Slice-aware execution section
**Outcome:** `## Slice-aware execution` section exists in `agents/go-developer.md` and codifies Decision 8: when the brief contains `## Slices`, agent executes one slice per commit, in order, test-first, with the commit message naming the slice.
**Test (Red — verifiable acceptance check):** `grep -qF "## Slice-aware execution" agents/go-developer.md && grep -qF "one slice per commit" agents/go-developer.md && grep -qF "failing test first" agents/go-developer.md` exits 0.
**Implementation (Green):** Author the section. Cover: detect `## Slices` in the brief; execute slices in order; for each slice, write the failing test first (or, for non-executable acceptance checks, the equivalent assertion), then the minimum implementation, then the refactor; commit per slice with a message that names the slice (e.g. `Slice N — <outcome>`); never batch slices.
**Refactor:** Verify the section's wording is identical-in-spirit to the line in `SYSTEM_PROMPT.md` Step 2 — when the TODO eventually lands the same section in the other 4 agents, all five should be word-for-word consistent.
**Acceptance:** Acceptance check above passes; section length is between 10 and 25 lines (focused, no padding).

### Slice 7 — Repo integration
**Outcome:** Three integration points are updated so go-developer is discoverable by the rest of the system: (i) `agents/README.md` lists go-developer; (ii) `SYSTEM_PROMPT.md` adds go-developer to the Step 2 routing list and to the Agent index table; (iii) `TODO.md` is updated to drop go-developer from the slice-aware-pending list and add a new entry tracking the kotlin-backend cleanup (split `## AWS rules — ALWAYS enforce` into separate sections per the precedent set here).
**Test (Red — verifiable acceptance check):** `grep -qF "go-developer" agents/README.md && grep -qF "Go (CLI tools" SYSTEM_PROMPT.md && grep -qF "go-developer | \`agents/go-developer.md\`" SYSTEM_PROMPT.md && ! grep -qF "agents/go-developer.md\`)" TODO.md && grep -qF "kotlin-backend" TODO.md && grep -qF "AWS rules" TODO.md` exits 0. (Last three clauses verify TODO no longer references go-developer in the slice-aware list AND has a new kotlin-backend cleanup entry.)
**Implementation (Green):** Edit `agents/README.md` to add the row. Edit `SYSTEM_PROMPT.md` to add `Go (CLI tools, services, libraries) → go-developer (agents/go-developer.md)` under Step 2's routing list, and add the `| go-developer | agents/go-developer.md | Step 2 |` row to the Agent index table. Edit `TODO.md`: drop `go-developer` from the existing list (which currently still says 4 agents — confirm the count is correct) and add a new "Clean up kotlin-backend AWS rules section" entry with the rationale from Decision 10 (split into separate top-level sections matching go-developer's precedent).
**Refactor:** Re-run all six earlier acceptance checks plus this one in sequence — confirms the file is internally consistent across all slices.
**Acceptance:** Acceptance check above passes; `git diff` shows exactly 3 files changed in this slice (README, SYSTEM_PROMPT, TODO).

---

## Open Questions

_To be filled in if any branches go unresolved at termination._
