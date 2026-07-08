# Guard hooks

Claude Code **PreToolUse** hooks that enforce three of the workflow's
non-negotiables mechanically instead of as advisory prose. All of them read
the hook JSON on stdin, print a `permissionDecision: "deny"` object to deny,
and exit 0 with no output to allow.

| Script | Matcher | What it blocks |
|--------|---------|----------------|
| `guard-main-edit.sh` | `Edit\|Write\|NotebookEdit` | Editing/creating files while the target file's git repo is on `main`/`master`. Write targets that don't exist yet are handled by walking up the dirname chain to the nearest existing directory. Deny reason: "On main/master — create a feature branch first". |
| `guard-push-main.sh` | `Bash` | Any `git push` targeting `main`/`master`: explicit destinations (`git push origin main`, `git push origin HEAD:main`, `git push origin feature/x:main`, with or without flags) and implicit pushes (`git push`, `git push origin`, `git push --force`) while the session cwd's repo (or a `git -C <dir>` override) is on main/master. Quote and backslash characters are stripped before matching, so `git push origin "main"`, `git push origin ma\in`, `\git push origin main`, and shell wrappers like `sh -c 'git push origin main'` (or `bash -c`/`zsh -c`) are denied too. `git push --all`, `--mirror`, and `--branches` are denied outright regardless of the current branch — they push every branch, main included. Compound commands (`&&`, `;`, `\|\|`, `\|`, newlines) are denied if any segment is a denied push. Refspec destinations are matched as whole segments — `feature/main-page` and `domain-fix` are not denied. |
| `guard-push-review.sh` | `Bash` | Any `git push` of a `feature/*` or `fix/*` branch without a review-evidence record matching HEAD. The record lives at `<repo-root>/.claude/review-evidence/<branch-slug>.md` (slug = branch name with `/` → `-`) and must contain a line `HEAD: <full sha>` equal to `git rev-parse refs/heads/<branch>` — any new commit invalidates it; the workflow writes it at the review step (`skills/implement-feature.md` step 5). The branch being pushed is the explicit refspec source (`origin feature/x`, `origin feature/x:dst`, force `+` and `refs/heads/` prefixes tolerated, `HEAD` resolved to the current branch) or, for implicit pushes, the current branch of the session cwd's repo (or a `git -C <dir>` override). Skipped for: deletion pushes (`--delete`/`-d`, or an empty-source `:branch` refspec), branches outside `feature/*`/`fix/*` (main/master are `guard-push-main.sh`'s concern), and `--all`/`--mirror`/`--branches` pushes (`guard-push-main.sh` denies those outright). Same quote-stripping, shell-wrapper, and compound-command handling as `guard-push-main.sh`. |

All three guards source their shared allow/deny/stdin-parsing helpers from
the sibling `lib.sh`, located via `$(dirname "$0")` — deploy the directory as
a whole (the installer symlinks it as a whole), not individual scripts.

### Accepted tradeoff — quote-blind segment splitting

`guard-push-main.sh` and `guard-push-review.sh` split compound commands and
tokenize without parsing shell quoting, and err toward blocking. A quoted
string that merely *mentions* a bad push — e.g. `git commit -m 'x && git push
origin main y'` — is denied as a false positive. This is a deliberate
safe-direction tradeoff: a full shell parser is out of scope, and a false
deny costs a reword while a false allow costs a push to main or an unreviewed
push. Reword the string (or run the command outside the harness) to proceed.

In the other direction, constructs that only resolve at shell-evaluation time
(variables, command substitution, brace expansion — `git push origin $B`,
`{m,}ain`) can still slip through: the hook is a guardrail against accidental
pushes, not a sandbox against adversarial ones.

## Fail open

A broken hook must never brick the harness. All guards **allow** when:

- `jq` is not installed, or stdin is not valid JSON
- the sibling `lib.sh` is missing next to the guard script
- the target path is not inside a git repo, or the repo is on a detached HEAD
- the tool is not one the guard inspects
- the refspec source is not a local branch, or the branch cannot be resolved
  (`guard-push-review.sh` — a push it cannot verify is allowed, not blocked)

## Exceptions file — `~/.claude/hooks-exceptions`

The opt-out for repos that don't use the workflow. `guard-main-edit.sh` skips
its check for any target file at or under a listed path prefix (useful for
note vaults and other repos where editing on main is fine).
`guard-push-review.sh` skips its check when the root of the repo being pushed
(`git rev-parse --show-toplevel`) is at or under a listed prefix (repos not
using the review-evidence workflow). `guard-push-main.sh` deliberately has no
opt-out.

One path prefix per line; a leading `~`, `$HOME`, or `${HOME}` is expanded;
blank lines and `#` comments are ignored; the file may not exist. Prefixes
match whole path segments — `~/notes` covers `~/notes/a.md` but not
`~/notes-other/a.md`.

```
# personal vaults — main-branch edits are fine here
~/notes
$HOME/journal
/Users/me/scratch
# repos not using the review-evidence workflow — pushes need no record
~/oss/some-fork
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
./scripts/test-guard-push-review.sh
./scripts/test-install-hooks.sh
```
