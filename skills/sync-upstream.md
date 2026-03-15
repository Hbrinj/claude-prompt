---
Name: sync-upstream
Version: 2.0.0
Description: Establishes or updates the claude-prompt submodule from https://github.com/Hbrinj/claude-prompt, syncs agents/ and skills/ into the repo, symlinks ~/.claude/agents and ~/.claude/skills to the repo directories so Claude Code picks them up globally, and updates CLAUDE.md from SYSTEM_PROMPT.md. Trigger when the user wants to pull the latest agents or skills from the shared library, set up the submodule for the first time, or refresh CLAUDE.md with the latest workflow.
---

## Starting state

The current repo may or may not have a git submodule pointing to `https://github.com/Hbrinj/claude-prompt`. The submodule path, when present, is `.claude-prompt/` at the repo root. `~/.claude/agents` and `~/.claude/skills` may or may not exist.

## Target state

1. `.claude-prompt/` exists as a registered git submodule at `https://github.com/Hbrinj/claude-prompt`, checked out at the latest commit on `main`.
2. All files under `agents/` in the submodule are present in the repo's `agents/` directory (preserving subdirectories).
3. All files under `skills/` in the submodule are present in the repo's `skills/` directory (preserving subdirectories).
4. `~/.claude/agents` is a symlink pointing to `<absolute_repo_root>/agents/`.
5. `~/.claude/skills` is a symlink pointing to `<absolute_repo_root>/skills/`.
6. `CLAUDE.md` contains the latest content from `.claude-prompt/SYSTEM_PROMPT.md` inside a guarded block. Content outside the guarded block is preserved unchanged.

---

## Execution steps — follow in exact order

After each step output: `✅ [step name] — [one-line status]`

### Step 1 — Resolve absolute repo root

Run `git rev-parse --show-toplevel` to get the absolute path of the repo root. Store this as `REPO_ROOT`. All paths below are relative to `REPO_ROOT` unless prefixed with `~/`.

### Step 2 — Detect submodule state

Run `git submodule status` and check whether `.claude-prompt` appears.

Also inspect `.gitmodules` (if it exists) for an entry with url `https://github.com/Hbrinj/claude-prompt`.

### Step 3 — Establish submodule if missing

If `.claude-prompt` is NOT registered:

```
git submodule add https://github.com/Hbrinj/claude-prompt .claude-prompt
```

STOP and report an error if this command fails. Do not proceed.

If `.claude-prompt` IS already registered but not initialized (shown by a `-` prefix in `git submodule status`):

```
git submodule update --init .claude-prompt
```

### Step 4 — Pull latest changes

```
git submodule update --remote --merge .claude-prompt
```

STOP and report an error if this command fails. Do not proceed.

### Step 5 — Sync agents/

For every file in `$REPO_ROOT/.claude-prompt/agents/` (recursively):
- Copy it to the same relative path under `$REPO_ROOT/agents/`, creating intermediate directories as needed.
- Overwrite any existing file at that path.

MUST NOT delete files in `agents/` that do not exist in the submodule — only add or overwrite.

### Step 6 — Sync skills/

For every file in `$REPO_ROOT/.claude-prompt/skills/` (recursively):
- Copy it to the same relative path under `$REPO_ROOT/skills/`, creating intermediate directories as needed.
- Overwrite any existing file at that path.

MUST NOT delete files in `skills/` that do not exist in the submodule — only add or overwrite.

### Step 7 — Link ~/.claude/agents

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

### Step 8 — Link ~/.claude/skills

Check the current state of `~/.claude/skills`:

- **Does not exist** → create the symlink:
  ```
  ln -s $REPO_ROOT/skills ~/.claude/skills
  ```
- **Exists as a symlink pointing to `$REPO_ROOT/skills`** → already correct, skip.
- **Exists as a symlink pointing to a different path** → update it:
  ```
  ln -sfn $REPO_ROOT/skills ~/.claude/skills
  ```
- **Exists as a regular directory or file** → STOP. Report the conflict and ask the user whether to remove it before creating the symlink.

### Step 9 — Update CLAUDE.md

Read `.claude-prompt/SYSTEM_PROMPT.md` to get the latest workflow content.

Open `CLAUDE.md` in `$REPO_ROOT`.

**If `CLAUDE.md` contains both markers `<!-- SYSTEM_PROMPT:START -->` and `<!-- SYSTEM_PROMPT:END -->`:**
Replace everything between those two markers (inclusive) with the guarded block below.

**If either marker is missing:**
Append the guarded block at the end of `CLAUDE.md` (add a blank line before it if the file is non-empty).

Guarded block format:
```
<!-- SYSTEM_PROMPT:START -->
<full content of .claude-prompt/SYSTEM_PROMPT.md verbatim>
<!-- SYSTEM_PROMPT:END -->
```

MUST NOT modify any content in `CLAUDE.md` outside the `<!-- SYSTEM_PROMPT:START -->` / `<!-- SYSTEM_PROMPT:END -->` markers.

### Step 10 — Report

Output a summary block:

```
## sync-upstream complete

Submodule:   .claude-prompt @ <short commit hash>
Agents:      <count> files synced → ~/.claude/agents → $REPO_ROOT/agents/
Skills:      <count> files synced → ~/.claude/skills → $REPO_ROOT/skills/
CLAUDE.md:   updated (markers found | markers appended)

Staged changes are NOT committed. Review with `git diff` before committing.
```

---

## Allowed actions

- Run `git submodule` commands scoped to `.claude-prompt`
- Run `git rev-parse --show-toplevel`
- Read files inside `.claude-prompt/`
- Create or overwrite files under `$REPO_ROOT/agents/` and `$REPO_ROOT/skills/`
- Run `mkdir -p ~/.claude`
- Create or update symlinks at `~/.claude/agents` and `~/.claude/skills`
- Edit `CLAUDE.md` within the guarded markers only

## Forbidden actions

- NEVER modify files inside `.claude-prompt/` directly
- NEVER run `git add`, `git commit`, or `git push` — leave staging to the user
- NEVER delete existing `agents/` or `skills/` files not present in the submodule
- NEVER overwrite content in `CLAUDE.md` outside the guarded markers
- NEVER run `git submodule update` on any submodule other than `.claude-prompt`
- NEVER remove or overwrite `~/.claude/agents` or `~/.claude/skills` if they are regular directories — always ask first

## Stop and ask before

- `~/.claude/agents` or `~/.claude/skills` exists as a regular directory or file (not a symlink)
- The `.claude-prompt/` path already exists as a regular directory (not a submodule)
- The submodule remote URL in `.gitmodules` does not match `https://github.com/Hbrinj/claude-prompt`
- Any git command exits with a non-zero status — report the full error output and stop
