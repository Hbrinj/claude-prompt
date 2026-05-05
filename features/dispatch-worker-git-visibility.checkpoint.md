# Checkpoint: dispatch-worker-git-visibility

## Status
Step 1 — Plan — COMPLETE

## Completed steps
- [x] Step 1 — Plan
- [ ] Step 2 — Implement

## Resumption notes
Plan written at `tasks/dispatch-worker-git-visibility.md`. Single slice:
- Add `-v "$REPO_ROOT/.git:$REPO_ROOT/.git"` to the top-level `docker run`
  in `scripts/dispatch-docker-worker.sh`.
- Move `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars out of the Linux-only
  `USER_FLAG` block to the top-level `docker run -e` flags.

Test signal: existing `scripts/test-dispatch-single.sh:34-35` assertion
transitions Red → Green; no new test required.

Adjacent parallel-test 4th-worker hang remains out of scope (already logged
in `/TODO.md` under `From feature/parallel-docker-workers`).

Open question: host repo being itself a worktree of an outer repo — flagged
for future handling, not blocking.

## Last updated
2026-05-05
