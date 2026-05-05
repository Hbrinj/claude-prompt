---
Name: parallel-docker-dispatch
Description: Docker variant of parallel-dispatch — fans out ≥2 features to claude-worker containers with full in-container freedom (open network, root filesystem). Opt-in via explicit "in containers" / "with docker" / "dockerised" trigger phrasing. Defers shared semantics (cap reasoning, gate flow, combined-diff pass) to parallel-dispatch.md.
---

# parallel-docker-dispatch

Docker variant of `parallel-dispatch`. Each worker agent runs inside its own
`claude-worker` container with full in-container freedom (open network, root
filesystem, ability to `apt install`, run servers, do destructive shell work);
the host coordinator still owns plan distribution, gate approvals, branch
pushes, and PR opening.

For shared semantics — pre-dispatch validation, concurrency cap reasoning,
per-feature gate flow, combined-diff reviewer pass — this skill defers to
`skills/parallel-dispatch.md`. Only the Docker-specific mechanics live here.

## When to invoke (vs parallel-dispatch)

`parallel-dispatch` is the default for parallel work — workers run in git
worktrees on the host, no container infrastructure required. Invoke
`parallel-docker-dispatch` only when the user explicitly signals it in the
dispatch instruction, with phrasing like:

- *"dispatch features X, Y, Z in containers"*
- *"… with docker"*
- *"… dockerised"*

The trigger phrase is a deliberate user judgment call: they're saying the work
needs full system-level access (global package installs, long-running servers,
destructive shell ops) and accept the container infra cost. There is NO
heuristic auto-routing — if the phrase is absent, use `parallel-dispatch`.

## Starting state

- The user has named ≥2 features in a single dispatch AND used the trigger
  phrase above.
- For every named feature, an approved plan exists at `tasks/<slug>.md`
  (Step 1 has completed).
- No `feature/<slug>` branch exists locally or on origin for any of those
  features.
- Docker daemon is running on the host.
- `CLAUDE_CODE_OAUTH_TOKEN` is exported in the coordinator's environment
  (host minted it once via `claude setup-token`).

## Target state

Same as `parallel-dispatch`: each named feature has its own `feature/<slug>`
branch with code committed, the developer agent ran its self-review loop
inside its container before writing `.worker-result.json`, each feature's
PR is opened after the user approves its per-feature gate, and a final
combined-diff reviewer pass has run.

---

## Entry behaviour — execute in order

### Step 1 — Pre-dispatch validation

All checks from `parallel-dispatch.md` Step 1 (plan exists, no clashing
branches, no in-progress checkpoint, no duplicate slugs) PLUS:

- `docker version --format '{{.Server.Version}}'` succeeds. If not → STOP and
  ask the user to start the Docker daemon.
- `docker image inspect claude-worker:test` succeeds, OR the user approves
  running `docker build -t claude-worker:test docker/` now (the dispatch
  wrapper builds on demand if the image is absent, but the first build is
  ~1–2 GB and worth surfacing).
- `[ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]`. If not → STOP and tell the user to
  export it.
- `[ -x scripts/dispatch-docker-worker.sh ]`. If not → STOP (the skill is
  unusable without the wrapper).

If validation fails for any feature, STOP and report exactly which checks
failed. Do NOT dispatch a partial batch.

### Step 2 — Concurrency cap

cap of 3 concurrent containers, same reasoning as `parallel-dispatch.md`
Step 2 (gate cognitive load is the binding constraint, not host CPU).
Each container handles one whole feature end-to-end (the unit of work);
slice-level fan-out is NOT supported. Surplus features queue and release
one per per-feature gate approval.

### Step 3 — Fan-out (single coordinator turn)

In ONE coordinator message, emit one `Bash` tool-use block per feature in
the active slot. Each call uses:

- `run_in_background: true` — completion lands as a notification.
- `command`: `scripts/dispatch-docker-worker.sh <slug>` (with optional
  trailing base branch if not `main`).
- `description`: `"Docker worker: <slug>"`.
- Optional env override per dispatch: `WORKER_TIMEOUT=<seconds>` for
  known-large features (default 1800 = 30 min).

The wrapper:
1. Creates `../wt-<slug>` as a git worktree on `feature/<slug>`.
2. Builds `claude-worker:test` if missing.
3. Runs `timeout 1800 docker run --rm --name claude-worker-<slug>-<pid>
   [--user uid:gid on Linux] -v <wt>:/workspace -e SLUG=<slug>
   -e CLAUDE_CODE_OAUTH_TOKEN claude-worker:test`. The container's entrypoint
   invokes `claude --print --dangerously-skip-permissions` against
   `tasks/<slug>.md` and writes `.worker-result.json` before exiting.
4. On timeout (exit 124), synthesises a `BLOCKED` result file and removes
   the container.

All N calls go in the SAME message. Sequential dispatch across multiple
coordinator turns is forbidden — same reasoning as `parallel-dispatch`.

### Step 4 — Track completions

When each backgrounded `Bash` call completes, read
`../wt-<slug>/.worker-result.json`:

```
{
  "status":   "APPROVE" | "BLOCKED",
  "branch":   "feature/<slug>",
  "commits":  ["<short sha>", ...],
  "summary":  "<one-sentence>",
  "blockers": ["<reason>", ...]
}
```

If the wrapper exited non-zero AND no result file is present, the worker
crashed before writing — synthesise a `BLOCKED` entry citing the wrapper's
exit code and stderr, and surface that at the gate.

Update each feature's `features/<slug>.checkpoint.md` to
`Step 2 — Implement — COMPLETE` (or `BLOCKED` with blockers from the result
file) immediately on receipt — do not batch.

### Step 5 — Per-feature gate, in completion order

Same shape as `parallel-dispatch.md` Step 5 — surface the gate the moment a
feature completes; on approval, append the row to `features/all_features.md`,
push the branch, open the PR via `gh pr create`, then release one queued
feature if any.

Push semantics: the branch lives in the bind-mounted worktree but the same
ref is visible from the main repo (`git worktree` shares the `.git`
directory). `git -C <repo-root> push origin feature/<slug>` works as
expected. The container has been torn down by the time we reach this gate;
nothing in-container holds any state.

### Step 6 — Combined-diff reviewer pass

Mechanically identical to `parallel-dispatch.md` Step 6 — branches live on
the host post-dispatch, so `code-reviewer` runs on the host the same way.
Advisory only; does not block any merge.

---

## Allowed actions

- All actions from `parallel-dispatch.md` (`Allowed actions` section).
- Run `Bash` calls invoking `scripts/dispatch-docker-worker.sh` with
  `run_in_background: true`.
- Read `../wt-<slug>/.worker-result.json` for each dispatched feature.
- Run `docker version`, `docker image inspect`, `docker build`,
  `docker ps -a` for pre-dispatch checks and post-dispatch hygiene.

## Forbidden actions

- All forbidden actions from `parallel-dispatch.md`, plus:
- NEVER mount the host's `~/.claude` directory into the worker container —
  auth flows through `CLAUDE_CODE_OAUTH_TOKEN` env var only.
- NEVER bind-mount the host's repo working tree directly — always use the
  per-feature worktree path.
- NEVER bypass the wrapper to run `docker run` without a timeout.
- NEVER run the worker without `--rm` (containers are disposable; the
  worktree retains everything needed for post-mortem).
- NEVER pass `--network host` or any other flag that punctures the default
  network/process isolation; the open-network decision is bridge-mode only.
- NEVER auto-merge any PR.
- NEVER push to `main` directly.

## Stop and ask before

- All triggers from `parallel-dispatch.md` (`Stop and ask before`), plus:
- Docker daemon is not reachable.
- `claude-worker:test` image is absent AND the user has not approved
  building it (~1–2 GB, ~60 s on first build).
- `CLAUDE_CODE_OAUTH_TOKEN` is not set on the host.
- A worker exits with a `BLOCKED` result whose `blockers` cite "timeout" —
  surface clearly so the user can decide whether to retry with a longer
  `WORKER_TIMEOUT`.

---

## Resume semantics

Same as `parallel-dispatch.md`: per-feature checkpoint files are the source
of truth; no batch-level resume. To resurrect the still-running subset of a
batch, re-invoke this skill with the names of the features that have not
yet had their PR opened.

---

## Verification

`tasks/_canary.md` is a minimal fixture (stamp a UTC timestamp into
`CANARY.txt`, write `.worker-result.json` with status APPROVE) that
exercises the dispatch wiring end-to-end without spending real
implementation time. Use it as a smoke test before any large dispatch and
whenever the image, entrypoint, or skill prose changes:

```
scripts/test-image.sh           # image builds, claude --version works
scripts/test-entrypoint.sh      # entrypoint produces a valid result file
scripts/test-dispatch-single.sh # full single-feature dispatch round-trip
```

The two tests that talk to the API skip cleanly when
`CLAUDE_CODE_OAUTH_TOKEN` is absent.
