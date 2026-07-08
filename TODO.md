# TODO

Items deferred as out-of-scope from feature planning. Triage manually.

Statuses: `Open` (still valid), `Resolved YYYY-MM-DD` (delivered, see note), `Obsolete YYYY-MM-DD` (references deleted infrastructure or a superseded design — kept for the record).

## From feature/add-go-developer
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Fix `lint` → `test` wording in `agents/go-developer.md:61` (line reads *"the lint step also runs `go test -race ./...`"* but `-race` runs under the test step, not the lint step) | Surfaced as SUGGESTION in cycle 1 review of `add-go-developer` (workflow rule: apply only CRITICAL/MAJOR). Then rejected from `extend-slice-aware-to-other-agents` to keep bounded scope (Decision 4 there). Should be addressed in a future micro-PR. | `tasks/extend-slice-aware-to-other-agents.md` Decision 4 | 2026-05-03 | Resolved 2026-07-08 — agent deleted in `risk-tiered-workflow`; `skills/stacks/go.md` places `-race` under verification commands, no lint confusion |

## Self-evolution
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Design persistent memory of user interactions so Claude can learn lessons across sessions and consolidate new thinking into concrete suggestions for its own evolution (workflow rules, agent definitions, skill prompts). Should specify: what gets captured, where it lives (relative to existing auto-memory at `~/.claude/projects/.../memory/` and this repo's `agents/`/`skills/`), how lessons get reviewed/promoted into committed agent/skill changes, and the trigger cadence (per-session, per-feature, manual). | Out of scope — needs its own grill-plan session; touches the meta-workflow itself, so impacts every future feature. | — | 2026-05-03 | Open |

## Workflow
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Discuss how to split tasks down further so that each pull request stays reviewable. Current slice convention bundles all slices of a feature into a single PR, which can grow large. Should explore: criteria for when to split a feature into multiple PRs, how slices map to PRs (1:1, grouped, stacked), how issue status comments track multi-PR features, and whether Step 1 should output a PR-split proposal. | Needs its own grill-plan session — affects the core Step 2 workflow and PR conventions. | — | 2026-05-03 | Open |
| Lock down each agent's `tools:` (and possibly `model:`) in its frontmatter so capabilities match the agent's role. Read-only reviewers (`reviewer`, `security-reviewer`) should not have Edit/Write/Bash-mutation tools; the `developer` agent should not have GitHub-issue mutation tools; `issue-liaison` should not have code-edit tools. Should specify: per-agent allowed tool list, whether to constrain `model:` per agent, and how to keep the lockdown in sync when new tools appear. *(Agent names updated 2026-07-08 for the unified agent set.)* | Needs its own grill-plan session — affects every agent definition and could break existing workflows if too restrictive. | — | 2026-05-03 | Open |
| Split tasks into ones where multiple sub-agents can act in parallel. Today the workflow runs one developer agent per task end-to-end; explore decomposing a task/plan into independent units of work that can be dispatched to multiple agents concurrently (e.g. parallel slices, frontend/backend split, independent modules). Should specify: how Step 1 marks parallelizable units, how the coordinator dispatches and joins results, conflict/merge handling on a shared branch, and how issue status comments track multi-agent execution. | Needs its own grill-plan session — changes the core Step 2 dispatch model and concurrency semantics. | — | 2026-05-04 | Open |

## From feature/parallel-sub-agents
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Pre-dispatch overlap detection — at the moment the user provides the parallel feature list, coordinator inspects each plan's file references and warns if two plans touch the same path (e.g. *"plans X and Y both touch `agents/foo.md` — dispatch sequentially?"*). Should specify how plans expose their file references (explicit `## Files` section? heuristic scan?), false-positive tolerance, and whether the warning is advisory or blocking. | Discussed during Q7 grilling; chose the standard GitHub merge flow first because it works without new tooling. Worth revisiting if conflicts become a recurring pain. | Decision 7 | 2026-05-04 | Obsolete 2026-07-08 — parallel-dispatch tooling deleted in `b898c16`; revisit only with the parallel sub-agents item above |

## From feature/reviewer-agents
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| test-quality reviewer agent | Strong follow-on candidate; reviews test code (coverage gaps, brittle assertions, mocking abuse). Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape | 2026-05-04 | Obsolete 2026-07-08 — superseded by the unified `reviewer` (test-quality checks folded into `agents/reviewer.md`) |
| dependency reviewer agent | Strong follow-on candidate; reviews new package adds (license, maintenance, supply-chain). Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape | 2026-05-04 | Obsolete 2026-07-08 — superseded; dependency audit lives in the developer evidence report + stack-brief supply-chain stop-and-asks |
| PR / commit-message reviewer agent | Strong follow-on candidate; reviews PR description and commit-message hygiene. Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape | 2026-05-04 | Obsolete 2026-07-08 — contradicts the single-pass review design |
| Wire `security-reviewer` into the Step 2 gate | Different review strategy (full-repo, persistent log); changing the gate's contract beyond what the trinity needs. Stays on-demand. | Q10 (i) | 2026-05-04 | Resolved 2026-07-08 — high-risk lane dispatches `security-reviewer` at the gate (`skills/implement-feature.md` step 4) |
| Extract a shared `agents/_reviewer-skeleton.md` template | Premature abstraction at 3 reviewers; existing reviewer agents converge on a skeleton organically. Revisit once the deferred trio above lands and the count is closer to 5. | Q10 (ii) | 2026-05-04 | Obsolete 2026-07-08 — reviewers collapsed to one; nothing to template |

## From feature/parallel-docker-workers
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Long-lived worker pool with task queue | Different product than feature-scoped containers; only worth building if there's a 24/7 worker need we don't currently have | Decision 5 | 2026-05-05 | Obsolete 2026-07-08 — dispatch infrastructure deleted in `b898c16` |
| Replace `parallel-dispatch.md` entirely with the Docker variant | Worktree dispatch has zero infra cost and remains the right default for most parallel work; revisit only if Docker dispatch becomes universally preferred | Decision 6 | 2026-05-05 | Obsolete 2026-07-08 — both dispatch skills deleted in `b898c16` |
| Add a `shell-docker-developer` agent | No language-specific developer agent in the existing index fits Bash/Docker/Markdown work in this meta/skill-library repo; coordinator implements such changes directly. Worth grilling its own scope (when it owns implementation, what tools it gets, how it interacts with `code-reviewer`). | Step 2 implementation routing | 2026-05-05 | Obsolete 2026-07-08 — superseded by the unified `developer` + `skills/stacks/shell.md`; meta-repo direct edits are now the sanctioned express lane |
| Canary fixture missing in worker worktree — `tasks/_canary.md` lives only on the feature branch, but `dispatch-docker-worker.sh` cuts the worktree from `main` (default `BASE`), so the container reports `BLOCKED — missing: tasks/_canary.md`. Affects both `test-dispatch-single.sh` and `test-dispatch-parallel.sh` when run on a Mac (or anywhere the fixture isn't yet on `main`). Options: merge the canary fixture to `main`; have the test scripts pass the current branch as `BASE`; or copy the fixture into the worktree post-creation. | Surfaced after fixing macOS portability (`brew install coreutils flock`); pre-existing fixture/test-script bug, not a regression. | — | 2026-05-05 | Obsolete 2026-07-08 — scripts and fixture deleted (`b898c16`; `tasks/_canary.md` removed in `risk-tiered-workflow`) |
| Parallel dispatch test hangs after 3rd worker — `_canary_d` never gets a worktree and `test-dispatch-parallel.sh` hangs at `wait`. Likely a semaphore/FIFO race or a silent worktree-creation failure on the 4th slug. Currently masked by the canary-fixture bug above; revisit once the fixture issue is fixed. | Observed during Mac re-run; only 3 of 4 worktrees materialised, parent script idle with no children. | — | 2026-05-05 | Obsolete 2026-07-08 — test scripts deleted in `b898c16` |

## From feature/add-shell-developer-agent
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Manual sync of new `shell-developer` agent into `~/.claude/CLAUDE.md` | Project convention: the derived copy is refreshed manually post-merge, not as part of the feature touching `SYSTEM_PROMPT.md`. After this feature merges, copy the updated routing list and Agent index into `~/.claude/CLAUDE.md` so the active session and other "raw" sessions pick up the new agent. | D7 | 2026-05-05 | Obsolete 2026-07-08 — `shell-developer` deleted; the standing post-merge step (copy `SYSTEM_PROMPT.md` into `~/.claude/CLAUDE.md`) covers the current agent set |

## From feature/paired-docker-dev-reviewer-loop

*Plan shelved 2026-07-08 — see the banner in `tasks/paired-docker-dev-reviewer-loop.md`. Rows kept for the record.*

| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Severity-policy revision (e.g. block on MINOR, demote MAJOR to non-blocking) | Out of scope: paired memory doesn't change *what should* block a PR. Separate, future decision requiring its own evidence. | Decision 6 | 2026-05-05 | Open — still applies to the `reviewer` gate in `implement-feature` v3 |
| Concurrency cap change (raise above 3 or lower below 3) | Out of scope: cap rationale (gate cognitive load) is unchanged by paired pattern. Separate, future decision needing user-testing data. | Decision 11 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved; no dispatch concurrency to cap |
| Long-lived "watcher" containers with in-container shell loops | Out of scope: per-round restart with persistent session JSONL gives identical user-facing memory-across-rounds property at lower complexity. | Decision 3 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
| Pre-computed diff injection into reviewer prompt | Out of scope: reviewer container has full git access in worktree and can compute its own diff with tool use. | Slice 7 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
| Adversarial canary that deterministically forces round-2 by triggering a known reviewer flag | Out of scope: rejected as flaky in CI; stub-reviewer mode (Decision 14) covers multi-round paths deterministically. | Decision 14 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
| Two separate Docker images (`claude-worker-dev`, `claude-worker-reviewer`) | Out of scope: image-pair drift cost outweighs separation benefit; one-image with role-via-env-var is simpler. | Decision 7 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
| Coordinator-orchestrated loop in skill prose (loop logic in markdown rather than shell) | Out of scope: shell scripts have testable contracts; skill prose does not. | Decision 9 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
| Mid-round retry-once-then-BLOCKED for transient failures | Out of scope: retry semantics ambiguous when Claude has partially committed; user re-dispatch is the natural retry mechanism. | Decision 15 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
| Feature flag (`WORKER_PAIR_LOOP_ENABLED`) for incremental rollout | Out of scope: repo convention rejects feature flags; atomic-flip slice is the cutover. | Decision 16 | 2026-05-05 | Obsolete 2026-07-08 — plan shelved |
