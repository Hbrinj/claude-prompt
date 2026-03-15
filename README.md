# Claude Agents

A centralised collection of reusable Claude Code agents, designed to be shared across multiple repositories.

## Overview

This repository contains custom [Claude Code subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) that can be installed globally (`~/.claude/agents/`) or per-project (`.claude/agents/`). Each agent is a self-contained Markdown file with a defined role, tools, and prompt.

## Structure

```
agents/
├── README.md       # Agent catalogue and usage notes
└── *.md            # Individual agent definitions
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

- Keep each agent focused on a single responsibility.
- Prefer narrow tool lists — only grant the tools an agent genuinely needs.
- Update `agents/README.md` with a one-line entry for every new agent.
