# Guard hooks

Claude Code **PreToolUse** hooks that enforce two of the workflow's
non-negotiables mechanically instead of as advisory prose. Both read the hook
JSON on stdin, print a `permissionDecision: "deny"` object to deny, and exit 0
with no output to allow.

| Script | Matcher | What it blocks |
|--------|---------|----------------|
| `guard-main-edit.sh` | `Edit\|Write\|NotebookEdit` | Editing/creating files while the target file's git repo is on `main`/`master`. Write targets that don't exist yet are handled by walking up the dirname chain to the nearest existing directory. Deny reason: "On main/master — create a feature branch first". |
| `guard-push-main.sh` | `Bash` | Any `git push` targeting `main`/`master`: explicit destinations (`git push origin main`, `git push origin HEAD:main`, `git push origin feature/x:main`, with or without flags) and implicit pushes (`git push`, `git push origin`, `git push --force`) while the session cwd's repo (or a `git -C <dir>` override) is on main/master. Quote characters are stripped before matching, so `git push origin "main"` and shell wrappers like `sh -c 'git push origin main'` (or `bash -c`/`zsh -c`) are denied too. `git push --all`, `--mirror`, and `--branches` are denied outright regardless of the current branch — they push every branch, main included. Compound commands (`&&`, `;`, `\|\|`, `\|`, newlines) are denied if any segment is a denied push. Refspec destinations are matched as whole segments — `feature/main-page` and `domain-fix` are not denied. |

### Accepted tradeoff — quote-blind segment splitting

`guard-push-main.sh` splits compound commands and tokenizes without parsing
shell quoting, and errs toward blocking. A quoted string that merely
*mentions* a bad push — e.g. `git commit -m 'x && git push origin main y'` —
is denied as a false positive. This is a deliberate safe-direction tradeoff:
a full shell parser is out of scope, and a false deny costs a reword while a
false allow costs a push to main. Reword the string (or run the command
outside the harness) to proceed.

Both guards source their shared allow/deny/stdin-parsing helpers from the
sibling `lib.sh`, located via `$(dirname "$0")` — deploy the directory as a
whole (the installer symlinks it as a whole), not individual scripts.

## Fail open

A broken hook must never brick the harness. Both guards **allow** when:

- `jq` is not installed, or stdin is not valid JSON
- the sibling `lib.sh` is missing next to the guard script
- the target path is not inside a git repo, or the repo is on a detached HEAD
- the tool is not one the guard inspects

## Exceptions file — `~/.claude/hooks-exceptions`

`guard-main-edit.sh` skips its check for any target at or under a listed path
prefix (useful for note vaults and other repos where editing on main is fine).
One path prefix per line; a leading `~`, `$HOME`, or `${HOME}` is expanded;
blank lines and `#` comments are ignored; the file may not exist. Prefixes
match whole path segments — `~/notes` covers `~/notes/a.md` but not
`~/notes-other/a.md`.

```
# personal vaults — main-branch edits are fine here
~/notes
$HOME/journal
/Users/me/scratch
```

## Installation

`install.sh --global` symlinks `~/.claude/hooks` → `<clone>/scripts/hooks` and
prints the snippet below; it never edits `settings.json` itself. Add to
`~/.claude/settings.json` (merge into an existing `"hooks"` key if present):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          { "type": "command", "command": "bash \"$HOME/.claude/hooks/guard-main-edit.sh\"" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$HOME/.claude/hooks/guard-push-main.sh\"" }
        ]
      }
    ]
  }
}
```

## Dependencies

- `jq` — preinstalled on recent macOS; otherwise `brew install jq` /
  `apt install jq`. Missing `jq` fails open (see above).
- `git`, `bash` — POSIX-baseline assumptions only; no GNU-specific flags.

## Tests

```bash
./scripts/test-guard-main-edit.sh
./scripts/test-guard-push-main.sh
./scripts/test-install-hooks.sh
```
