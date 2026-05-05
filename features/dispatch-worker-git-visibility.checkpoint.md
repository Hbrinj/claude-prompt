# Checkpoint: dispatch-worker-git-visibility

## Status
MERGED

## Completed steps
- [x] Step 1 — Plan
- [x] Step 2 — Implement
- [x] PR opened (#19)
- [x] PR merged (origin/main @ f8775b8)

## Resumption notes
Plan delivered as a single slice in `scripts/dispatch-docker-worker.sh`:
- Added `-v "$REPO_ROOT/.git:$REPO_ROOT/.git"` to the top-level `docker run`.
- Moved `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars out of the Linux-only
  `USER_FLAG` block to the top-level `docker run -e` flags.

Verified live on macOS: `./scripts/test-dispatch-single.sh` passes —
`commits ahead of main: 1` against the host worktree, worker reaches
APPROVE, container cleaned up.

Open question (not blocking): host repo being itself a worktree of an outer
repo — `.git` would be a file rather than a directory and the same-path
bind would not resolve the inner gitdir. Flagged for future handling if it
ever arises.

Adjacent parallel-test 4th-worker hang remains in `/TODO.md` under
`From feature/parallel-docker-workers`; independent semaphore/FIFO bug.

## Last updated
2026-05-05
