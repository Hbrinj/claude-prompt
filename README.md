# Claude Agents & Skills

A centralised collection of reusable Claude Code agents and skills, designed to be shared across multiple repositories.

## Overview

This repository contains custom [Claude Code subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) and slash-command skills that can be installed globally or per-project. Each agent and skill is a self-contained Markdown file.

## Structure

```
agents/
├── README.md         # Agent catalogue and usage notes
└── *.md              # Individual agent definitions
skills/
├── README.md         # Skills catalogue and usage notes
└── *.md              # Individual skill definitions
SYSTEM_PROMPT.md      # Coordinator workflow — source of truth (committed)
CLAUDE.md             # Repo conventions for Claude when working in this repo
```

## Workflow source of truth

`SYSTEM_PROMPT.md` is the **canonical, version-controlled** coordinator workflow (Step 1 → Plan, Step 2 → Implement, non-negotiable rules, Skill index, Agent index). Two derived copies exist downstream:

- **Consumer repos' `CLAUDE.md`** — kept in sync automatically by the `sync-upstream` skill (`skills/sync-upstream.md`), which writes the latest `SYSTEM_PROMPT.md` content into a guarded block bounded by `<!-- SYSTEM_PROMPT:START -->` / `<!-- SYSTEM_PROMPT:END -->` markers. Anything in the consumer repo's `CLAUDE.md` outside those markers is preserved.
- **Your `~/.claude/CLAUDE.md`** — Claude Code's global instructions file. Kept in sync **manually** — `sync-upstream` does NOT touch it. After editing `SYSTEM_PROMPT.md`, copy the new content into `~/.claude/CLAUDE.md` yourself if you want the active session and other "raw" sessions (no sync-upstream installed) to pick up the change immediately.

> **When changing the coordinator workflow, ALWAYS edit `SYSTEM_PROMPT.md` in this repo — NEVER edit a derived copy (`~/.claude/CLAUDE.md` or any consumer repo's `CLAUDE.md`) directly.**
>
> Editing a derived copy alone is upside-down: the change is not version-controlled, is not shared with other machines or users, and is silently overwritten the next time `sync-upstream` runs in that consumer repo. The fix is one-way: edit `SYSTEM_PROMPT.md` here, commit, then propagate (sync-upstream for consumer repos, manual copy for `~/.claude/CLAUDE.md`).
>
> If you're unsure whether a change belongs in `SYSTEM_PROMPT.md` or somewhere else, default to `SYSTEM_PROMPT.md` — it's the workflow's source of truth and the safer place for any coordinator-shaped change.

The same source-of-truth rule applies to `agents/*.md` and `skills/*.md` — the repo is the source; `~/.claude/agents` and `~/.claude/commands` are derived (typically symlinked by `sync-upstream`, see [Usage](#usage)).

## Usage

### Global install (available in every repo)

```bash
# Symlink or copy individual agents
cp agents/<agent-name>.md ~/.claude/agents/

# Or symlink the whole directory (changes here apply everywhere)
ln -s "$(pwd)/agents" ~/.claude/agents
```

### Per-project install

```bash
mkdir -p .claude/agents
cp path/to/claude-prompt/agents/<agent-name>.md .claude/agents/
```

### Invoke an agent

Once installed, reference any agent in Claude Code:

```
Use the <agent-name> agent to …
```

Or from the CLI:

```bash
claude --agent <agent-name> "your task here"
```

## Skills

Skills are reusable slash commands (`/skill-name`) that appear in Claude Code's command palette.

### Global install

```bash
cp skills/<skill-name>.md ~/.claude/commands/

# Or symlink the whole directory
ln -s "$(pwd)/skills" ~/.claude/commands
```

### Per-project install

```bash
mkdir -p .claude/commands
cp path/to/claude-prompt/skills/<skill-name>.md .claude/commands/
```

### Invoke a skill

```
/skill-name
```

### Adding a new skill

1. Create a new `.md` file in `skills/`.
2. Write the prompt body (no frontmatter required, but `description:` is recommended).
3. Open a PR — the skill becomes available to all repos on merge.
4. Update `skills/README.md` with a one-line entry.

---

## Adding a new agent

1. Create a new `.md` file in `agents/`.
2. Add the required frontmatter (`name`, `description`, `tools`).
3. Write the system prompt body.
4. Open a PR — the agent becomes available to all repos on merge.

### Agent template

```markdown
---
name: agent-name
description: One-line description of when Claude should use this agent.
tools: Read, Edit, Bash   # comma-separated list of tools this agent may use
---

You are a specialist in …

## Responsibilities
- …

## Constraints
- …
```

## Dispatch scripts — host requirements

The scripts under `scripts/` (notably `dispatch-docker-worker.sh` and `test-dispatch-parallel.sh`) rely on GNU tooling that ships by default on Linux but **not on macOS**. Before running them on a Mac, install:

```bash
brew install coreutils flock
```

- `coreutils` provides `timeout` (used to bound worker wall-clock).
- `flock` provides the file lock used by the parallel-dispatch event log.

Without these, you will see `timeout: command not found` and `flock: command not found`. Linux hosts and the Docker worker image already include both.

## Contributing

- Keep each agent and skill focused on a single responsibility.
- For agents: prefer narrow tool lists — only grant the tools an agent genuinely needs.
- Update `agents/README.md` or `skills/README.md` with a one-line entry for every new addition.
