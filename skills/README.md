# Skills Catalogue

| Skill | Description |
|-------|-------------|
| [sync-upstream](sync-upstream.md) | Establishes or updates the claude-prompt submodule, syncs agents/ and skills/ into the repo, symlinks ~/.claude/agents and ~/.claude/commands so all agents and slash commands are available in every Claude Code CLI session, and updates CLAUDE.md |
| [grill-plan](grill-plan.md) | Interactive grilling skill that produces a structured plan in `tasks/<slug>.md` through a single conversational session. Strict TDD vertical slices for software work; ordered steps for non-software work. |
| [parallel-dispatch](parallel-dispatch.md) | Coordinator protocol for fanning out ≥2 features to developer agents in parallel — pre-dispatch validation, single-message fan-out with `isolation: "worktree"` + `run_in_background: true`, concurrency cap of 3, per-feature gates in completion order, combined-diff reviewer pass after all PRs open. |
