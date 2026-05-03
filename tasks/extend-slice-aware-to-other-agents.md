# extend-slice-aware-to-other-agents

Extend the `## Slice-aware execution` section from `agents/go-developer.md` (the reference implementation) into the four other developer agents — `android-developer`, `ios-developer`, `flutter-developer`, `kotlin-backend-developer` — so that slice/TDD discipline is enforced agent-side for every supported stack, not only via the coordinator workflow.

This plan is being produced via `/grill-plan` (manual protocol invocation, since the skill is not loaded as a callable tool in this session). Mode: **software** (one slice per agent maps 1:1 to one commit per agent). "Test (Red)" is reframed as a verifiable grep acceptance check since the deliverable is markdown.

---

## Context

_Codebase facts._

- `agents/go-developer.md` (lines ~73–86) contains the canonical `## Slice-aware execution` section, written in stack-neutral language ("failing test", "minimum implementation", "commit", "acceptance check"). Nothing in the section references Go-specific tooling.
- The four target agents (`android-developer`, `ios-developer`, `flutter-developer`, `kotlin-backend-developer`) all share the same skeleton sections (Role / Starting state / Target state / NEVER do these / Testing rules — ALWAYS enforce / Allowed actions / Steps / Stop and ask before). `kotlin-backend-developer` additionally has `## AWS rules — ALWAYS enforce`.
- Per the precedent set in `agents/go-developer.md` (Decision 10 of `tasks/add-go-developer.md`), the Slice-aware section sits **between** the agent's last `## ... — ALWAYS enforce` section and the `## Allowed actions` section.
- `TODO.md` currently lists this work as an open item: *"copy the `## Slice-aware execution` section from `agents/go-developer.md` into each of the four other developer agents, with stack-appropriate adjustments to commands and test verbs."*
- The deferred kotlin-backend AWS-rules-cleanup TODO is a separate item — out of scope here.

---

## Decisions

_Resolved through grilling. To be filled as questions are answered._

1. **Mode** — software (override per Q1; user reaffirmed slice-shape preference for this kind of meta-work). "Test (Red)" reframed as verifiable grep acceptance check. (Q1)
2. **Adaptation strategy** — verbatim copy of `agents/go-developer.md`'s `## Slice-aware execution` section into each of the four target agents. The section is stack-neutral by design (no Go-specific tooling, syntax, or patterns) — adaptation would introduce drift surface for no readability win. Cross-agent consistency wins; future semantic changes propagate via find-and-replace across all 5 agents. (Q2)
3. **Slice structure** — 4 agent-edit slices (android, ios, flutter, kotlin-backend) + 1 TODO-update slice. Dogfoods the rule being installed: "execute one slice per commit, never batch slices." Each agent's commit is independently revertable. (Q3)
4. **Bundling** — no bundling of unrelated fixes into this PR. The lint-step / test-step typo in `agents/go-developer.md:61` (deferred SUGGESTION from the previous review — `-race` is actually invoked under the test step, not the lint step) is NOT fixed here. Instead, it gets a new entry in `TODO.md` so it doesn't get lost. This keeps this PR's scope bounded to "extend slice-aware to other agents." (Q4)

---

## Slices

_Strict one-cycle TDD per slice. "Test (Red)" is a verifiable grep acceptance check (markdown deliverable, no executable tests). Each slice = one commit._

The verbatim section to copy in slices 1–4 is the entire `## Slice-aware execution` block from `agents/go-developer.md` (currently lines ~73–86 — read the file at slice-time to get the canonical text). Per Decision 2, the section text MUST be byte-identical across all 5 agents after this PR ships.

### Slice 1 — android-developer
**Outcome:** `agents/android-developer.md` gains a `## Slice-aware execution` section, byte-identical to `agents/go-developer.md`'s section, placed between `## Testing rules — ALWAYS enforce` and `## Allowed actions`.
**Test (Red — verifiable acceptance check):** `grep -qF "## Slice-aware execution" agents/android-developer.md && grep -qF "one slice per commit" agents/android-developer.md && grep -qF "failing test first" agents/android-developer.md && grep -qF "NEVER batch slices" agents/android-developer.md` exits 0.
**Implementation (Green):** Read the canonical section from `agents/go-developer.md`. Insert verbatim into `agents/android-developer.md` immediately after the closing line of `## Testing rules — ALWAYS enforce`, with a blank line above and below. Confirm placement is BEFORE `## Allowed actions`.
**Refactor:** Run a `diff <(sed -n '/^## Slice-aware execution$/,/^## Allowed actions$/p' agents/go-developer.md | sed '$d') <(sed -n '/^## Slice-aware execution$/,/^## Allowed actions$/p' agents/android-developer.md | sed '$d')` (or equivalent block-extract) — output MUST be empty (byte-identical sections).
**Acceptance:** Acceptance check above passes; section is byte-identical to go-developer's; commit touches only `agents/android-developer.md`.

### Slice 2 — ios-developer
**Outcome:** `agents/ios-developer.md` gains the same `## Slice-aware execution` section, byte-identical, placed between `## Testing rules — ALWAYS enforce` and `## Allowed actions`.
**Test (Red — verifiable acceptance check):** `grep -qF "## Slice-aware execution" agents/ios-developer.md && grep -qF "one slice per commit" agents/ios-developer.md && grep -qF "failing test first" agents/ios-developer.md && grep -qF "NEVER batch slices" agents/ios-developer.md` exits 0.
**Implementation (Green):** Same procedure as Slice 1, target file `agents/ios-developer.md`.
**Refactor:** Same byte-equality diff against `agents/go-developer.md` MUST produce empty output.
**Acceptance:** Acceptance check above passes; section byte-identical; commit touches only `agents/ios-developer.md`.

### Slice 3 — flutter-developer
**Outcome:** `agents/flutter-developer.md` gains the same `## Slice-aware execution` section, byte-identical, placed between `## Testing rules — ALWAYS enforce` and `## Allowed actions`.
**Test (Red — verifiable acceptance check):** `grep -qF "## Slice-aware execution" agents/flutter-developer.md && grep -qF "one slice per commit" agents/flutter-developer.md && grep -qF "failing test first" agents/flutter-developer.md && grep -qF "NEVER batch slices" agents/flutter-developer.md` exits 0.
**Implementation (Green):** Same procedure as Slice 1, target file `agents/flutter-developer.md`.
**Refactor:** Same byte-equality diff against `agents/go-developer.md` MUST produce empty output.
**Acceptance:** Acceptance check above passes; section byte-identical; commit touches only `agents/flutter-developer.md`.

### Slice 4 — kotlin-backend-developer
**Outcome:** `agents/kotlin-backend-developer.md` gains the same `## Slice-aware execution` section, byte-identical, placed between `## AWS rules — ALWAYS enforce` (the agent's last `## ... — ALWAYS enforce` section) and `## Allowed actions`.
**Test (Red — verifiable acceptance check):** `grep -qF "## Slice-aware execution" agents/kotlin-backend-developer.md && grep -qF "one slice per commit" agents/kotlin-backend-developer.md && grep -qF "failing test first" agents/kotlin-backend-developer.md && grep -qF "NEVER batch slices" agents/kotlin-backend-developer.md` exits 0.
**Implementation (Green):** Same procedure as Slice 1 BUT placement target is after `## AWS rules — ALWAYS enforce`, NOT after `## Testing rules`. Pre-check by reading the file's section ordering before editing.
**Refactor:** Same byte-equality diff against `agents/go-developer.md` MUST produce empty output. Additionally verify `## AWS rules — ALWAYS enforce` was not displaced.
**Acceptance:** Acceptance check above passes; section byte-identical; commit touches only `agents/kotlin-backend-developer.md`.

### Slice 5 — TODO update
**Outcome:** `TODO.md` no longer contains the "Make remaining developer agents slice-aware" entry (work is complete after slices 1–4). A new entry is added tracking the lint-step / test-step wording typo in `agents/go-developer.md:61` (per Decision 4).
**Test (Red — verifiable acceptance check):** `! grep -qF "Make remaining developer agents slice-aware" TODO.md && grep -qF "lint step" TODO.md && grep -qF "test step" TODO.md && grep -qF "agents/go-developer.md" TODO.md` exits 0. (First clause: completed entry removed. Other clauses: new entry mentions both terms and the file path.)
**Implementation (Green):** Edit `TODO.md`: delete the entire `## Make remaining developer agents slice-aware` section (now done). Add a new section `## Fix lint-step / test-step wording in agents/go-developer.md` with body explaining: line 61 of `agents/go-developer.md` says "the lint step also runs `go test -race ./...`" but `-race` actually runs under the test step (Step 5), not the lint step (Step 6). One-word fix (`lint` → `test`). Deferred from cycle 1 of `add-go-developer`'s code review per the workflow rule (apply only CRITICAL/MAJOR). Should be addressed in a future micro-PR or alongside the kotlin-backend AWS-rules cleanup (which already touches developer-agent files). Keep the existing kotlin-backend cleanup section unchanged.
**Refactor:** Read TODO.md top to bottom; verify it remains internally consistent (no orphan references, no broken markdown).
**Acceptance:** Acceptance check above passes; `TODO.md` has exactly 2 `## ...` second-level headings (kotlin-backend cleanup + new lint/test typo entry); commit touches only `TODO.md`.

---

## Open Questions

_None yet._
