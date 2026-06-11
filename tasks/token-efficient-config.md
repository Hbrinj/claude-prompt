# Token-efficient Claude Code configuration

## Context
- `~/.claude/CLAUDE.md` (a manual copy of this repo's `SYSTEM_PROMPT.md`) is ~8.6KB and loads into every session in every project — the single largest recurring token cost in the user's setup. Consumer repos additionally embed the same content via `sync-upstream`, so dev sessions often pay it twice.
- No hooks are configured: the workflow's non-negotiables ("never code on main", "never push to main") are advisory prose only.
- Skill frontmatter across `skills/*.md` uses capitalized keys (`Name:`, `Description:`) which Claude Code does not parse — skill descriptions fall back to the first content line, breaking model-side skill discovery. `parallel-dispatch.md` has no frontmatter at all. Agent files already use correct lowercase keys.
- Agent frontmatter carries no `model:` pinning; session history shows 42 manual `/model` switches between Fable and Opus.
- `agents/react-typescript-developer.md` existed only as uncommitted work in the live clone (`~/.claude/claude-prompt`); rescued onto this branch.
- Decisions below were gathered interactively (AskUserQuestion, 2026-06-11) in lieu of a `/grill-plan` session, at the user's direction.

## Decisions
- **Slim + skill split**: reduce `SYSTEM_PROMPT.md` to a ~40-line skeleton (role, non-negotiables, 2-step outline, routing one-liner, pause/resume pointer). Move the Step 2 procedure (sub-steps 1–8, file-type reviewer routing, checkpoint format, feature-log schema, review-gate template) into a new on-demand skill `skills/implement-feature.md`. Rationale: skill bodies load only when invoked; ~75% cut to the always-loaded cost.
- **Hooks**: enforce two rules with PreToolUse hooks (deny + reason): (1) Edit/Write/NotebookEdit denied when the target file's repo is on main/master; (2) `git push` targeting main/master denied (feature-branch pushes stay allowed). An exceptions file `~/.claude/hooks-exceptions` (path prefixes, one per line) skips the edit guard for e.g. note vaults.
- **Hook packaging**: scripts are version-controlled here under `scripts/hooks/`; `install.sh` (global mode) symlinks `~/.claude/hooks` → `<clone>/scripts/hooks` and prints the `settings.json` wiring snippet. `install.sh` never edits `settings.json` itself.
- **Model pinning**: add `model: sonnet` to the frontmatter of the four reviewers (`code-reviewer`, `general-reviewer`, `prompt-definition-reviewer`, `security-reviewer`). Developer agents keep inheriting the session model.
- **Frontmatter fix**: lowercase keys in `grill-plan.md`, `sync-upstream.md`, `parallel-docker-dispatch.md`, `prompt-master/SKILL.md`; add missing frontmatter to `parallel-dispatch.md`.
- **Permissions**: mined from transcripts via `/fewer-permission-prompts`, proposed to the user at the review gate, applied at user level — outside this repo.

## Slices
1. **guard-main-edit.sh** — PreToolUse hook for `Edit|Write|NotebookEdit`. Reads hook JSON on stdin; resolves the target file's git repo; if the branch is main/master, emit `permissionDecision: "deny"` with reason "On main/master — create a feature branch first". Allows: non-git paths, repos on other branches, paths under any prefix listed in `~/.claude/hooks-exceptions`. Test: `scripts/test-guard-main-edit.sh`.
2. **guard-push-main.sh** — PreToolUse hook for `Bash`. Parses `tool_input.command`; denies when it contains a `git push` that targets main/master (explicit refspec, or implicit push while the cwd repo is on main/master). Allows everything else, including feature-branch pushes. Test: `scripts/test-guard-push-main.sh`.
3. **install.sh hooks wiring** — global mode also symlinks `~/.claude/hooks` → `<clone>/scripts/hooks` via the existing `ensure_symlink`, and prints the `settings.json` hooks block for the user to apply. Test: dry-run assertion in `scripts/test-install-hooks.sh`.

## Steps (coordinator-owned prose/config)
1. Rewrite `SYSTEM_PROMPT.md` as the slim skeleton.
2. Create `skills/implement-feature.md` with the relocated Step 2 procedure; add a row to `skills/README.md`.
3. Apply the frontmatter fixes and reviewer `model:` pins.
4. Commit the rescued `react-typescript-developer.md` + its `agents/README.md` row.
5. After reviewer approval + push: check out this branch in `~/.claude/claude-prompt`, copy the slim `SYSTEM_PROMPT.md` → `~/.claude/CLAUDE.md`, create the `~/.claude/hooks` symlink, wire hooks into `~/.claude/settings.json`, run the permissions-mining proposal.

## Deferred (out of scope)
- Haiku pinning for triage-style agents — no such agents exist in this repo; the built-in Explore agent can be overridden per-call.
- Effort-level changes — the user deliberately set `xhigh`.
- Automated `settings.json` editing from `install.sh`.

## Open Questions
- None — all four configuration decisions were resolved interactively on 2026-06-11.
