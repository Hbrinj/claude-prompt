# Claude Agents & Skills

A centralised collection of reusable Claude Code agents and skills, designed to be shared across multiple repositories.

## Overview

This repository contains custom [Claude Code subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) and slash-command skills that can be installed globally or per-project. Each agent and skill is a self-contained Markdown file.

## Structure

```
agents/
├── README.md       # Agent catalogue and usage notes
└── *.md            # Individual agent definitions
skills/
├── README.md       # Skills catalogue and usage notes
└── *.md            # Individual skill definitions
```

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

## Contributing

- Keep each agent and skill focused on a single responsibility.
- For agents: prefer narrow tool lists — only grant the tools an agent genuinely needs.
- Update `agents/README.md` or `skills/README.md` with a one-line entry for every new addition.
