# Claude-prompt repo conventions

This repo **is** the agent library. When working here:

- All agent definitions live in `agents/` — one `.md` file per agent.
- Every new agent must have a one-line entry added to `agents/README.md`.
- Agent filenames use `kebab-case` matching the `name` frontmatter field.
- Do not commit local Claude settings (`settings.local.json`).
