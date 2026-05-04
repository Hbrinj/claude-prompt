# parallel-dispatch

## Starting state

The user has named ≥2 features in a single dispatch (e.g. *"implement features X, Y, Z in parallel"*). For every named feature, an approved plan exists at `tasks/<slug>.md` (Step 1 has completed). No `feature/<slug>` branch exists yet on origin or locally for any of those features.

## Target state

Each named feature has its own `feature/<slug>` branch with code committed; the developer agent ran its self-review loop inside its worktree before returning; each feature's PR is opened after the user approves its per-feature gate; a final combined-diff reviewer pass has run across all opened PRs in the batch and findings have been surfaced to the user.

---

## Entry behaviour — execute in order

### Step 1 — Pre-dispatch validation

For every named feature, confirm:
- `tasks/<slug>.md` exists and contains `## Decisions` and either `## Slices` or `## Steps`. If missing → STOP and report which features need Step 1 grilling.
- No `feature/<slug>` branch exists locally or on `origin` (`git rev-parse --verify feature/<slug>` and `git ls-remote --heads origin feature/<slug>` both empty).
- No `features/<slug>.checkpoint.md` with status `IN PROGRESS` exists for that slug — it would clash with resumption.
- The same slug is not named twice in the dispatch list.

If validation fails for any feature, STOP and report exactly which features failed which check. Do NOT dispatch a partial batch.

### Step 2 — Concurrency cap (default 3)

If the user named more than 3 features:
- Dispatch the first 3 in this run.
- Queue the remainder and tell the user: *"Queued for next dispatch slot: X, Y. Each will release as a gate approves."*
- After each per-feature gate is approved (Step 5 sub-step 4), release one queued feature by re-entering Step 3 with a fresh single `Agent` call (same `subagent_type`, `isolation: "worktree"`, `run_in_background: true` parameters as the original fan-out). Skip Step 1 validation for the released feature — it was validated at original dispatch and the precondition has not changed. Do NOT re-invoke this skill from scratch for a single feature; the skill's Starting state requires ≥2 features in a single dispatch.

The cap is configurable here in this skill — change `3` to a different default if the project's cross-feature contention is consistently lower than expected. Anthropic's research-system range is 3–5; Cursor's is 8 (fully-isolated tasks).

### Step 3 — Fan-out (single coordinator turn)

In ONE coordinator message, emit one `Agent` tool-use block per feature in the active slot. Each call uses:
- `subagent_type: "<stack>-developer"` — pick per the brief's stack (`go-developer`, `android-developer`, `ios-developer`, `flutter-developer`, `kotlin-backend-developer`).
- `isolation: "worktree"` — the runtime creates a temporary git worktree per call; agent works on an isolated copy of the repo; path + branch returned at completion.
- `run_in_background: true` — completion lands as a notification; coordinator can act on each as it arrives without waiting on the slowest.
- `description: "Implement <slug>"`.
- `prompt`: brief the agent to read `tasks/<slug>.md` in its worktree, create `feature/<slug>` if not already on it, execute the plan end-to-end including the self-review loop defined in its agent prompt, and return APPROVE or BLOCKED with the reviewer's last verdict.

All N calls go in the SAME message. Sequential dispatch across multiple coordinator turns is forbidden — it forfeits the parallelism Decision 4 paid for.

### Step 4 — Track completions

As each background agent's notification lands, record from its result:
- Worktree path and branch name (returned by the Agent tool).
- Final status (APPROVE / BLOCKED).
- Commits on the branch.
- Reviewer's last verdict + outstanding findings (if BLOCKED).

Update that feature's `features/<slug>.checkpoint.md` to `Step 2 — Implement — COMPLETE` (or `BLOCKED` with reviewer findings) immediately on receipt — do not batch.

### Step 5 — Per-feature gate, in completion order

The moment a feature completes, surface its gate INDIVIDUALLY — do NOT batch:

```
## Implementation complete for <slug> — review required before PR

### Branch
feature/<slug>

### Commits on branch
<list>

### Feature log entry
<the row to be added to features/all_features.md>

### What was done
<bullet summary from the agent's report>
```

Stop and ask: *"Implementation is complete for <slug>. Approve to open the PR, or provide feedback to address first."*

On approval, in this exact order:
1. Append the row to `features/all_features.md` on the feature branch with status `In Review`; commit.
2. Push the branch to origin.
3. Open the PR using `gh pr create` with `tasks/<slug>.md` content as the body.
4. If queue from Step 2 is non-empty, release one queued feature now (re-enter at Step 3 for that one).

Sibling agents continue running regardless of any one feature's gate state. A BLOCKED feature does NOT halt siblings — its gate surfaces with the reviewer's outstanding findings; the user decides whether to triage in-session or set the feature aside.

### Step 6 — Combined-diff reviewer pass

After EVERY feature in the batch has either had its PR opened or been resolved as BLOCKED, gather the union of branch diffs vs `main` — `git diff` only accepts one commit-range per invocation, so run one diff per branch and concatenate:

```
for b in feature-X feature-Y feature-Z; do
  echo "=== $b ==="
  git diff "main...$b"
done > /tmp/parallel-batch-combined.diff
```

Then invoke `code-reviewer` once with the concatenated diff (or a path to it) as input.

Brief the reviewer: *"Review the union of these branch diffs for cross-feature interactions invisible to per-PR review: overlapping types, contradictory edits to the same prose, double-defined sections, or any inconsistency a single-PR review would miss."*

Surface the verdict and findings to the user. The pass is ADVISORY — it does NOT block any merge. The user decides what to do with findings (e.g. add a follow-up commit to one of the branches, or accept and proceed to merging).

---

## Allowed actions

- Read `tasks/<slug>.md` and `features/<slug>.checkpoint.md` for any named feature.
- Run `git rev-parse`, `git ls-remote`, `git diff` on local refs and origin.
- Invoke `Agent` with `isolation: "worktree"`, `run_in_background: true`, and a developer-agent `subagent_type`.
- Invoke `Agent` with `subagent_type: "code-reviewer"` for the combined-diff pass.
- Append rows to `features/all_features.md` per per-feature gate approval.
- Open PRs via `gh pr create`.

## Forbidden actions

- NEVER dispatch parallel without an approved plan for every named feature.
- NEVER include the same feature in two concurrent dispatches.
- NEVER skip the per-feature gate — open PRs only on explicit user approval per feature.
- NEVER batch per-feature gates ("approve all N at once") unless the user explicitly says so at a gate.
- NEVER block sibling agents on a single feature's failure.
- NEVER treat the combined-diff reviewer pass as blocking.
- NEVER auto-merge any PR without user instruction.
- NEVER push to `main` directly. Feature-branch pushes are the only push the coordinator performs.

## Stop and ask before

- Pre-dispatch validation fails for any feature (missing plan, branch already exists, duplicate slug, in-progress checkpoint).
- A developer agent returns BLOCKED — surface the reviewer findings at that feature's gate before proceeding to the next gate or the combined-diff pass.
- The user names features whose stacks span developer agents the coordinator cannot map (no matching `*-developer`).
- The user requests dispatching more than the configured cap; confirm whether to raise the cap or queue.

---

## Resume semantics

This skill has no batch-level resume. After interruption, use the existing per-feature resume protocol from `~/.claude/CLAUDE.md`: each feature's `features/<slug>.checkpoint.md` is the source of truth. To resurrect the still-running subset of a batch, re-invoke this skill with the names of the features that have not yet had their PR opened.
