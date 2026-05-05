# dispatch-worker-git-visibility

Make the in-container `git` commands operate on the actual `feature/<slug>` branch backed by the host repo, so commits made inside the `claude-worker` container land on that branch when the worktree is inspected from the host.

## Context
_Codebase facts and constraints learned during grilling._
- `scripts/dispatch-docker-worker.sh:48-58` creates a host git worktree at `../wt-<slug>` via `git worktree add ... feature/<slug> main`. The worktree's `.git` is a **file** containing `gitdir: <REPO_ROOT>/.git/worktrees/wt-<slug>` — an absolute host path.
- `scripts/dispatch-docker-worker.sh:78-84` runs `docker run --rm ... -v "$WT_DIR:/workspace" ... claude-worker:test`. Only the worktree directory is bind-mounted; the host's `<REPO_ROOT>/.git` is not visible inside the container, so the absolute path referenced by the worktree's `.git` file does not resolve.
- During the most recent live test, the in-container agent improvised by running `git init` inside `/workspace`, producing a self-contained throwaway repo. Its commit was unreachable from the host's `feature/<slug>` branch, so `test-dispatch-single.sh:34-35`'s `git rev-list --count main..HEAD` failed.
- `scripts/dispatch-docker-worker.sh:60-75` has a Linux-only `USER_FLAG` block that sets `--user $(id -u):$(id -g)` plus `HOME=/tmp`, `GOPATH=/tmp/go`, and four `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars. On macOS the block is skipped, so commits inside the container would inherit the `node` user's auto-derived identity (`node@<container-id>`).
- Git's worktree dirs (`.git/worktrees/<slug>/`) are per-slug; shared `.git/objects/` and per-branch refs are git's standard concurrent-write territory and need no extra coordination for the cap-of-3 parallel dispatch.
- The Mac-root fix (PR #18, merged 2026-05-05) is already in place — the worker reaches `APPROVE` and the only blocker for `test-dispatch-single.sh` is now the gitdir visibility issue addressed by this plan.

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **Resolution approach (Q1)** — bind-mount the host's `.git` at the same absolute path inside the container (`-v "$REPO_ROOT/.git:$REPO_ROOT/.git"`). Because the worktree's `.git` file references an absolute host path, mounting that exact path makes it resolve transparently. No clone, no path rewrite, no model change. Clone-on-host (b) was rejected — adds a post-dispatch `git fetch` step and changes Decision 4 of the original plan. Path-rewrite hybrid (c) was rejected — most code, least benefit; the path-leak it would avoid is cosmetic since the container already sees host paths via the worktree mount itself.
2. **Platform scope (Q2)** — the new `-v` is added unconditionally at the top-level `docker run` flags, not inside the Linux-only `USER_FLAG` block. The gitdir-resolution issue is platform-independent; the worktree's `.git` file points at an unreachable host path on both macOS and Linux. No reason to gate it.
3. **Git author identity (Q3)** — move the four `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars out of the Linux-only block to the top-level `docker run -e` flags so the same `claude-worker / claude-worker@local` identity applies on every platform. Once `.git` is bound and commits flow to `feature/<slug>` on the host, authorship matters for the merged history; without this, macOS workers would land `node@<container-id>` in `git log`.
4. **Test signal and task scope (Q4)** — (a) lean on the existing `scripts/test-dispatch-single.sh` (which already asserts `git rev-list --count main..HEAD ≥ 1` against the worktree on the host) as the slice's Red→Green signal; no new dedicated test. A dry-run unit test of the `docker run` command would require restructuring the wrapper for testability, which is overkill for a one-flag change. (b) The independent `test-dispatch-parallel.sh` 4th-worker hang (already in `TODO.md` under `From feature/parallel-docker-workers`) stays out of scope; it is a semaphore/FIFO race, unrelated to gitdir visibility.

## Slices

### Slice 1 — In-container git operates on the host's `feature/<slug>` branch
**Outcome:** Running `scripts/dispatch-docker-worker.sh _canary` produces a commit on `feature/_canary` that the host's parent repo can see — `git rev-list --count main..feature/_canary` returns ≥ 1 — instead of the agent improvising with a fresh `git init` inside `/workspace`.
**Test (Red):** `scripts/test-dispatch-single.sh:34-35` (`COMMITS_AHEAD=$(git -C "$WT_DIR" rev-list --count "main..HEAD"); [ "$COMMITS_AHEAD" -ge 1 ]`) currently fails because the worker's commit is in a throwaway repo and no commits are reachable from `main` on the worktree. After the fix, the same assertion passes — the commit landed on the real `feature/_canary` branch backed by the host repo. File: `scripts/test-dispatch-single.sh` (no edits — transitions Red→Green via the wrapper change alone).
**Implementation (Green):**
1. In `scripts/dispatch-docker-worker.sh`, add a single bind-mount flag to the top-level `docker run` invocation: `-v "$REPO_ROOT/.git:$REPO_ROOT/.git"`. Place it next to the existing `-v "$WT_DIR:/workspace"`.
2. Move the four `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL` env vars out of the Linux-only `USER_FLAG` block (lines 60–75) into the top-level `docker run -e` flags so they apply on macOS too. The Linux block keeps `--user`, `HOME=/tmp`, and `GOPATH=/tmp/go` (those still depend on the unmapped host uid).
File: `scripts/dispatch-docker-worker.sh`.
**Refactor:** none expected; the diff is a couple of lines.
**Acceptance:** `./scripts/test-dispatch-single.sh` exits 0 on macOS (and continues to pass on Linux). The commit visible on `feature/_canary` carries the `claude-worker <claude-worker@local>` author identity regardless of host OS.

## Deferred (out of scope)
_Items resolved as "not this feature" during grilling. Consolidated to `/TODO.md` at termination._

| Item | Why deferred | Related decision |
|------|--------------|------------------|
| _(none — the only adjacent issue, the `test-dispatch-parallel.sh` 4th-worker hang, was already logged in `/TODO.md` under `From feature/parallel-docker-workers` during the earlier session)_ | — | Decision 4b |

## Open Questions
- **Host repo is itself a worktree** — if `<REPO_ROOT>/.git` is a *file* (i.e. the host repo is itself a worktree of some outer repo) rather than a directory, the same-path bind mount won't suffice; we'd need to also mount the outer repo's `.git` directory. Not a current concern (this repo's `.git` is a normal directory) but worth flagging if a future user runs the dispatcher from inside a worktree of another repo.
