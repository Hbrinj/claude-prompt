# Claude-prompt repo conventions

This repo **is** the agent and skills library. When working here:

- All agent definitions live in `agents/` — one `.md` file per agent.
- All skill definitions live in `skills/` — one `.md` file per skill.
- Every new agent must have a one-line entry added to `agents/README.md`.
- Every new skill must have a one-line entry added to `skills/README.md`.
- Agent and skill filenames use `kebab-case`.
- Do not commit local Claude settings (`settings.local.json`).
- **The coordinator workflow source of truth lives in this repo, split across two files:** `SYSTEM_PROMPT.md` (always-loaded skeleton — role, non-negotiable rules, two-step outline, dispatch triggers) and `skills/implement-feature.md` (Step 2 procedure, agent/skill routing index, checkpoint format, feature-log schema). When changing the workflow, ALWAYS edit those files here — NEVER edit any derived copy directly.
- Two derived copies exist downstream: a consumer repo's `CLAUDE.md` (refreshed by the `sync-upstream` skill, between `<!-- SYSTEM_PROMPT:START/END -->` markers) and `~/.claude/CLAUDE.md` (refreshed **manually** — `sync-upstream` does not touch it). After editing `SYSTEM_PROMPT.md`, copy it into `~/.claude/CLAUDE.md` yourself so the active session picks up the change. See README "Workflow source of truth" for the long form.
