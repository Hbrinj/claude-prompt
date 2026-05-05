# TODO

Items deferred as out-of-scope from feature planning. Triage manually.

## From feature/add-go-developer
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Fix `lint` → `test` wording in `agents/go-developer.md:61` (line reads *"the lint step also runs `go test -race ./...`"* but `-race` runs under the test step, not the lint step) | Surfaced as SUGGESTION in cycle 1 review of `add-go-developer` (workflow rule: apply only CRITICAL/MAJOR). Then rejected from `extend-slice-aware-to-other-agents` to keep bounded scope (Decision 4 there). Should be addressed in a future micro-PR. | `tasks/extend-slice-aware-to-other-agents.md` Decision 4 | 2026-05-03 | Open |

## Self-evolution
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Design persistent memory of user interactions so Claude can learn lessons across sessions and consolidate new thinking into concrete suggestions for its own evolution (workflow rules, agent definitions, skill prompts). Should specify: what gets captured, where it lives (relative to existing auto-memory at `~/.claude/projects/.../memory/` and this repo's `agents/`/`skills/`), how lessons get reviewed/promoted into committed agent/skill changes, and the trigger cadence (per-session, per-feature, manual). | Out of scope — needs its own grill-plan session; touches the meta-workflow itself, so impacts every future feature. | — | 2026-05-03 | Open |

## Workflow
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Discuss how to split tasks down further so that each pull request stays reviewable. Current `## Slices` convention bundles all slices of a feature into a single PR, which can grow large. Should explore: criteria for when to split a feature into multiple PRs, how slices map to PRs (1:1, grouped, stacked), how `features/all_features.md` and the checkpoint file track multi-PR features, and whether `/grill-plan` should output a PR-split proposal. | Needs its own grill-plan session — affects the core Step 2 workflow and PR conventions. | — | 2026-05-03 | Open |
| Lock down each agent's `tools:` (and possibly `model:`) in its frontmatter so capabilities match the agent's role. Read-only reviewers (`code-reviewer`, `security-reviewer`, `architecture`) should not have Edit/Write/Bash-mutation tools; developer agents should not have GitHub-issue mutation tools; `issue-liaison` should not have code-edit tools. Should specify: per-agent allowed tool list, whether to constrain `model:` per agent, and how to keep the lockdown in sync when new tools appear. | Needs its own grill-plan session — affects every agent definition and could break existing workflows if too restrictive. | — | 2026-05-03 | Open |
| Split tasks into ones where multiple sub-agents can act in parallel. Today the workflow runs one developer agent per task end-to-end; explore decomposing a task/plan into independent units of work that can be dispatched to multiple agents concurrently (e.g. parallel slices, frontend/backend split, independent modules). Should specify: how `/grill-plan` marks parallelizable units, how the coordinator dispatches and joins results, conflict/merge handling on a shared branch, and how the checkpoint + feature log track multi-agent execution. | Needs its own grill-plan session — changes the core Step 2 dispatch model and concurrency semantics. | — | 2026-05-04 | Open |

## From feature/parallel-sub-agents
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Pre-dispatch overlap detection — at the moment the user provides the parallel feature list, coordinator inspects each plan's file references and warns if two plans touch the same path (e.g. *"plans X and Y both touch `agents/foo.md` — dispatch sequentially?"*). Should specify how plans expose their file references (explicit `## Files` section? heuristic scan?), false-positive tolerance, and whether the warning is advisory or blocking. | Discussed during Q7 grilling; chose the standard GitHub merge flow first because it works without new tooling. Worth revisiting if conflicts become a recurring pain. | Decision 7 | 2026-05-04 | Open |

## From feature/reviewer-agents
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| test-quality reviewer agent | Strong follow-on candidate; reviews test code (coverage gaps, brittle assertions, mocking abuse). Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape | 2026-05-04 | Open |
| dependency reviewer agent | Strong follow-on candidate; reviews new package adds (license, maintenance, supply-chain). Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape | 2026-05-04 | Open |
| PR / commit-message reviewer agent | Strong follow-on candidate; reviews PR description and commit-message hygiene. Out of scope to keep this feature to the agreed trinity. | Q3 detour: broader reviewer landscape | 2026-05-04 | Open |
| Wire `security-reviewer` into the Step 2 gate | Different review strategy (full-repo, persistent log); changing the gate's contract beyond what the trinity needs. Stays on-demand. | Q10 (i) | 2026-05-04 | Open |
| Extract a shared `agents/_reviewer-skeleton.md` template | Premature abstraction at 3 reviewers; existing reviewer agents converge on a skeleton organically. Revisit once the deferred trio above lands and the count is closer to 5. | Q10 (ii) | 2026-05-04 | Open |

## From feature/parallel-docker-workers
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Long-lived worker pool with task queue | Different product than feature-scoped containers; only worth building if there's a 24/7 worker need we don't currently have | Decision 5 | 2026-05-05 | Open |
| Replace `parallel-dispatch.md` entirely with the Docker variant | Worktree dispatch has zero infra cost and remains the right default for most parallel work; revisit only if Docker dispatch becomes universally preferred | Decision 6 | 2026-05-05 | Open |
| Add a `shell-docker-developer` agent | No language-specific developer agent in the existing index fits Bash/Docker/Markdown work in this meta/skill-library repo; coordinator implements such changes directly. Worth grilling its own scope (when it owns implementation, what tools it gets, how it interacts with `code-reviewer`). | Step 2 implementation routing | 2026-05-05 | Open |
| Canary fixture missing in worker worktree — `tasks/_canary.md` lives only on the feature branch, but `dispatch-docker-worker.sh` cuts the worktree from `main` (default `BASE`), so the container reports `BLOCKED — missing: tasks/_canary.md`. Affects both `test-dispatch-single.sh` and `test-dispatch-parallel.sh` when run on a Mac (or anywhere the fixture isn't yet on `main`). Options: merge the canary fixture to `main`; have the test scripts pass the current branch as `BASE`; or copy the fixture into the worktree post-creation. | Surfaced after fixing macOS portability (`brew install coreutils flock`); pre-existing fixture/test-script bug, not a regression. | — | 2026-05-05 | Open |
| Parallel dispatch test hangs after 3rd worker — `_canary_d` never gets a worktree and `test-dispatch-parallel.sh` hangs at `wait`. Likely a semaphore/FIFO race or a silent worktree-creation failure on the 4th slug. Currently masked by the canary-fixture bug above; revisit once the fixture issue is fixed. | Observed during Mac re-run; only 3 of 4 worktrees materialised, parent script idle with no children. | — | 2026-05-05 | Open |

## From feature/add-shell-developer-agent
| Item | Why deferred | Related decision | Added | Status |
|------|--------------|------------------|-------|--------|
| Manual sync of new `shell-developer` agent into `~/.claude/CLAUDE.md` | Project convention: the derived copy is refreshed manually post-merge, not as part of the feature touching `SYSTEM_PROMPT.md`. After this feature merges, copy the updated routing list and Agent index into `~/.claude/CLAUDE.md` so the active session and other "raw" sessions pick up the new agent. | D7 | 2026-05-05 | Open |
