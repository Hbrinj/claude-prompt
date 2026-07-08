---
name: shell
description: Stack brief for bash/shell work — loaded by the developer agent. Strict-mode hygiene, portability-aware tooling, scripts/test-*.sh test scripts, and co-evolution of the adjacent markdown prose documenting each script's contract.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`. This stack's scope includes the markdown prose that documents how a script is invoked or configured — skill prompts, READMEs, and agent prompts that reference the script.

## Stack NEVERs
- NEVER use `eval` on user-controlled input or any value derived from a CLI argument, env var, or file content
- NEVER use `curl … | bash` (or `wget … | sh`) install patterns inside scripts — fetch the artefact, verify it (checksum or signature), then execute
- NEVER strip `set -euo pipefail` (or any of its individual flags) to silence an error — fix the underlying error path instead

## Testing rules
- Use bare bash with `set -euo pipefail` for every test script. Do NOT introduce `bats`, `shunit2`, or other test frameworks unless the project already uses one — match what is there
- Test file location: `scripts/test-<topic>.sh` in the repo's `scripts/` directory (kebab-case after `test-`)
- Each test script begins with `#!/usr/bin/env bash` and `set -euo pipefail`
- Assertions use shell-native idioms: `[ … ]` / `[[ … ]]` for conditionals, `grep -q` for substring/pattern checks, exit codes for success/failure. Do NOT introduce assertion DSLs
- Negative-path tests use `if <cmd>; then echo FAIL; exit 1; fi` or `! <cmd>` — every script that handles errors MUST have at least one negative-path test
- Fixtures: prefer real ephemeral state — `mktemp -d` for temp directories, `git init` inside a temp dir for ephemeral repos, real subprocesses. Tear down on `trap '<cleanup>' EXIT`. Avoid mocks unless an external boundary genuinely cannot be exercised
- Coverage mandate: every shell script with non-trivial behaviour MUST have a test script. Every error path explicitly enumerated by the script (input validation, env-var presence checks, file-existence checks, non-zero exit codes) MUST be covered by at least one negative-path test
- Test scripts are executable (`chmod +x`) and invocable directly: `./scripts/test-<topic>.sh`
- When a project already has a different test idiom in active use, match the existing idiom. Default to bare bash only when no convention exists

## Shell hygiene
- Strict mode is mandatory: `set -euo pipefail` at the top of every script (after the shebang)
- Quote ALL variable expansions: `"$var"`, `"${var}"`, `"$@"` (NEVER `$@`), `"${array[@]}"` — unquoted expansions are word-split + glob-expanded; assume hostile input
- In bash, prefer `[[ … ]]` over `[ … ]` — no word-splitting, regex support (`=~`). POSIX `sh` scripts use `[ … ]` (no choice)
- ALWAYS use `trap '<cleanup>' EXIT` for resource cleanup (temp dirs, lock files, background processes) — the trap fires on success AND failure
- Beware the `set -e` + `||` interaction: `cmd || true` swallows failures; `if cmd; then …; fi` does NOT trigger `set -e` for the failing `cmd`; pipelines rely on `pipefail`. Read every `||`/`&&`/`|` chain with this in mind
- Validate user-controlled input (slugs, paths, URLs) against an allow-list pattern, NEVER a deny-list: `if ! [[ "$slug" =~ ^[A-Za-z0-9_-]+$ ]]; then exit 2; fi`
- Use `printf '%s\n' "$value"` over `echo "$value"` for arbitrary content
- For temporary files use `mktemp` (never `/tmp/myfile.$$`), and always trap-clean

## Portability
- The shebang declares the contract: `#!/usr/bin/env bash` for bash, `#!/bin/sh` for POSIX `sh`. Do NOT mix bash-only features (arrays, `[[ ]]`, `<<<`, `=~`) into a `#!/bin/sh` script
- macOS ships BSD coreutils; Linux ships GNU. Divergent tools: `timeout` (BSD has none — `brew install coreutils`), `sed -i` (BSD needs an empty-string suffix), `readlink -f` (BSD lacks `-f`), `flock` (BSD lacks it). Gate via `command -v` checks, document the install requirement in the README, or pick a portable alternative
- Run `command -v <tool>` before invoking any tool outside the POSIX baseline (jq, yq, gh, docker, timeout, flock)
- When a script may run under `zsh`, guard bash array semantics: `if [ -n "${ZSH_VERSION:-}" ]; then setopt KSH_ARRAYS NO_NOMATCH 2>/dev/null; fi`
- When adding a script that requires non-POSIX tooling, document the install command in the README

## Prose discipline
- The prose half of this stack's scope is the markdown that documents how a script is INVOKED or CONFIGURED — skill prompts, READMEs, and agent prompts that reference the script. NOT plan files or architecture docs
- Every runnable example in prose MUST exactly match the script's actual flag/argument syntax. After changing a script, grep the prose for old flag/path references and update every occurrence
- NEVER document a flag, env var, or behaviour that is not implemented; NEVER omit a behaviour the script enforces
- Prose changes that document a behaviour change MUST be in the same commit as the behaviour change — co-evolution is mandatory
- When updating a skill or agent prompt, preserve the file's existing top-level section structure — edit content within sections, don't reorder or rename them

## Verification commands
- `./scripts/test-<topic>.sh` for every touched script — all passing
- `bash -n <script>` on every changed script — exit 0
- `shellcheck <script>` on every changed script when available (`command -v shellcheck`) — exit 0; document any deliberate `# shellcheck disable=…`

## Stop and ask (stack)
- Adding any new tooling dependency (jq, yq, gh, docker, timeout, flock, etc.) not already used in the project
- Switching a script's shebang between interpreters
- Removing or renaming a script that other scripts, skill prompts, READMEs, or CI configs reference
- Changing a script's argument or flag contract in a way that breaks existing callers
- The script needs `eval`, `source` of a non-trusted file, or any other dynamically-evaluated input
