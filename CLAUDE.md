# Claude-prompt repo conventions

This repo **is** the agent and skills library. When working here:

- All agent definitions live in `agents/` — one `.md` file per agent.
- All skill definitions live in `skills/` — one `.md` file per skill.
- Every new agent must have a one-line entry added to `agents/README.md`.
- Every new skill must have a one-line entry added to `skills/README.md`.
- Agent and skill filenames use `kebab-case`.
- Do not commit local Claude settings (`settings.local.json`).
- **The coordinator workflow source of truth lives in this repo, split across two files:** `SYSTEM_PROMPT.md` (always-loaded skeleton — role, non-negotiable rules, the express/standard/high-risk lanes, the Step 1/Step 2 outline for the standard and high-risk lanes, dispatch triggers) and `skills/implement-feature.md` (Step 2 procedure, stack-brief routing table, review-evidence record schema, status-comment format). When changing the workflow, ALWAYS edit those files here — NEVER edit any derived copy directly.
- Two derived copies exist downstream: a consumer repo's `CLAUDE.md` (refreshed by the `sync-upstream` skill, between `<!-- SYSTEM_PROMPT:START/END -->` markers) and `~/.claude/CLAUDE.md` (refreshed **manually** — `sync-upstream` does not touch it). After editing `SYSTEM_PROMPT.md`, copy it into `~/.claude/CLAUDE.md` yourself so the active session picks up the change; `skills/implement-feature.md` needs no manual copy — `~/.claude/skills`/`~/.claude/commands` symlink into the clone, so updating the clone (`git pull` in `~/.claude/claude-prompt`) propagates it. See README "Workflow source of truth" for the long form.
