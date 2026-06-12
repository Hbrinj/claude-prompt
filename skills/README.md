# Skills Catalogue

| Skill | Description |
|-------|-------------|
| [sync-upstream](sync-upstream.md) | Establishes or updates the claude-prompt submodule, syncs agents/ and skills/ into the repo, symlinks ~/.claude/agents and ~/.claude/commands so all agents and slash commands are available in every Claude Code CLI session, and updates CLAUDE.md |
| [implement-feature](implement-feature.md) | Step 2 of the coordinator workflow — implements one approved issue: branch, `/tdd` implementation via the stack developer agent, file-type reviewer routing gate, feature log, push, review gate, PR, CI monitoring. Holds the checkpoint format and feature-log schema. |

Step 1 (Understand → Specify → Slice) and the implementation methodology are owned by the vendored Matt Pocock skills below (`/grill-with-docs`, `/to-prd`, `/to-issues`, `/tdd`, …).

## Vendored — Matt Pocock engineering skills (third-party, MIT)

Vendored verbatim from <https://github.com/mattpocock/skills> (`skills/engineering/`). See [NOTICE.md](NOTICE.md) for the pinned commit, license, and update procedure. These follow upstream's structure and are scoped out of `prompt-definition-reviewer`.

| Skill | Description |
|-------|-------------|
| [setup-matt-pocock-skills](setup-matt-pocock-skills/SKILL.md) | One-time per-repo setup: records the issue tracker (GitHub/GitLab/local-markdown), triage-label vocabulary, and domain-doc layout into `docs/agents/*.md` + an `## Agent skills` block. Manual-invoke only. |
| [grill-with-docs](grill-with-docs/SKILL.md) | Grilling session that stress-tests a plan against the project's domain model, sharpens terminology, and updates `CONTEXT.md` + ADRs inline as decisions crystallise. |
| [to-prd](to-prd/SKILL.md) | Synthesizes the current conversation context into a PRD and publishes it to the issue tracker (no interview). |
| [to-issues](to-issues/SKILL.md) | Breaks a plan/spec/PRD into independently-grabbable vertical-slice (tracer-bullet) issues on the tracker, HITL/AFK tagged and dependency-ordered. |
| [tdd](tdd/SKILL.md) | Test-driven development with a red-green-refactor loop, one vertical slice at a time; integration-style tests through public interfaces. |
| [diagnose](diagnose/SKILL.md) | Disciplined diagnosis loop for hard bugs and perf regressions: build a feedback loop → reproduce → hypothesise → instrument → fix → regression-test. |
| [improve-codebase-architecture](improve-codebase-architecture/SKILL.md) | Finds deepening opportunities (shallow→deep modules), presents an HTML report, then grills the chosen candidate; informed by `CONTEXT.md` + ADRs. |
| [triage](triage/SKILL.md) | Moves issues through a state machine of triage roles; every triage comment is AI-disclaimer-prefixed. |
| [prototype](prototype/SKILL.md) | Builds a throwaway prototype to flesh out a design — a runnable terminal app for logic/state questions, or several toggleable UI variations. |
| [zoom-out](zoom-out/SKILL.md) | Go up a layer of abstraction: map the relevant modules and callers using the project's domain glossary. Manual-invoke only. |
