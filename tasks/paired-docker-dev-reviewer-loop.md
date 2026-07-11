# paired-docker-dev-reviewer-loop

> **SHELVED — 2026-07-08.** Superseded by the `feature/risk-tiered-workflow` redesign, which removed the in-agent self-review loop this plan targets and replaced multi-round agent review with a fresh-context `reviewer` pass (one confirm re-pass after fixes) plus verification-by-execution (see `skills/implement-feature.md` v3). This plan also references infrastructure deleted in commit `b898c16` (`dispatch-docker-worker.sh`, `docker/entrypoint.sh`, `parallel-docker-dispatch.md`, dispatch test scripts) and would need a ground-up rewrite against the current architecture before any part of it is revived. Kept for its research notes on cross-container session resumption.

Replace the in-agent self-review loop (developer agent invokes `code-reviewer` as a sub-agent) with a paired long-lived setup: the developer and the reviewer run as separate Claude sessions communicating via shared files in the worktree, looping until the reviewer approves. In dockerised parallel dispatch, both sides run as long-lived containers; in non-docker flows, the equivalent pairing is to be defined.

## Context
_Codebase facts and constraints learned during grilling._

- Claude Code CLI supports session resumption: `claude --resume <session-id>` and `claude --continue` both work with `--print`/`-p` mode and restore prior conversation context. (Source: `code.claude.com/docs/en/sessions.md`, `headless.md`.)
- Session IDs are exposed via `--output-format json` (field: `session_id`). A wrapper can extract it with `jq -r '.session_id'` from round 1's output and feed it to round 2 via `--resume`.
- Session state persists at `~/.claude/projects/<project>/<session-id>.jsonl`. Cross-container resumption requires sharing the session storage path — either bind-mount `~/.claude` (forbidden by `parallel-docker-dispatch.md`) or override `CLAUDE_CONFIG_DIR` to a per-feature shared path inside the worktree.
- `--bare` is the recommended flag for scripted/SDK calls (will become the default for `-p` in a future release).
- `parallel-docker-dispatch.md` currently forbids mounting host `~/.claude` and routes auth via `CLAUDE_CODE_OAUTH_TOKEN` env var only. Any cross-container session sharing must respect this.
- Existing dispatch wrapper at `scripts/dispatch-docker-worker.sh` (~147 lines): validates slug, resolves paths, builds image if absent, creates worktree at `../wt-<slug>/` on `feature/<slug>`, `docker run --rm` with `/workspace` bind-mount, forwards `SLUG`/`CLAUDE_CODE_OAUTH_TOKEN`/git identity env vars, wraps in `timeout`, synthesises BLOCKED result on failure or missing result file. Result lands at `${WT_DIR}/.worker-result.json`.
- Existing entrypoint at `docker/entrypoint.sh`: reads `/workspace/tasks/${SLUG}.md`, assembles a multi-part prompt that instructs the worker to execute slices in order and write `/workspace/.worker-result.json`, invokes `claude --print --dangerously-skip-permissions`, validates result schema, falls back to BLOCKED on malformed/missing result.
- Existing test harness: `scripts/test-image.sh` (offline image smoke test), `scripts/test-entrypoint.sh`, `scripts/test-dispatch-single.sh` (integration, requires token), `scripts/test-dispatch-parallel.sh` (cap-of-3 stress test, requires token).
- Canary fixture at `tasks/_canary.md`: minimal task that has the worker `date > CANARY.txt && git commit` then write APPROVE result. Still invokes Claude (so consumes tokens) but tool use is trivial.
- Existing `agents/code-reviewer.md` output is **prose-only** — markdown findings with `**[SEVERITY] file:line**` headers + `Issue:`/`Fix:` lines, ending with a `Verdict: APPROVE / REQUEST CHANGES` line. No JSON schema. Severities: CRITICAL, MAJOR, MINOR, SUGGESTION. REQUEST CHANGES triggered by any CRITICAL or MAJOR.
- Existing developer agents consume reviewer output as prose: read findings as a human would, scan for the `Verdict: APPROVE` token, loop up to 3 cycles. No structural parsing, no JSON contract.
- `security-reviewer` writes a markdown table (SECURITY-ISSUES.md) — also prose-formatted, not JSON. The codebase has zero precedent for structured machine-readable agent output today.
- `install.sh` symlinks ONLY `agents/` and `skills/` (plus `skills/` → `commands/` in global mode). It does NOT symlink `scripts/`, `docker/`, or `tasks/`. New files under those directories are exposed via the clone-path convention (`.claude/claude-prompt/scripts/...` project install, `~/.claude/claude-prompt/scripts/...` global install) and inherit visibility automatically. Adding new wrappers, docker fixtures, or task fixtures requires no `install.sh` change.

## Decisions
_Resolved through grilling. Each entry references the question that produced it._

1. **Scope: full replace** — The paired-reviewer pattern replaces the in-agent self-review loop in every flow (serial, `parallel-dispatch`, `parallel-docker-dispatch`). Developer agents will no longer invoke `code-reviewer` as a sub-agent; review happens as a separate paired session in all modes. _(Q1)_

2. **Continuity primitive: `claude --resume <session-id>`** — Both flows use Claude Code's documented session-resumption mechanism to give the dev side and reviewer side memory across rounds. Session IDs are captured via `--output-format json` from round 1 and threaded into subsequent invocations via `--resume <id>`. In docker flow, both containers share session storage via `CLAUDE_CONFIG_DIR=/workspace/.claude-sessions` (a path inside the per-feature worktree); the host's `~/.claude` is never mounted, preserving the existing `parallel-docker-dispatch` rule. In non-docker flow, the host's normal session storage is used. _(Q2)_

3. **Container lifecycle: per-round restart with persistent session** — Each loop round spins up a fresh `--rm` container that resumes the prior session via `--resume <id>`. The loop lives in the dispatch wrapper on the host, not in an in-container shell loop. Continuity comes from the JSONL files in the shared `CLAUDE_CONFIG_DIR` volume, not from container persistence. Matches existing `parallel-docker-dispatch` doctrine (`--rm` one-shot containers, worktree is the only persistent state); makes crash recovery free (failed round = non-zero exit, wrapper retries with session intact); preserves the user-facing "memory across rounds" property identically to a long-lived container. _(Q3)_

4. **Iteration cap: ≤3 rounds** — Parity with the existing in-agent self-review loop. The cap applies to "rounds where the reviewer returns CHANGES_REQUESTED and the dev runs another pass" — round 1 is dev's first pass plus reviewer's first review. Cap is fixed in the dispatch wrapper, not configurable per dispatch. Revise empirically if real-world loops hit the cap with non-trivial frequency. _(Q4)_

5. **Cap-reached behaviour: BLOCKED to coordinator** — Hitting round 3 without an APPROVE writes `.worker-result.json` with `status: BLOCKED`, populating `blockers` from the reviewer's unresolved findings. The existing per-feature gate (Step 5 in `parallel-docker-dispatch.md`, Step 6 in serial flow) surfaces this to the user, who decides whether to ship anyway (manual override), dispatch a manual fix pass, or abandon. New fields added to the result schema: `review_rounds: N` and `final_review_severity: [SEVERITIES]`, additive and backwards-compatible. NEVER auto-APPROVE at the cap; never silently lie about review status. _(Q5)_

6. **Severity threshold for APPROVE: CRITICAL+MAJOR** — Parity with the current convention used by `code-reviewer.md` and every developer-agent self-review prose. APPROVE means no CRITICAL and no MAJOR findings remain; MINOR and SUGGESTION are surfaced once at the end and do not block. Severity-policy changes are explicitly out of scope for this feature; they are a separate, future decision. _(Q6)_

7. **Container topology: one image, role via env var** — Extend `claude-worker:test` with an entrypoint that branches on `WORKER_ROLE=dev|reviewer`. Both roles share the runtime (Claude CLI, git, jq, OAuth token env, `/workspace` mount, `CLAUDE_CONFIG_DIR=/workspace/.claude-sessions`); only the user prompt and result-file path differ. Avoids image-pair drift (single Dockerfile, single CI build, single canary), keeps the existing `parallel-docker-dispatch` doctrine of "one image, one wrapper, one canary" intact, and the new branch is small enough to cover with `scripts/test-entrypoint.sh` parameterised by `WORKER_ROLE`. _(Q7)_

8. **Wrapper structure: replace `dispatch-docker-worker.sh` with a new `dispatch-docker-pair.sh`** — Write a new wrapper from scratch that handles worktree setup once, then loops dev/reviewer rounds in-process (Decision 3). Delete the old single-shot wrapper. Update all call sites: `parallel-docker-dispatch.md` (both project-install and global-install path spellings) and the four `scripts/test-dispatch-*.sh` scripts. **No `install.sh` change needed** — `install.sh` only symlinks `agents/` and `skills/` (plus `skills/` → `commands/` globally); `scripts/` and `docker/` are exposed via the clone-path convention (`.claude/claude-prompt/scripts/...` project, `~/.claude/claude-prompt/scripts/...` global), so new wrapper files inherit visibility automatically. Per Decision 1, the old wrapper has no remaining consumer — keeping it would be dead code. _(Q8)_

9. **Non-docker flow: new `scripts/dispatch-host-pair.sh`** — Mirrors `dispatch-docker-pair.sh` shape minus the `docker run` layer. Coordinator invokes the script once per feature (in serial flow and host-worktree `parallel-dispatch`); the script runs the per-round loop with `claude --print --output-format json --resume <id>`, writes per-round result files, aggregates into final `.worker-result.json`. Common loop logic (round counter, session-id threading, cap enforcement, BLOCKED escalation) lives in `scripts/lib/pair-loop.sh` shared by both wrappers. Loop logic does NOT live in coordinator skill prose. _(Q9)_

10. **Findings schema: JSON file written by the reviewer** — Modify `agents/code-reviewer.md` to instruct the reviewer to write `/workspace/.review-result-<round>.json` with this schema:
    ```json
    {
      "status": "APPROVE" | "CHANGES_REQUESTED",
      "round": <integer>,
      "findings": [
        { "severity": "CRITICAL|MAJOR|MINOR|SUGGESTION",
          "file": "path/to/file.ext",
          "line": 42,
          "issue": "<one-sentence>",
          "fix": "<one-sentence>" }
      ],
      "summary": "<one-paragraph overview>"
    }
    ```
    The `session_id` is captured by the wrapper from `claude --output-format json` stdout, not written by the reviewer. Wrapper validates the JSON with `jq -e`; malformed file → BLOCKED with synthesised entry. Prose narration remains in the session transcript JSONL but is not the contract. Per Decision 1, the wrapper is the only consumer of `code-reviewer.md` output, so the contract change is contained. _(Q10)_

11. **Concurrency cap: stays at 3** — `parallel-docker-dispatch.md` cap rationale (gate cognitive load, not host CPU/API resources) is unchanged by the paired pattern. Per Decision 3, peak concurrent containers per feature is 1 (dev OR reviewer for the current round, not both). 3 concurrent features still = 3 concurrent containers and at most 3 simultaneous gates. Per-feature wall-clock and token cost roughly double, but those are per-feature costs, not concurrency costs. Cap-change is a separate, future decision requiring its own evidence. _(Q11)_

12. **`parallel-docker-dispatch.md` Step 6: reframed as cross-feature interaction check** — Per-feature paired review already covers per-file code quality, so Step 6's role becomes specifically catching conflicts that span feature boundaries (rename-vs-caller, schema-vs-reader, type drift, duplicate definitions, incompatible config edits). Update Step 6 prose to make this explicit: the reviewer's prompt instructs it to ONLY flag findings that span feature boundaries; per-file nits already resolved in per-feature review are explicitly out of scope. Step remains advisory (does not block any merge). `agents/code-reviewer.md` gains a "cross-feature mode" triggered by an env var or prompt flag from the wrapper. _(Q12)_

13. **Developer agent prompt changes: strip-only, no additions** — Remove the `## Self-review before return` section from each of the six developer agents (`go-developer.md`, `shell-developer.md`, `kotlin-backend-developer.md`, `android-developer.md`, `ios-developer.md`, `flutter-developer.md`). Add nothing new to handle round-N+1. The wrapper-injected user prompt for each round (e.g. "Round 2: address these CRITICAL+MAJOR findings, commit, exit. MINOR/SUGGESTION are out of scope for this round.") carries the round-specific instructions in one place rather than six. Verify surrounding prose still flows after each strip. _(Q13)_

14. **Testing: stub-reviewer mode for multi-round paths + unit tests on `pair-loop.sh` library** — The reviewer entrypoint branch gains a `WORKER_REVIEWER_STUB=<fixture-path>` env var that, when set, skips the `claude --print` call and writes a pre-baked per-round JSON fixture to `/workspace/.review-result-<round>.json`. Production never sets the env var; CI tests set it to deterministically exercise rounds 1 → 2 → 3 → BLOCKED paths without burning tokens or relying on Claude judgment. Unit tests on `scripts/lib/pair-loop.sh` cover individual functions (round counter, cap detection, JSON aggregation). Existing `test-dispatch-single.sh`-style integration test covers the round-1-APPROVE happy path with real Claude. Adversarial canaries (option C) explicitly rejected for being non-deterministic. _(Q14)_

15. **Failure handling: fail-fast → BLOCKED, no retry** — Any per-round failure (Claude API error, container timeout, `--resume` failure, malformed result file, missing result file) writes a synthesised BLOCKED `.worker-result.json` with a specific diagnostic in `blockers`, exits non-zero. No retry inside the wrapper. Mirrors existing `dispatch-docker-worker.sh` failure pattern verbatim. The `CLAUDE_CONFIG_DIR=/workspace/.claude-sessions` volume persists across wrapper invocations, so user re-dispatch resumes from the failed round naturally — re-dispatch IS the retry mechanism, not in-wrapper retry. Specific BLOCKED diagnostics defined in the failure-mode table for each of the five mode types. _(Q15)_

16. **Atomic flip slice kept bundled, no feature flag** — The cutover from in-agent self-review to paired-loop review is a single coordinated commit (Slice 13): strip 6 developer agents, update `parallel-docker-dispatch.md` Step 5 wrapper path and Step 6 reframe, update `SYSTEM_PROMPT.md` Step 2 prose, delete `dispatch-docker-worker.sh`, update `test-dispatch-single.sh` and `test-dispatch-parallel.sh` to call the new wrapper. Feature-flagging the new behaviour explicitly rejected per repo convention (CLAUDE.md: "Don't use feature flags or backwards-compatibility shims when you can just change the code"). _(Q-slice-1)_

17. **Library split into four single-function slices** — `scripts/lib/pair-loop.sh` is built across Slices 1-4, one TDD cycle per function (`next_round`, `at_cap`, `extract_session_id`, `aggregate_results`). Strict adherence to "one Red→Green→Refactor cycle per slice" rule from `skills/grill-plan.md`, even though each function is small. _(Q-slice-2)_

18. **Reviewer-real ships before dev-real** — Slice 7 (entrypoint reviewer real Claude path) precedes Slice 8 (entrypoint dev role). Reasoning: reviewer is the new high-risk role; dev role is a small refactor of existing round-1 entrypoint behaviour. Once reviewer-real works, the dev role can be tested against it without needing a stub-dev mode. _(Q-slice-3)_

## Slices

### Slice 1 — `scripts/lib/pair-loop.sh`: `next_round` function
**Outcome:** A round-counter function exists and increments correctly.
**Test (Red):** `scripts/test-pair-loop-unit.sh` asserts `next_round 1 == 2`, `next_round 2 == 3`, `next_round 0 == 1`. File: `scripts/test-pair-loop-unit.sh`.
**Implementation (Green):** Single shell function in `scripts/lib/pair-loop.sh` returning argument + 1.
**Refactor:** None expected.
**Acceptance:** `bash scripts/test-pair-loop-unit.sh` passes offline.

### Slice 2 — `scripts/lib/pair-loop.sh`: `at_cap` function
**Outcome:** Cap detection function returns true at round 3, false otherwise.
**Test (Red):** Extend `test-pair-loop-unit.sh` to assert `at_cap 1 == false`, `at_cap 2 == false`, `at_cap 3 == true`.
**Implementation (Green):** Add `at_cap` function comparing round to hard-coded cap=3.
**Refactor:** Extract cap to a top-of-file constant `MAX_REVIEW_ROUNDS=3`.
**Acceptance:** Unit test passes; cap is one named constant in the library.

### Slice 3 — `scripts/lib/pair-loop.sh`: `extract_session_id` function
**Outcome:** Function extracts session ID from a `claude --output-format json` stdout payload.
**Test (Red):** Extend unit test with a fixture string containing `{"session_id": "abc-123", ...}` and assert `extract_session_id "$fixture" == "abc-123"`. Also assert empty string return on missing field.
**Implementation (Green):** Function uses `jq -r '.session_id // empty'`.
**Refactor:** None expected.
**Acceptance:** Unit test passes; function tolerates missing field without erroring.

### Slice 4 — `scripts/lib/pair-loop.sh`: `aggregate_results` function
**Outcome:** Function combines per-round JSON files into a single final `.worker-result.json` matching the schema in Decision 5.
**Test (Red):** Extend unit test with a fixtures directory containing `.review-result-1.json` (CHANGES_REQUESTED), `.review-result-2.json` (APPROVE), and assert `aggregate_results <dir>` produces JSON with `status: APPROVE`, `review_rounds: 2`, `final_review_severity: []`.
**Implementation (Green):** Function reads all `.review-result-*.json`, takes status from the last one, populates `review_rounds` and `final_review_severity` from the last file's findings.
**Refactor:** None expected.
**Acceptance:** Unit test covers the APPROVE case, the BLOCKED case (3 rounds CHANGES_REQUESTED), and the malformed-file case (synthesises BLOCKED).

### Slice 5 — `agents/code-reviewer.md`: JSON output schema instruction
**Outcome:** The reviewer agent prompt instructs the reviewer to write `/workspace/.review-result-<round>.json` matching the Decision 10 schema, and to read `WORKER_ROUND` env var to determine the round number.
**Test (Red):** Manual gate via `prompt-definition-reviewer` agent. The reviewer prompt's existing `## Output format` section gets a new directive; verify cohesion with surrounding prose.
**Implementation (Green):** Add an `## Output format (paired-loop mode)` section to `agents/code-reviewer.md` with the JSON schema. Also add cross-feature mode trigger (Decision 12).
**Refactor:** Strip any prose that conflicts with the new directive (e.g., "output prose to stdout" lines if present).
**Acceptance:** `prompt-definition-reviewer` returns APPROVE on the modified file.

### Slice 6 — `docker/entrypoint.sh`: reviewer branch with stub-reviewer mode
**Outcome:** The entrypoint branches on `WORKER_ROLE=dev|reviewer`. In reviewer role with `WORKER_REVIEWER_STUB=<fixture-path>` set, the entrypoint copies the fixture's per-round element to `.review-result-<round>.json` and exits 0 without invoking Claude.
**Test (Red):** New `scripts/test-entrypoint-reviewer-stub.sh` (offline) builds the image, runs container with `WORKER_ROLE=reviewer WORKER_REVIEWER_STUB=/workspace/fixtures/stub-changes-then-approve.json WORKER_ROUND=1`, asserts `.review-result-1.json` matches fixture[0]. File: `scripts/test-entrypoint-reviewer-stub.sh`.
**Implementation (Green):** Top-of-file branch on `WORKER_ROLE` in `docker/entrypoint.sh`. Reviewer branch checks `WORKER_REVIEWER_STUB`; if set, `jq` extracts the indexed round from fixture and writes the result file.
**Refactor:** Extract the role-branching to a small dispatch function for clarity.
**Acceptance:** Offline test passes; image builds without errors; reviewer stub mode never calls Claude.

### Slice 7 — `docker/entrypoint.sh`: reviewer branch real Claude path
**Outcome:** With `WORKER_ROLE=reviewer` and no stub env var, the entrypoint invokes `claude --print --output-format json --append-system-prompt <code-reviewer.md>` with a diff-context user prompt; the reviewer writes the JSON result file as instructed by Slice 5.
**Test (Red):** `scripts/test-entrypoint-reviewer-integration.sh` (token-required): seed a minimal worktree with a known diff, run the container, validate that `.review-result-1.json` exists and matches the schema.
**Implementation (Green):** Reviewer non-stub path computes diff via `git diff <base>...HEAD`, builds the user prompt from the diff, invokes `claude --print --bare --output-format json` with `--append-system-prompt` pointing at the bundled `code-reviewer.md`, captures session_id from stdout to a known path.
**Refactor:** None expected.
**Acceptance:** Integration test produces a valid review-result JSON with status APPROVE or CHANGES_REQUESTED.

### Slice 8 — `docker/entrypoint.sh`: dev branch round-1 + round-N+1 input handling
**Outcome:** Dev role reads `WORKER_ROUND`. On round 1, builds prompt from `tasks/${SLUG}.md`. On round N+1, reads `WORKER_FINDINGS_PATH` (path to `.review-result-<N>.json`) and builds a "address these findings" prompt. Dev invokes Claude with `--resume <id>` if `WORKER_SESSION_ID` is set.
**Test (Red):** `scripts/test-entrypoint-dev.sh` covering both round-1 (no findings, reads task plan) and round-2 (findings JSON injected) cases. Round 1 offline-only via stub; round 2 integration with token.
**Implementation (Green):** Dev branch in entrypoint reads round + findings path, constructs appropriate prompt, invokes Claude. Round-N+1 includes session resume.
**Refactor:** None expected.
**Acceptance:** Both round flows produce a valid `.dev-result-<round>.json` and a commit on the worktree branch.

### Slice 9 — `scripts/dispatch-docker-pair.sh`: happy-path round-1 APPROVE
**Outcome:** New wrapper does worktree setup once, then invokes one dev/reviewer cycle and produces a final `.worker-result.json` with status APPROVE.
**Test (Red):** `scripts/test-dispatch-pair-round1.sh` (offline, uses stub reviewer fixture that approves on round 1): runs the wrapper end-to-end, validates final result.
**Implementation (Green):** Wrapper imports `pair-loop.sh`, creates worktree, sets up `CLAUDE_CONFIG_DIR=/workspace/.claude-sessions`, runs `WORKER_ROLE=dev` container then `WORKER_ROLE=reviewer` container with stub fixture, calls `aggregate_results`.
**Refactor:** Extract worktree setup into a helper for reuse by the host wrapper later.
**Acceptance:** Round-1 cycle produces APPROVE result file in the worktree; container is `--rm`-cleaned up.

### Slice 10 — `scripts/dispatch-docker-pair.sh`: multi-round APPROVE
**Outcome:** Wrapper loops dev → reviewer → dev → reviewer with `--resume` threading; APPROVES at round 2.
**Test (Red):** `scripts/test-dispatch-pair-multi.sh` (offline, stub fixture: round-1 CHANGES_REQUESTED, round-2 APPROVE): asserts final result has `review_rounds: 2`, `status: APPROVE`.
**Implementation (Green):** Add the round loop with session-id capture (Slice 3 function) and findings-path injection into round-N+1 dev container.
**Refactor:** None expected.
**Acceptance:** Round-2 path produces APPROVE; session resumption verified by inspecting `.claude-sessions/` JSONL files.

### Slice 11 — `scripts/dispatch-docker-pair.sh`: BLOCKED at cap and failure-mode handling
**Outcome:** Wrapper produces correctly-shaped BLOCKED results for: cap-reached (3 rounds CHANGES_REQUESTED), malformed result file, missing result file, container timeout, `--resume` failure, Claude API error.
**Test (Red):** `scripts/test-dispatch-pair-blocked.sh` (offline, stub fixtures for each failure mode): asserts each failure case produces `.worker-result.json` with `status: BLOCKED` and the specific blocker text from the Decision 15 failure-mode table.
**Implementation (Green):** Add per-failure BLOCKED escalation paths to the wrapper. Hook into existing `dispatch-docker-worker.sh`-style timeout-and-synthesise pattern.
**Refactor:** None expected.
**Acceptance:** All 6 failure modes (cap + 5 from the table) produce specific BLOCKED diagnostics matching the Decision 15 schema.

### Slice 12 — `scripts/dispatch-host-pair.sh`: non-docker mirror
**Outcome:** Host-side wrapper produces the same result shape as the docker wrapper using `claude --print --resume` directly (no `docker run`). Shares `pair-loop.sh` library with the docker wrapper.
**Test (Red):** `scripts/test-dispatch-host-pair.sh` (token-required): host wrapper produces valid `.worker-result.json` for round-1 APPROVE on a small task.
**Implementation (Green):** Mirror the docker wrapper's loop without container invocations; use host's normal session storage; share helper functions via `scripts/lib/pair-loop.sh`.
**Refactor:** Extract any duplicated logic between the docker and host wrappers into shared library functions.
**Acceptance:** Host integration test produces the same result shape as docker; library functions are reused, not re-implemented.

### Slice 13 — ATOMIC FLIP: cutover from in-agent loop to paired-loop
**Outcome:** Old in-agent self-review loop is removed and the new paired-loop infrastructure becomes the only review mechanism. Single coordinated commit prevents any window where review is doubled or missing.
**Test (Red):** All existing integration tests (`test-dispatch-single.sh`, `test-dispatch-parallel.sh`) updated to call the new wrapper. `prompt-definition-reviewer` and `general-reviewer` pass on prose changes. `grep -r dispatch-docker-worker` returns no hits.
**Implementation (Green):** In a single commit: (a) strip `## Self-review before return` from `agents/{go,shell,kotlin-backend,android,ios,flutter}-developer.md` (6 files); (b) update `skills/parallel-docker-dispatch.md` Step 5 wrapper paths and Step 6 cross-feature reframe; (c) update `SYSTEM_PROMPT.md` Step 2 prose to reflect that developer agents no longer self-review (and propagate the same change to `~/.claude/CLAUDE.md` per repo convention); (d) delete `scripts/dispatch-docker-worker.sh`; (e) update `scripts/test-dispatch-single.sh` and `scripts/test-dispatch-parallel.sh` to invoke `dispatch-docker-pair.sh`.
**Refactor:** None expected — this slice is the cutover, not a redesign.
**Acceptance:** All tests green; no dangling references to old wrapper or in-agent self-review prose; both `prompt-definition-reviewer` and `general-reviewer` APPROVE.

### Slice 14 — `skills/parallel-dispatch.md`: integrate `dispatch-host-pair.sh`
**Outcome:** Host-worktree parallel dispatch invokes the new host-pair wrapper instead of the legacy in-agent loop.
**Test (Red):** `general-reviewer` APPROVE on the modified skill prose.
**Implementation (Green):** Update `parallel-dispatch.md` to point at `dispatch-host-pair.sh`; update Step 6 (combined-diff) to match the cross-feature reframe from Decision 12.
**Refactor:** None expected.
**Acceptance:** `general-reviewer` returns APPROVE.

## Deferred (out of scope)
_Items resolved as "not this feature" during grilling. Consolidated to `/TODO.md` at termination._

| Item | Why deferred | Related decision |
|------|--------------|------------------|
| Severity-policy revision (e.g. block on MINOR, demote MAJOR to non-blocking) | Out of scope: paired memory doesn't change *what should* block a PR. Separate, future decision requiring its own evidence. | Decision 6 |
| Concurrency cap change (raise above 3 or lower below 3) | Out of scope: cap rationale (gate cognitive load) is unchanged by paired pattern. Separate, future decision needing user-testing data. | Decision 11 |
| Long-lived "watcher" containers with in-container shell loops | Out of scope: per-round restart with persistent session JSONL gives identical user-facing memory-across-rounds property at lower complexity. | Decision 3 |
| Pre-computed diff injection into reviewer prompt | Out of scope: reviewer container has full git access in worktree and can compute its own diff with tool use. | Implicit in Slice 7 |
| Adversarial canary that deterministically forces round-2 by triggering a known reviewer flag | Out of scope: rejected as flaky in CI; stub-reviewer mode (Decision 14) covers multi-round paths deterministically. | Decision 14 |
| Two separate Docker images (`claude-worker-dev`, `claude-worker-reviewer`) | Out of scope: image-pair drift cost outweighs separation benefit; one-image with role-via-env-var is simpler. | Decision 7 |
| Coordinator-orchestrated loop in skill prose (loop logic in markdown rather than shell) | Out of scope: shell scripts have testable contracts; skill prose does not. | Decision 9 |
| Mid-round retry-once-then-BLOCKED for transient failures | Out of scope: retry semantics ambiguous when Claude has partially committed; user re-dispatch is the natural retry mechanism. | Decision 15 |
| Feature flag (`WORKER_PAIR_LOOP_ENABLED`) for incremental rollout | Out of scope: repo convention rejects feature flags; atomic-flip slice is the cutover. | Decision 16 |

## Open Questions
- **Architecture impact review.** This feature changes a load-bearing workflow surface (review path for all flows). Per `~/.claude/CLAUDE.md` Step 1, run `architecture` agent before implementation begins to confirm there are no architectural concerns the grilling missed.
- **`SYSTEM_PROMPT.md` and global `~/.claude/CLAUDE.md` prose updates.** Slice 13 includes this in the atomic flip, but the workflow's "Skill index" and "Agent index" tables and the "code → `code-reviewer` (via the developer agent's self-review loop in serial mode)" prose specifically need careful prose surgery — verify wording with `general-reviewer` before merge.
- **`install.sh` path-fallback hygiene.** `parallel-docker-dispatch.md` currently spells out both `.claude/claude-prompt/scripts/dispatch-docker-worker.sh` (project) and `~/.claude/claude-prompt/scripts/dispatch-docker-worker.sh` (global) for the wrapper path. Slice 13 must update both spellings to `dispatch-docker-pair.sh`. Confirm during implementation that no other consumer-repo references exist.
- **Stub-reviewer fixture format finalisation.** Decision 14 sketches an array-indexed-by-round JSON fixture, but the exact filename convention (`stub-changes-then-approve.json` vs `stub-fixture-2round-approve.json`) and directory location (`docker/fixtures/` vs `scripts/fixtures/`) are not pinned. Resolve in Slice 6.
- **Reviewer's diff computation strategy.** Slice 7 says reviewer uses `git diff <base>...HEAD` via tool use, but the exact base-branch detection (`main` default; check for `master` fallback?) is implementation detail to confirm during Slice 7.
