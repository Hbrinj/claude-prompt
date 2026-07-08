---
name: react-typescript
description: Stack brief for React + TypeScript web work (SPAs, components, hooks, client-side logic) — loaded by the developer agent. Vitest unit tests, React Testing Library component tests, strict type-safety, hooks-only patterns.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`.

## Stack NEVERs
- NEVER touch the project's `node` engine pin, `typescript` major version, or `react` major version — match what is already declared
- NEVER use `any` to silence the type-checker — use `unknown` and narrow, or model the type properly
- NEVER write snapshot tests unless the brief explicitly requests one — they rot and rarely catch real regressions
- NEVER reach into another package's internals via deep imports — use the published entry point
- NEVER write class components for new code — function components + hooks only
- NEVER mutate React state directly (`state.x = y`); always go through the setter / reducer
- NEVER call hooks conditionally or inside loops — Rules of Hooks are non-negotiable

## Testing rules
- Use **Vitest** as the test runner (preferred) or **Jest** if the project is already on it — match what the project uses; do not introduce a second runner
- Use **@testing-library/react** for component tests. Query by accessible role / label / text — NEVER by CSS class; prefer `data-testid` only when no accessible query exists
- Use **@testing-library/user-event** for user interactions, not `fireEvent`, unless the test specifically needs low-level event dispatch
- Mocking: hand-written test doubles and `vi.fn()` / `jest.fn()` for callbacks; `msw` for HTTP. Do NOT introduce other mocking libraries unless already present
- Coverage mandate: every exported function / hook / component with non-trivial behaviour MUST have a test. Every component that owns state, accepts user input, or calls a side-effect MUST have a test
- Test file location: co-located with the source file, `.test.ts` / `.test.tsx` suffix (e.g. `useFoo.ts` ↔ `useFoo.test.ts`)
- Test naming: descriptive `describe('Foo', () => { it('does X when Y', ...) })` — don't leak implementation details into test names
- For functions with more than one meaningful input/output case, use a table-driven test: `it.each([...])('does X for %s', ...)`
- Every test MUST cover: happy path, error/failure path, and at least one edge case (empty input, max input, async race, etc.)
- For components with async behaviour, use `findBy*` queries or `waitFor` — never arbitrary `setTimeout` sleeps
- For Playwright E2E (when the brief calls for it): one happy-path scenario per feature unless explicitly broader; place under `e2e/` with `.spec.ts` suffix

## Type safety
- `tsconfig.json` MUST have `strict: true`. If it does not, surface that as a stop-and-ask before writing new code
- Public component props and hook signatures are explicitly typed via `interface` or `type` — NEVER rely on inference for an exported API
- Prefer `type` for unions and primitives, `interface` for object shapes that may be extended — be consistent with the project
- Discriminated unions for state machines and variant types: `type State = { kind: 'idle' } | { kind: 'loading' } | { kind: 'error'; message: string }`
- NEVER cast with `as` unless narrowing from `unknown` after a runtime check
- `// @ts-expect-error` and `// @ts-ignore` require an inline justification comment
- Errors thrown across module boundaries should be typed (`class FooError extends Error`) so callers can `instanceof`-narrow

## React patterns
- Function components + hooks only; no legacy lifecycle methods
- State lives at the lowest level that needs it; lift only when shared. Reach for `useReducer` over multiple `useState` calls when state transitions are coupled
- `useEffect` is for synchronising with external systems, NOT for deriving state from props — derived state is computed during render or via `useMemo`
- Every `useEffect` lists its dependencies exhaustively. If lint flags a missing dependency, fix the code — do not suppress the rule
- Memoise (`useMemo` / `useCallback`) only when profiling or a clear referential-equality requirement demands it
- Side effects (fetch, subscribe, timers) MUST have cleanup — unsubscribe functions, cleared timers
- Keys on rendered lists MUST be stable IDs from the data, NEVER array indices unless the list is append-only and order-permanent
- Forms: controlled inputs for anything with validation or cross-field logic; uncontrolled + `ref` acceptable for simple single-field forms

## Styling
- Match the project's existing styling approach (CSS Modules, Tailwind, styled-components, vanilla CSS, etc.). NEVER introduce a second styling system without asking
- No inline `style={{ ... }}` beyond a single dynamic value — static styles belong in the styling layer

## Project hygiene
- Match the project's package manager: `pnpm-lock.yaml` → `pnpm`, `yarn.lock` → `yarn`, `bun.lockb` → `bun`, otherwise `npm`. NEVER mix package managers
- Run the package manager's install after any dependency change — `package.json` and the lockfile MUST stay in sync
- Review the lockfile diff before committing. Unexpected new transitive packages or hash changes for pinned versions are a stop-and-ask condition — possible supply-chain surprise
- Surface every newly-introduced direct dependency in the evidence report

## Verification commands
- The project's test command (e.g. `npx vitest run`) — all passing; run Playwright E2E too when the change touches user-visible behaviour and Playwright is configured
- `npx tsc --noEmit` (or the project's typecheck script) — exit 0
- The project's lint script — exit 0; the project's format check — clean

## Stop and ask (stack)
- Bumping the major version of `react`, `typescript`, `vite`, or the test runner
- Switching the project's package manager
- Switching or adding a styling system, state-management library, or router
- Enabling or disabling `strict` (or any other `tsconfig.json` strictness flag) project-wide
- Changing an exported component or hook signature already in use
