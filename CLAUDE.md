# Claude-prompt repo conventions

This repo **is** the agent and skills library. When working here:

- All agent definitions live in `agents/` — one `.md` file per agent.
- All skill definitions live in `skills/` — one `.md` file per skill.
- Every new agent must have a one-line entry added to `agents/README.md`.
- Every new skill must have a one-line entry added to `skills/README.md`.
- Agent and skill filenames use `kebab-case`.
- Do not commit local Claude settings (`settings.local.json`).
