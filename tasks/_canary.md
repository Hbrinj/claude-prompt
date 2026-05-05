# _canary

> **Test fixture — not a grilled plan.** This file is consumed by
> `scripts/test-dispatch-single.sh` and `scripts/test-dispatch-parallel.sh`
> to validate the `parallel-docker-dispatch` wiring end-to-end. The full
> grilled-plan conventions (`## Context`, `## Decisions`, `## Slices`,
> `## Open Questions`) deliberately do NOT apply here — only `## Steps`
> is meaningful, and the leading underscore in the slug marks it as a
> non-feature fixture.

A worker dispatched against this plan should produce a single commit that adds
`CANARY.txt` to its worktree, and nothing else. Used to validate end-to-end
dispatch wiring without spending real implementation time.

## Steps

### 1. Stamp the canary file
Use the Bash tool to run `date -u +%Y-%m-%dT%H:%M:%SZ > CANARY.txt`. Then commit
it: `git add CANARY.txt && git commit -m "Canary: stamp timestamp"`.
- Files: `CANARY.txt` (CREATE).
- Acceptance: `CANARY.txt` exists in the worktree, contains an ISO-8601 UTC
  timestamp, and is the tip commit on `feature/_canary`.

### 2. Write the result file
Use the Write tool to create `/workspace/.worker-result.json` with status
`APPROVE`, branch `feature/_canary`, the short SHA of the canary commit in
`commits`, summary `canary stamp ok`, and empty `blockers`. Then stop.
- Files: `/workspace/.worker-result.json` (CREATE).
- Acceptance: the file is valid JSON matching the worker-result schema; no
  further work is performed.
