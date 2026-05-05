# add-shell-developer-agent

Add a new developer agent specialised for bash/shell scripts (and the markdown prose files that often co-evolve with them) so the coordinator workflow has a correct delegation target for shell-script work. Today's `agents/` directory covers Android, iOS, Flutter, Kotlin-backend, and Go but has no shell-script agent, leaving shell features (e.g. `tasks/location-independent-dispatch-wrapper.md`) without a clean delegation target.

## Context
_Codebase facts and constraints learned during grilling._
- All five existing developer agents (`android-developer.md`, `ios-developer.md`, `flutter-developer.md`, `kotlin-backend-developer.md`, `go-developer.md`) share an identical frontmatter shape — only two fields: `name` and `description`. **No `model` field, no `tools` field** in any of them.
- Every developer agent has the same top-level section order: `## Role` → `## Starting state` → `## Target state` → `## NEVER do these` → `## Testing rules — ALWAYS enforce` → (optional language-specific sections) → `## Self-review before return` → `## Slice-aware execution` → `## Allowed actions` → `## Steps` (7 numbered) → `## Stop and ask before`.
- The `## Self-review before return` and `## Slice-aware execution` sections are **word-for-word identical** across all five existing developer agents. Mirror them verbatim.
- `## Testing rules — ALWAYS enforce` is the main divergence point — each agent specifies its language's test framework, file convention, and naming pattern (e.g., go-developer uses `_test.go` + `testing`+`testify`; android uses JUnit 5 + MockK with `methodName_givenCondition_shouldExpectedBehavior`).
- `agents/README.md:3-16` catalogues agents in a two-column table: `| Agent | Description |` with `[name](file.md)` link and one-sentence description.
- `SYSTEM_PROMPT.md:127-137` Agent index is a three-column table: `| Agent | File | Called in |` with bare agent name, backticked relative path, and the workflow step plus parenthetical trigger.
- `SYSTEM_PROMPT.md` Step 2.2 carries a tech-stack routing bullet list (currently 5 stacks) — this is the *decision input* the coordinator consults when picking a developer agent.
- The motivating downstream feature is `tasks/location-independent-dispatch-wrapper.md` — its slice 4 changes both `parallel-docker-dispatch.md` (skill prose) AND `README.md` AND `scripts/dispatch-docker-worker.sh` in the same conceptual unit. A shell-only agent would force that slice to dispatch to two agents; a shell+prose agent handles it cleanly.
- The repo's tests live at `scripts/test-<topic>.sh` and are bare bash with `set -euo pipefail` (no `bats`/`shunit2`). The repo README already documents GNU vs BSD tooling pain (`coreutils`/`flock` install on macOS) — agent prompt should bake this in as a default rather than rediscover it.

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **Mode** — general (non-software). Output uses `## Steps`, not `## Slices`. Adding an agent definition is markdown prose authoring; no executable behaviour ships from this feature itself.
2. **Scope (D1)** — shell + adjacent prose. Agent owns `*.sh` files plus the markdown prose that documents the script's contract (`skills/*.md`, `README.md`, sibling agent prompts, inline help). Lets a single dispatch own both halves of features like the wrapper-feature's slice 4. Boundary is sharp: it's the prose describing the script's invocation/contract, not all docs (architecture, plans, feature logs stay with their existing owners).
3. **Name (D2)** — `shell-developer`. Single-word stack + `-developer` matches `go-developer` / `ios-developer` convention. Broad enough for bash/sh/zsh, narrow enough not to overlap with other interpreted-language stacks. Frontmatter `description` carries the shell+prose scope detail.
4. **Test framework (D3)** — bare bash with `set -euo pipefail`, mirroring the in-repo `scripts/test-<topic>.sh` pattern. No `bats` / `shunit2` mandate. File path: `scripts/test-<topic>.sh`. Assertions via shell idioms (`[`, `[[`, `grep -q`, exit codes). Fixtures: real (mktemp, ephemeral git repos), torn down on `trap … EXIT`. Default to this pattern unless a project already uses a different convention.
5. **Custom sections (D4)** — beyond the universal skeleton, add three language-specific sections: `## Shell hygiene — ALWAYS enforce` (strict mode, quoting, `[[ ]]`/`[ ]`, traps, `set -e` + `||` interactions, allow-list input validation), `## Portability — ALWAYS enforce` (bash vs POSIX `sh`, GNU vs BSD tool divergence — `timeout`/`sed`/`readlink` — `command -v` checks before non-default tools), `## Prose discipline — ALWAYS enforce` (runnable examples in sync with script behaviour, absolute paths where script demands them, no inventing flags). Inserted between `## Testing rules` and `## Self-review before return`, matching go-developer's placement of its custom sections.
6. **Self-review loop (D5)** — mirror the existing developer agents verbatim. `## Self-review before return` invokes `code-reviewer` only, ≤3 cycles, applies CRITICAL+MAJOR each round, returns BLOCKED on exhaustion. The coordinator's file-type routing gate (SYSTEM_PROMPT.md Step 2.3) handles `prompt-definition-reviewer` (for `skills/`/`agents/` touches) and `general-reviewer` (for general allowlist) after the agent returns.
7. **`## NEVER do these` contents (D6)** — three layers: (i) **Process** (NEVER skip writing/extending tests; NEVER amend a previous commit; NEVER force-push; NEVER pass `--no-verify`). (ii) **Scope** (NEVER edit non-shell source — `*.go`, `*.kt`, `*.swift`, `*.dart`, `*.py`, `*.js`/`*.ts`; NEVER edit `Dockerfile` or CI config without explicit instruction; NEVER edit other agents' definitions; NEVER edit `tasks/<slug>.md` or `features/<slug>.checkpoint.md`). (iii) **Safety** (NEVER use `eval` on user-controlled input; NEVER use `curl ... | bash` install patterns; NEVER strip `set -euo pipefail` to silence an error). Broad-scope agent demands explicit scope guards; safety prohibitions are non-negotiable security guarantees.
8. **Catalogue/index updates (D7)** — three files: (i) `agents/README.md` (new row in catalogue table); (ii) `SYSTEM_PROMPT.md` Agent index table (new row); (iii) `SYSTEM_PROMPT.md` Step 2.2 tech-stack routing bullet (`Bash/shell scripts (and adjacent prose) → shell-developer (agents/shell-developer.md)`). All three needed: catalogue is human-facing; Agent index is workflow-machine-facing; routing list is the actual decision input the coordinator consults. `~/.claude/CLAUDE.md` sync stays a manual post-merge step per project source-of-truth convention — explicitly out of scope.

## Steps

### 1. Author the agent definition file
Create `agents/shell-developer.md` mirroring the existing developer-agent skeleton.

- Frontmatter: only `name: shell-developer` and a single-sentence `description`. The description names the stack (bash/shell scripts) and the dual scope ("...plus the markdown prose that documents the script's contract — skill prompts, READMEs, sibling agent prompts"). NO `model`, NO `tools` fields (matches all five existing developer agents).
- Top-level section order: `## Role` → `## Starting state` → `## Target state` → `## NEVER do these` → `## Testing rules — ALWAYS enforce` → `## Shell hygiene — ALWAYS enforce` → `## Portability — ALWAYS enforce` → `## Prose discipline — ALWAYS enforce` → `## Self-review before return` → `## Slice-aware execution` → `## Allowed actions` → `## Steps` (7 numbered) → `## Stop and ask before`.
- `## Self-review before return` and `## Slice-aware execution` MUST be copied verbatim from one of the existing developer agents (any of the five — they're identical). Do not paraphrase.
- `## NEVER do these` carries the three layers per D6 (process, scope, safety).
- `## Testing rules — ALWAYS enforce` codifies D4: bare bash, `scripts/test-<topic>.sh`, `set -euo pipefail`, real fixtures torn down on `trap`, no mock-heavy patterns. Mention the "default to bare bash; match the project's existing test idiom if different" carve-out.
- `## Shell hygiene` covers strict mode, double-quoting variable expansions, `[[ ]]` over `[ ]` in bash, traps for cleanup, the `set -e` + `||` gotcha, allow-list pattern validation for slugs/paths.
- `## Portability` covers bash vs POSIX `sh`, GNU vs BSD divergence (`timeout`, `sed -i`, `readlink -f`), `command -v` checks before invoking non-default tools, the macOS `coreutils`/`flock` situation already documented in this repo's README.
- `## Prose discipline` covers keeping examples in sync with script behaviour, absolute paths in skill prose, no inventing flags or behaviours not present in the script.
- `## Allowed actions` lists permitted file extensions affirmatively (`*.sh`, `*.md` in `skills/`/`agents/`/repo root, inline help/usage text inside scripts) and named commands (run shell scripts, run `shellcheck` if available, run any `scripts/test-*.sh`).
- `## Steps` (the 7-step internal protocol that mirrors the other agents): read the brief, plan the slice/step list, write tests first, implement minimum code, run tests, refactor, run self-review.

Files: `agents/shell-developer.md` (CREATE).
Acceptance: file exists at the path; frontmatter has only `name` + `description`; all twelve top-level sections appear in the order above; `## Self-review before return` and `## Slice-aware execution` match the existing developer agents byte-for-byte (verifiable by `diff` against extracted sections).

### 2. Catalogue the agent in `agents/README.md`
Append one row to the agent table in `agents/README.md` (matching the existing two-column format).

- Row: `| [shell-developer](shell-developer.md) | <one-sentence description matching the frontmatter> |`.
- Row placement: keep the table in its current ordering convention (alphabetical by agent name if that's the pattern; otherwise append at the end — verify by reading the existing rows before placing).

Files: `agents/README.md` (UPDATE).
Acceptance: a new row is present in the catalogue table; the link target `shell-developer.md` resolves to the file created in Step 1; description sentence matches the agent's frontmatter `description` field.

### 3. Wire the agent into `SYSTEM_PROMPT.md` (routing list + Agent index)
Update `SYSTEM_PROMPT.md` in two places:

- **Step 2.2 tech-stack routing list** (currently 5 bullets). Add a sixth: `Bash/shell scripts (and adjacent prose) → shell-developer (agents/shell-developer.md)`. Place it consistently with surrounding bullets (after `Go (CLI tools, services, libraries) → go-developer` is the natural slot).
- **Agent index table** (three columns: `| Agent | File | Called in |`). Add a row: `| shell-developer | agents/shell-developer.md | Step 2 |`. Place alphabetically among the other developer agents.

Files: `SYSTEM_PROMPT.md` (UPDATE).
Acceptance: routing list contains the new bullet with the exact phrasing above; Agent index table contains the new row; existing tests (`scripts/test-routing-prose.sh`, `scripts/test-skill-indexed.sh`) still exit 0 — no regression in unrelated assertions.

### 4. Final verification
Run the existing prose-grep tests to confirm nothing else regressed, and visually scan the three updated files for table-rendering / formatting issues.

- Run `scripts/test-routing-prose.sh` and `scripts/test-skill-indexed.sh`. Both must exit 0.
- Re-read `agents/shell-developer.md` end-to-end to confirm the verbatim sections (`## Self-review before return`, `## Slice-aware execution`) are exact copies, not paraphrased.
- Re-read `agents/README.md` and `SYSTEM_PROMPT.md` to confirm the new entries are present in the right places and the surrounding tables/lists still render cleanly.

Files: none (verification only).
Acceptance: both test scripts exit 0; manual scan finds no formatting drift in the three updated files; verbatim sections in the new agent file diff-cleanly against the source.

## Deferred (out of scope)
| Item | Why deferred | Related decision |
|------|--------------|------------------|
| Manual sync of new agent into `~/.claude/CLAUDE.md` | Project convention: derived copy refreshed manually post-merge, not as part of the feature touching `SYSTEM_PROMPT.md` | D7 |

## Open Questions
- None unresolved at finalisation.
