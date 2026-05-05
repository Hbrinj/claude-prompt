# location-independent-dispatch-wrapper

Make `scripts/dispatch-docker-worker.sh` resolve the consumer repo root from the caller's CWD instead of inferring it from `$(dirname "$0")/..`, so the dockerised parallel-dispatch flow works after `install.sh` has placed the clone under `.claude/claude-prompt/`. Skill prose in `skills/parallel-docker-dispatch.md` and the README are updated to invoke the wrapper via its absolute clone path with a project-then-global fallback.

## Context
_Codebase facts and constraints learned during grilling._
- `scripts/dispatch-docker-worker.sh:30` computes `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. That value is then used at four sites: `tasks/${SLUG}.md` lookup (line 38), docker build context `$REPO_ROOT/docker/` (line 45), worktree parent `$REPO_ROOT/..` (line 48), and the `.git` bind-mount source/target (line 83).
- `skills/parallel-docker-dispatch.md` invokes the wrapper via the relative path `scripts/dispatch-docker-worker.sh <slug>` and pre-checks `[ -x scripts/dispatch-docker-worker.sh ]` (lines ~71, ~94, ~158). Both assume the script lives at the consumer repo root.
- `install.sh` clones the repo to `~/.claude/claude-prompt/` (global) or `<project>/.claude/claude-prompt/` (project) and only symlinks `agents/`, `skills/`, and (global) `commands/` into `.claude/`. Neither `scripts/` nor `docker/` is exposed to the consumer repo.
- Existing test scripts: `scripts/test-dispatch-single.sh:28` and `scripts/test-dispatch-parallel.sh:68` both `cd "$REPO_ROOT"` (the clone) before invoking the wrapper, so they still operate against the from-clone case under the new contract and will keep passing without modification. `scripts/test-image.sh`, `scripts/test-entrypoint.sh`, `scripts/test-routing-prose.sh`, `scripts/test-skill-indexed.sh` do not invoke the wrapper.
- No existing test asserts the wrapper's behaviour when invoked from a consumer repo outside the clone, nor any error path.

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **Mode** — software work; output uses `## Slices` with strict one-cycle TDD per slice.
2. **Repo-root source (D1)** — wrapper trusts caller's CWD. No new flag/env var/positional arg. Coordinator `Bash` tool calls already run from the consumer repo root; the skill already implies it.
3. **Docker build context (D2)** — derive `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` and build from `$SCRIPT_DIR/../docker/`. Keeps build-on-demand alive (first-run UX); the script↔Dockerfile pairing is invariant within the clone. Portable, no `readlink -f` required.
4. **Skill prose path resolution (D3)** — `skills/parallel-docker-dispatch.md` documents a fallback chain: prefer `.claude/claude-prompt/scripts/dispatch-docker-worker.sh` (project install), fall back to `~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh` (global install). Precheck and dispatch use whichever exists. Covers every `install.sh` outcome with no extra setup.
5. **Repo-root spelling (D4)** — implement D1 as `REPO_ROOT="$(git rev-parse --show-toplevel)"`. One call validates CWD is in a git repo, normalises to the top, and lets the user invoke from any subdirectory. Existing tests already `cd` to the top, so behaviour for them is unchanged.
6. **Test surface (D5)** — add a new `scripts/test-dispatch-from-consumer.sh` covering the consumer-repo case. Existing `test-dispatch-single.sh` / `test-dispatch-parallel.sh` stay as-is. The new test creates a temp git repo with `tasks/<slug>.md` and invokes the wrapper via absolute path from that repo, asserting the wrapper resolves REPO_ROOT to the temp repo. Uses a slug whose `.md` exists ONLY in the temp consumer (not in the clone) so the assertion is unambiguous.
7. **Test short-circuit (D6)** — add a `--dry-run` flag to the wrapper. After path resolution, prints `REPO_ROOT=…`, `SCRIPT_DIR=…`, `BUILD_CONTEXT=…`, `WT_DIR=…`, `BRANCH=…` on stable lines, then exits 0 without touching docker. Lets the new test assert path resolution with one positive check and no docker daemon dependency. Doubles as a user-facing sanity probe.
8. **Slicing (D7)** — four strict-TDD slices in this order: (1) `--dry-run` flag with current resolution, (2) `REPO_ROOT` from `git rev-parse --show-toplevel`, (3) `SCRIPT_DIR` for build context, (4) skill prose + README absolute-path fallback chain. Slice 1 lands the test surface first so slices 2–3 just extend it. Slice 4 is prose-only with grep-based assertions.
9. **README update (D8)** — folded into slice 4. Update the "Dispatch scripts — host requirements" section so the invocation example matches the skill: `~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh` (global) or `.claude/claude-prompt/scripts/dispatch-docker-worker.sh` (project), invoked from inside any consumer git repo. Slice 4's prose-grep test gains one assertion against `README.md`.

## Slices

### Slice 1 — `--dry-run` flag prints resolved paths and exits 0
**Outcome:** A user (or a test) can invoke `bash scripts/dispatch-docker-worker.sh --dry-run <slug>` from inside any repo and see five resolved-path lines without docker being touched.
**Test (Red):** New `scripts/test-dispatch-from-consumer.sh`. Step 1 of the fixture: from the clone root, run `bash scripts/dispatch-docker-worker.sh --dry-run _canary`; assert exit 0 and stdout contains `REPO_ROOT=<absolute clone path>` plus stable lines for `SCRIPT_DIR=`, `BUILD_CONTEXT=`, `WT_DIR=`, `BRANCH=`. Today no flag exists, so the wrapper treats `--dry-run` as the slug, fails slug-pattern validation at line 25, and exits 2 — the test fails. File: `scripts/test-dispatch-from-consumer.sh`.
**Implementation (Green):** Add a `DRY_RUN=false` flag and a single argv pass that strips `--dry-run` while leaving `<slug> [base-branch]` semantics intact. After the existing REPO_ROOT and slug-pattern checks, and after computing `SCRIPT_DIR`, `BUILD_CONTEXT="$SCRIPT_DIR/../docker/"` (introduced as a named variable now to keep slice 3 small), `WT_DIR`, and `BRANCH`, branch on `$DRY_RUN`: print the five `KEY=value` lines on stdout and `exit 0` before the `CLAUDE_CODE_OAUTH_TOKEN` check and any docker call. File: `scripts/dispatch-docker-worker.sh`.
**Refactor:** None expected. Capture `BUILD_CONTEXT` as a variable here even though slice 3 changes its source — keeps the dry-run output schema stable across later slices.
**Acceptance:** `bash scripts/dispatch-docker-worker.sh --dry-run _canary` from the clone root exits 0 and prints all five `KEY=value` lines; the new test passes; `scripts/test-dispatch-single.sh` and `scripts/test-dispatch-parallel.sh` continue to pass.

### Slice 2 — `REPO_ROOT` from `git rev-parse --show-toplevel`
**Outcome:** When invoked via absolute path from inside a consumer repo, the wrapper finds the consumer's `tasks/`, `.git`, and worktree parent — not the clone's.
**Test (Red):** Extend `scripts/test-dispatch-from-consumer.sh` to create a temp git repo at `$(mktemp -d)/consumer`, run `git init && git commit --allow-empty -m init`, write `tasks/_consumer_only.md` (a body adapted from `_canary.md`), `cd` into it, then run `bash <absolute path to wrapper> --dry-run _consumer_only`. Assert stdout contains `REPO_ROOT=<temp consumer path>`. Today the wrapper resolves REPO_ROOT from `$0`, so it prints the clone path — the assertion fails. File: `scripts/test-dispatch-from-consumer.sh`.
**Implementation (Green):** Replace `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` with `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Keep the existing `cd "$REPO_ROOT"` line. Let `git rev-parse`'s native error (`fatal: not a git repository`) flow when CWD is not in a repo. File: `scripts/dispatch-docker-worker.sh`.
**Refactor:** None expected.
**Acceptance:** From a temp consumer repo invoked via absolute path, `--dry-run _consumer_only` exits 0 and prints `REPO_ROOT=<temp consumer path>`; the wrapper invoked from outside any git repo exits non-zero with git's `fatal: not a git repository` message; `scripts/test-dispatch-single.sh` and `scripts/test-dispatch-parallel.sh` still pass (they `cd` to the clone, so `git rev-parse` returns the clone path — equivalent to the old behaviour).

### Slice 3 — `SCRIPT_DIR` decouples build context from `REPO_ROOT`
**Outcome:** When invoked from a consumer repo, the docker build context resolves to the clone's `docker/`, not `<consumer>/docker/`.
**Test (Red):** Extend `scripts/test-dispatch-from-consumer.sh` to also assert `BUILD_CONTEXT=<absolute clone path>/docker/` in the consumer-invocation dry-run output. Today, `BUILD_CONTEXT` is derived from `REPO_ROOT` (which after slice 2 is the consumer), so the dry-run prints `BUILD_CONTEXT=<temp consumer path>/docker/` — the assertion fails. File: `scripts/test-dispatch-from-consumer.sh`.
**Implementation (Green):** Add `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` near the top of the script (just after argv parsing). Change `BUILD_CONTEXT` from `"$REPO_ROOT/docker/"` to `"$SCRIPT_DIR/../docker/"` and use `BUILD_CONTEXT` in the `docker build` call (replacing the inline `"$REPO_ROOT/docker/"` at the existing build site). Dry-run output already references `BUILD_CONTEXT` from slice 1, so no schema change. File: `scripts/dispatch-docker-worker.sh`.
**Refactor:** None expected.
**Acceptance:** From a temp consumer repo, `--dry-run` prints `BUILD_CONTEXT` pointing inside the clone; from inside the clone, `BUILD_CONTEXT` still points at `<clone>/docker/`; an end-to-end `scripts/test-dispatch-single.sh` run still builds the image successfully.

### Slice 4 — Skill prose + README absolute-path fallback chain
**Outcome:** `skills/parallel-docker-dispatch.md` and `README.md` describe the canonical invocation as the absolute clone path with project-install fallback to global; the obsolete relative-path precheck is removed.
**Test (Red):** New `scripts/test-prose-absolute-path.sh` (sibling of `scripts/test-routing-prose.sh`, same `grep`-based shape). Assert: (1) `skills/parallel-docker-dispatch.md` contains the literal substrings `.claude/claude-prompt/scripts/dispatch-docker-worker.sh` AND `~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh`; (2) `skills/parallel-docker-dispatch.md` does NOT contain the obsolete substring `[ -x scripts/dispatch-docker-worker.sh ]`; (3) `README.md` contains the substring `~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh`. Today none of (1)–(3) hold — the test fails on assertion 1. File: `scripts/test-prose-absolute-path.sh`.
**Implementation (Green):**
- In `skills/parallel-docker-dispatch.md`: replace the `[ -x scripts/dispatch-docker-worker.sh ]` precheck with a fallback-chain check (try project path first, fall back to global, store the resolved path for use in dispatch). Update the dispatch step's `command:` example and the `Allowed actions` reference to use the same resolved path. Adjust surrounding prose so the "lives at the consumer repo root" assumption is gone.
- In `README.md` "Dispatch scripts — host requirements" section: add a one-paragraph note describing the absolute invocation pattern with both install paths, and that the wrapper is invoked from inside any consumer git repo.
Files: `skills/parallel-docker-dispatch.md`, `README.md`.
**Refactor:** None expected.
**Acceptance:** `scripts/test-prose-absolute-path.sh` exits 0; `scripts/test-routing-prose.sh` and `scripts/test-skill-indexed.sh` still pass; manual read of the skill prose and README shows the new invocation idiom and no remaining references to the obsolete relative path.

## Deferred (out of scope)
| Item | Why deferred | Related decision |
|------|--------------|------------------|

## Open Questions
- None unresolved at finalisation.
