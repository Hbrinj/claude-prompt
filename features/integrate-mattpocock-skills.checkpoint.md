# Checkpoint: integrate-mattpocock-skills

## Status
Step 1 — Plan — COMPLETE (awaiting approval at review gate)

## Completed steps
- [x] Step 1 — Plan (plan at `tasks/integrate-mattpocock-skills.md`; decisions via AskUserQuestion 2026-06-12)
- [ ] Step 2 — Implement

## Resumption notes
- Branch `feature/integrate-mattpocock-skills` created off main.
- Four decisions (all most-invasive): full replace+rewire; add all 10 with skills winning over agents; vendor verbatim flat + MIT attribution + reviewer carve-out; ship skills only (no per-repo scaffolding here).
- All 10 upstream skills fully read. Vendoring is ≈31 files incl. sibling reference docs + `diagnose/scripts/`.
- BLOCKING on user approval at the Step 1 review gate — especially the `## New workflow design` and the 4 Open Questions (parallel-dispatch knock-on, issue-tracker-as-source-of-truth, retire-vs-narrow, single vs two PRs).
- Nothing vendored or rewired yet; only the plan + this checkpoint are written.

## Last updated
2026-06-12
