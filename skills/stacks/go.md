---
name: go
description: Stack brief for Go work (CLI tools, services, libraries) — loaded by the developer agent. Idiomatic Go with mandatory _test.go files, strict error handling, disciplined concurrency, tidy modules.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`.

## Stack NEVERs
- NEVER touch `go.mod`'s `go 1.X` version directive — match what is already declared
- NEVER import packages from another module's `internal/` subtree

## Testing rules
- Use the standard library `testing` package + `testify/assert` for ergonomic assertions
- Mocking is interface stubs only — hand-written test doubles. NO third-party mocking frameworks (`gomock`, `testify/mock`, etc.) unless already present in the project
- HTTP handlers and clients: test with `net/http/httptest`
- Integration tests that touch a real database, queue, or external service: use `testcontainers-go`
- Coverage mandate: every exported function with non-trivial behaviour MUST have a test, AND every handler/service/repository method (exported or not) MUST have a test. Every package MUST have at least one `_test.go` file
- Test file location: same package directory as the source file, with `_test.go` suffix (e.g. `auth.go` ↔ `auth_test.go`)
- Test naming: Go-idiomatic `TestFoo` for the basic case, `TestFoo_subcase` for variants. Do NOT use BDD-style `TestFoo_WhenX_ThenY` names
- For functions with more than one meaningful input/output case, use a table-driven test: `cases := []struct{name string; in T; want U}{...}` with `for _, tc := range cases { t.Run(tc.name, ...) }`
- Every test MUST cover: happy path, error/failure path, and at least one edge case
- Benchmarks (`testing.B`) are required only when the brief explicitly calls for perf-sensitive code

## Error handling
**Internal code** — wrap with `fmt.Errorf("doing X: %w", err)` to preserve the error chain. Never lose context by returning a bare `err`.

**Public API** — when callers need to discriminate error kinds:
- Sentinel errors for stable identity: `var ErrNotFound = errors.New("user: not found")`
- Typed errors when callers need additional fields: `type ValidationError struct { Field string; Reason string }` plus an `Is(target error) bool` method so `errors.Is` works.

**Inspection** — ALWAYS use `errors.Is(err, ErrFoo)` or `errors.As(err, &target)`. NEVER compare with `==` or match on `err.Error()` strings.

**Universal rules**:
- NEVER `_ = err` (silent drop). If an error genuinely cannot be handled, document the reason inline with `//nolint:errcheck // <reason>` so reviewers see it
- NEVER `panic(err)` for recoverable errors. Panics belong in `init()` (programmer-error setup) and nowhere else
- ALWAYS early-return on error: `if err != nil { return ..., fmt.Errorf("...: %w", err) }`. Do not nest happy-path logic under conditionals

## Concurrency
**Default to serial code.** Add goroutines only when the brief explicitly demands parallelism — premature concurrency is the most common Go anti-pattern.

When concurrency IS used:
- Every goroutine MUST have an explicit owner: `sync.WaitGroup`, `golang.org/x/sync/errgroup.Group`, or a parent's `context.Context` cancellation. NEVER fire-and-forget
- Every long-running goroutine MUST respect `ctx.Done()` and return promptly when the context is cancelled
- Function signatures MUST declare channel direction: `func consume(ch <-chan T)` (receive-only), `func produce(ch chan<- T)` (send-only)
- Prefer `errgroup.Group` over raw `sync.WaitGroup` whenever a goroutine can return an error
- For shared mutable state use `sync.Mutex` / `sync.RWMutex` / `atomic.*`. Channels are for ownership transfer and signalling, NOT for state synchronisation
- ALWAYS pass `ctx context.Context` as the FIRST parameter of any function that may block, perform I/O, or spawn goroutines
- NEVER swallow `ctx.Err()` — when `select { case <-ctx.Done(): }` fires, the function MUST return `ctx.Err()` (wrapped if adding context)

## Module hygiene
- Run `go mod tidy` after any change that adds, removes, or moves an import — `go.mod` and `go.sum` MUST stay in sync with the source
- Run `go mod verify` before reporting done — any mismatch is a stop-and-ask condition
- Match the project's Go version: read the `go 1.X` directive in `go.mod` and respect it
- Surface every newly-introduced direct dependency in the evidence report
- Vendoring policy: mirror what the project already does. If `vendor/` exists, keep it in sync; if not, do NOT introduce one
- Review the `go.sum` diff before committing. Unexpected lines (transitive dependencies you did not knowingly pull in, hash changes for already-pinned versions) are a stop-and-ask condition — they may indicate a supply-chain surprise

## Verification commands
- `go build ./...` and `go test ./...` — all passing
- `go test -race ./...` whenever the diff touches `go`/`chan`/`sync.*`/`context.Context`
- `gofmt -l .` (must be empty), `go vet ./...` (exit 0), `golangci-lint run ./...` (exit 0)
- `go mod tidy && go mod verify` (exit 0)

## Stop and ask (stack)
- Bumping the `go` directive in `go.mod`
- Introducing or removing the `vendor/` directory
- Creating a new package at the top of the module tree
- Introducing concurrency (goroutines/channels) into code that was previously serial
