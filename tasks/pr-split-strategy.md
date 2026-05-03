# pr-split-strategy

How to split tasks/features so each pull request stays reviewable.

## Context
_Codebase facts and constraints learned during grilling._
- Mode: general (workflow/process change; no executable behaviour).
- Current convention (from `~/.claude/CLAUDE.md` Step 2): one feature → one branch (`feature/<name>`) → one PR. Slices in `tasks/<slug>.md` are commits on that branch, not separate PRs.
- Tracking artefacts: `features/all_features.md` (one row per feature), `features/<name>.checkpoint.md` (per-feature checkpoint).

## Decisions
_Resolved through grilling. Each entry references the question that produced it._
1. **One feature = one PR** — keep the existing 1:1 mapping between feature, branch, PR, and `features/all_features.md` row. Solve "PR too big" by splitting upstream into multiple smaller features during `/grill-plan` Step 1, not by introducing multi-PR features. Avoids stacked-PR mechanics, rebase pain, and schema changes to tracking artefacts. The mechanism is already present in `/grill-plan` (`## Deferred` → `/TODO.md` → future features).
2. **Trigger: slice count ≥ 5** — once a plan accumulates 5 or more slices during `/grill-plan` grilling, fire a single "should we split?" prompt. Mechanical and uniform; harder to game than a subjective cognitive-boundary heuristic. The threshold is a tripwire, not a hard cap — the user can confirm "no, this really is one feature" and continue.
3. **Tripwire prompt is binary; split reuses `## Deferred` plumbing** — when the tripwire fires, `/grill-plan` asks one yes/no question. On "yes, split", the user names the boundary; slices/scope above the boundary become rows in `## Deferred (out of scope)` with `Why deferred = "split from <slug>"`. At termination they flow to `/TODO.md` like any other deferred item. No new mechanism — the existing `## Deferred` → `/TODO.md` → future-feature pipeline handles it. Future `/grill-plan` sessions pick them up as standalone features. The `"split from <slug>"` wording in the `Why deferred` column distinguishes split-off items from genuinely out-of-scope items in `/TODO.md` triage.
4. **Software mode only** — the tripwire counts slices in `## Slices`. General-mode plans (`## Steps` for docs/RFC/infra/config) are exempt: their reviewer-load profile differs, and forcing a split prompt would be noise on the natural pattern of small-step doc/config sweeps. Users retain the manual escape hatch of voluntarily splitting a general-mode plan during grilling.
5. **Fire-once on threshold crossing** — `/grill-plan` fires the split prompt the moment a fifth slice is appended to `## Slices`. If the user dismisses ("no, continue"), the dismissal is recorded in conversation state and the prompt does not fire again for the rest of the session, even as further slices are added. Re-prompting would be naggy and override a deliberate user decision; the user can still manually invoke a split at any point by saying so.
6. **Boundary specified by slice number; per-slice deferred rows** — on "yes, split", `/grill-plan` proposes "split after slice 4" by default; user accepts or overrides with any slice number N. Slices 1..N remain in the current plan. Each slice from N+1 onward becomes its own row in `## Deferred (out of scope)` with `Item = <slice outcome line>` and `Why deferred = "split from <slug>"`. Ungrilled-but-implied scope (work the user mentioned but hadn't yet sliced) becomes a single catch-all row: `Item = "remaining ungrilled scope from <slug>"`. Per-slice granularity preserves the signal grilling already produced and lets future `/grill-plan` sessions pick a specific candidate; merging is trivial during the next session, fragmenting is not.
7. **File scope: `skills/grill-plan.md` + one-line note in `~/.claude/CLAUDE.md`** — primary edit lands in the skill (tripwire rule, prompt wording, split mechanic, per-slice-deferred convention). A single discoverability sentence is added to `~/.claude/CLAUDE.md` Step 1 so readers of the workflow doc know the mechanic exists without having to open the skill. No changes to `features/all_features.md`, the checkpoint template, `/TODO.md` schema, `skills/README.md`, or any agent definition — Decisions 1 and 3 deliberately reuse existing plumbing.
8. **Resume re-arms the tripwire** — if a resumed `/grill-plan` session opens an existing plan with ≥5 slices in `## Slices`, the prompt fires immediately at resume time. After dismissal it falls back to fire-once-already-fired silence for the remainder of that session. Rationale: a 6-slice plan is still a 6-slice plan — fresh-eyes resume is exactly when reconsidering scope is cheap. Conversation-state dismissal is intentionally not persisted to the file (would add file-state complexity for a small win); the user can dismiss again in one keystroke.

## Steps

### 1. Add the slice-count tripwire to `skills/grill-plan.md`
Extend the Grilling rules section with a new subsection that defines the tripwire mechanic. Concretely:
- Define the rule: when **Mode = software** and a fifth slice is appended to `## Slices`, fire one binary prompt asking the user whether to split. Fire-once per session — record dismissal in conversation state and do not re-prompt within the session.
- Specify the prompt content: state that the plan has reached 5 slices, that the resulting PR is likely too large for one review, and ask "split into multiple features, or continue?". On "yes", ask for the boundary slice number with the default proposal "split after slice 4".
- Specify the split execution: slices 1..N stay; each slice from N+1 onward is appended to `## Deferred (out of scope)` with `Item = <slice outcome line>` and `Why deferred = "split from <slug>"`. Any ungrilled-but-implied scope becomes a single catch-all row `Item = "remaining ungrilled scope from <slug>"` with the same `Why deferred` value. After the split, grilling continues on the now-narrower scope (slices 1..N).
- Explicitly forbid firing in general mode (`## Steps`) — add to Forbidden actions.
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: the skill file contains the tripwire rule, prompt wording, boundary mechanic, per-slice deferred convention, and a Forbidden-actions line excluding general mode. A reader following the skill instructions would fire the prompt exactly when slice 5 is appended in software mode.

### 2. Wire the tripwire into the resume path of `skills/grill-plan.md`
Update Step E2 (Resume vs restart) so that on `resume`, after the existing one-line summary, the skill checks: if Mode is software and `## Slices` already has ≥5 entries, fire the same tripwire prompt before continuing. Same dismissal/split mechanics as the in-session firing.
- Files: `skills/grill-plan.md` (UPDATE).
- Acceptance: Step E2 explicitly describes the resume-time check and references the same prompt wording defined in Step 1 above.

### 3. Add a discoverability note to `~/.claude/CLAUDE.md` Step 1
Append one sentence to the Step 1 description mentioning the split mechanic so readers of the workflow doc know it exists without opening the skill. Suggested wording: "If grilling produces five or more slices, `/grill-plan` proposes splitting into multiple features so each PR stays reviewable."
- Files: `~/.claude/CLAUDE.md` (UPDATE).
- Acceptance: Step 1 contains a single sentence describing the split-prompt behaviour. No other workflow text changed.

### 4. Verify no other artefact needs touching
Confirm — by reading, not editing — that the following files do not require changes under Decisions 1 and 3:
- `features/all_features.md` (still 1 row per feature).
- The checkpoint template described in `~/.claude/CLAUDE.md` (unchanged).
- `/TODO.md` (no schema change; "split from <slug>" is a value convention, not a column).
- `skills/README.md` (skill identity unchanged).
- Files: none modified.
- Acceptance: a one-line confirmation in the implementation commit message or PR description that these were checked and require no edits.

## Deferred (out of scope)
| Item | Why deferred | Related decision |
|------|--------------|------------------|

## Open Questions
- None. Exact wording for the tripwire prompt and the boundary follow-up is implementation detail to be written into `skills/grill-plan.md` during Step 2 of the main workflow.
