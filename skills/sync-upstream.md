---
name: sync-upstream
version: 3.1.0
description: Establishes or updates the claude-prompt clone from https://github.com/Hbrinj/claude-prompt, syncs agents/ and skills/ into the repo, flags local files absent from the clone as deletion candidates (may be library-removed or consumer-local — never auto-deletes), symlinks ~/.claude/agents and ~/.claude/commands to the repo directories so agents and slash commands are available in every Claude Code CLI session, and updates CLAUDE.md from SYSTEM_PROMPT.md. Trigger when the user wants to pull the latest agents or skills from the shared library, set up the clone for the first time, or refresh CLAUDE.md with the latest workflow.
---

## Starting state

The current repo may or may not have a git clone of `https://github.com/Hbrinj/claude-prompt` at `.claude/claude-prompt/`. `~/.claude/agents` and `~/.claude/commands` may or may not exist.

## Target state

1. `.claude/claude-prompt/` exists as a git clone of `https://github.com/Hbrinj/claude-prompt`, checked out at the latest commit on `main`.
2. All files under `agents/` in the clone are present in the repo's `agents/` directory (preserving subdirectories).
3. All files under `skills/` in the clone are present in the repo's `skills/` directory (preserving subdirectories).
4. `~/.claude/agents` is a symlink pointing to `<absolute_repo_root>/agents/`.
5. `~/.claude/commands` is a symlink pointing to `<absolute_repo_root>/skills/`.
6. `CLAUDE.md` contains the latest content from `.claude/claude-prompt/SYSTEM_PROMPT.md` inside a guarded block. Content outside the guarded block is preserved unchanged.

---

## Execution steps — follow in exact order

After each step output: `✅ [step name] — [one-line status]`

### Step 1 — Resolve absolute repo root

Run `git rev-parse --show-toplevel` to get the absolute path of the repo root. Store this as `REPO_ROOT`. All paths below are relative to `REPO_ROOT` unless prefixed with `~/`.

### Step 2 — Detect clone state

Check whether `.claude/claude-prompt/.git` exists to determine if the clone is already present.

### Step 3 — Establish clone if missing

If `.claude/claude-prompt/` does NOT exist as a git repo:

```
mkdir -p .claude
git clone https://github.com/Hbrinj/claude-prompt .claude/claude-prompt
```

STOP and report an error if this command fails. Do not proceed.

### Step 4 — Pull latest changes

```
git -C .claude/claude-prompt pull --ff-only
```

STOP and report an error if this command fails. Do not proceed.

### Step 5 — Sync agents/

For every file in `$REPO_ROOT/.claude/claude-prompt/agents/` (recursively):
- Copy it to the same relative path under `$REPO_ROOT/agents/`, creating intermediate directories as needed.
- Overwrite any existing file at that path.

MUST NOT delete files in `agents/` that do not exist in the clone — only add or overwrite.

### Step 6 — Sync skills/

For every file in `$REPO_ROOT/.claude/claude-prompt/skills/` (recursively):
- Copy it to the same relative path under `$REPO_ROOT/skills/`, creating intermediate directories as needed.
- Overwrite any existing file at that path.

MUST NOT delete files in `skills/` that do not exist in the clone — only add or overwrite.

### Step 7 — Stale-file check (advisory)

List every `*.md` file under `$REPO_ROOT/agents/` and `$REPO_ROOT/skills/` that does NOT exist at the same relative path in the clone. Carry the list into the Step 11 summary as **deletion candidates** — each is either a file the library once shipped and has since removed (e.g. a superseded agent) or a consumer-local file.

NEVER delete them automatically: this check cannot distinguish a removed library file from a consumer-local one, so the user decides. If the list is empty, report `Stale: none`.

### Step 8 — Link ~/.claude/agents

Ensure `~/.claude/` exists (create it if not: `mkdir -p ~/.claude`).

Check the current state of `~/.claude/agents`:

- **Does not exist** → create the symlink:
  ```
  ln -s $REPO_ROOT/agents ~/.claude/agents
  ```
- **Exists as a symlink pointing to `$REPO_ROOT/agents`** → already correct, skip.
- **Exists as a symlink pointing to a different path** → update it:
  ```
  ln -sfn $REPO_ROOT/agents ~/.claude/agents
  ```
- **Exists as a regular directory or file** → STOP. Report the conflict and ask the user whether to remove it before creating the symlink.

### Step 9 — Link ~/.claude/commands

`~/.claude/commands/` is the directory Claude Code CLI reads for global slash commands. Symlink it to the repo's `skills/` directory so all skills are available in any Claude Code session.

Check the current state of `~/.claude/commands`:

- **Does not exist** → create the symlink:
  ```
  ln -s $REPO_ROOT/skills ~/.claude/commands
  ```
- **Exists as a symlink pointing to `$REPO_ROOT/skills`** → already correct, skip.
- **Exists as a symlink pointing to a different path** → update it:
  ```
  ln -sfn $REPO_ROOT/skills ~/.claude/commands
  ```
- **Exists as a regular directory or file** → STOP. Report the conflict and ask the user whether to remove it before creating the symlink.

### Step 10 — Update CLAUDE.md

Read `.claude/claude-prompt/SYSTEM_PROMPT.md` to get the latest workflow content.

Open `CLAUDE.md` in `$REPO_ROOT`.

**If `CLAUDE.md` contains both markers `<!-- SYSTEM_PROMPT:START -->` and `<!-- SYSTEM_PROMPT:END -->`:**
Replace everything between those two markers (inclusive) with the guarded block below.

**If either marker is missing:**
Append the guarded block at the end of `CLAUDE.md` (add a blank line before it if the file is non-empty).

Guarded block format:
```
<!-- SYSTEM_PROMPT:START -->
<full content of .claude/claude-prompt/SYSTEM_PROMPT.md verbatim>
<!-- SYSTEM_PROMPT:END -->
```

MUST NOT modify any content in `CLAUDE.md` outside the `<!-- SYSTEM_PROMPT:START -->` / `<!-- SYSTEM_PROMPT:END -->` markers.

### Step 11 — Report

Output a summary block:

```
## sync-upstream complete

Clone:       .claude/claude-prompt @ <short commit hash>
Agents:      <count> files synced → ~/.claude/agents → $REPO_ROOT/agents/
Skills:      <count> files synced → ~/.claude/commands → $REPO_ROOT/skills/
Stale:       none | <count> local files not in the clone — deletion candidates, review before removing:
             <one relative path per line>
CLAUDE.md:   updated (markers found | markers appended)

Staged changes are NOT committed. Review with `git diff` before committing.
```

---

## Allowed actions

- Run `git rev-parse --show-toplevel`
- Run `git clone` and `git -C .claude/claude-prompt pull` commands
- Read files inside `.claude/claude-prompt/`
- Create or overwrite files under `$REPO_ROOT/agents/` and `$REPO_ROOT/skills/`
- List files under `$REPO_ROOT/agents/` and `$REPO_ROOT/skills/` to compare against the clone (stale-file check — report only, never delete)
- Run `mkdir -p ~/.claude`
- Create or update symlinks at `~/.claude/agents` and `~/.claude/commands`
- Edit `CLAUDE.md` within the guarded markers only

## Forbidden actions

- NEVER modify files inside `.claude/claude-prompt/` directly
- NEVER run `git add`, `git commit`, or `git push` — leave staging to the user
- NEVER delete existing `agents/` or `skills/` files not present in the clone
- NEVER overwrite content in `CLAUDE.md` outside the guarded markers
- NEVER remove or overwrite `~/.claude/agents` or `~/.claude/commands` if they are regular directories — always ask first

## Stop and ask before

- `~/.claude/agents` or `~/.claude/commands` exists as a regular directory or file (not a symlink)
- The `.claude/claude-prompt/` path already exists but is not a git clone
- Any git command exits with a non-zero status — report the full error output and stop
