# split-kotlin-backend-aws-rules

Split `agents/kotlin-backend-developer.md`'s consolidated `## AWS rules — ALWAYS enforce` section into separate top-level sections, matching the precedent set by `agents/go-developer.md`'s three-section split (Decision 10 of `tasks/add-go-developer.md`). Improves discoverability — readers jump straight to the section they need rather than scanning a single bucket.

This plan is being produced via `/grill-plan` (manual protocol invocation, since the skill is not loaded as a callable tool in this session).

---

## Context

_Codebase facts learned during grilling._

- `agents/kotlin-backend-developer.md` currently has a single `## AWS rules — ALWAYS enforce` section with 6 bullets (paraphrased): SDK choice (prefer Kotlin SDK, fall back to Java v2), IAM least-privilege, prefer managed services over self-hosted, Lambda handler shape (thin handler + service class, `aws-lambda-java-events`), DynamoDB Enhanced Client + annotated data classes, S3/SQS/SNS/Secrets Manager/SSM via SDK v2 with coroutine-suspend functions.
- AWS-adjacent content lives in three other sections of the same file:
  - `## NEVER do these`: don't hardcode credentials/region/ARN; don't use AWS SDK v1
  - `## Stop and ask before`: creating new Lambda / SQS / SNS / DynamoDB table / S3 bucket; modifying CDK / Terraform / IAM
  - `## Testing rules — ALWAYS enforce`: mock AWS SDK client interfaces with MockK (no real AWS in unit tests); Lambda handler unit test with crafted event object
- The file has NO sections covering common Spring Boot opinions: logging conventions (structured vs plain, MDC), observability (metrics, tracing, health endpoints), error handling style (exception hierarchy, `@ControllerAdvice`), transaction boundaries (`@Transactional` scope), dependency injection idioms (constructor injection over field injection), configuration management (`@ConfigurationProperties` vs `@Value`, profile strategy).
- The go-developer precedent splits across three top-level sections: `## Error handling — ALWAYS enforce`, `## Concurrency — ALWAYS enforce`, `## Module hygiene — ALWAYS enforce`. Each has tight scope and a clear name.
- `## Slice-aware execution` was added to this agent in `extend-slice-aware-to-other-agents` — placement was after `## AWS rules` and before `## Allowed actions`. Splitting AWS rules will displace that anchor; the new last `## ... — ALWAYS enforce` section becomes the new anchor for `## Slice-aware execution`.

---

## Decisions

_Resolved through grilling. Each entry references the question that produced it._

1. **Mode** — software. Refactor decomposes naturally into one slice per new section with verifiable grep acceptance, mirroring the precedent of the last three markdown changes. (Q1)
2. **Scope** — pure split. The 6 bullets currently inside `## AWS rules — ALWAYS enforce` get moved into separate top-level sections. AWS-adjacent rules in `## NEVER do these`, `## Stop and ask before`, and `## Testing rules` stay where they are — they're correctly placed (NEVERs belong in NEVER, guardrails belong in Stop). Spring Boot opinions (logging, observability, transactions, DI, config) are out of scope — each merits its own grilling round. Honors the TODO entry's scope contract. (Q2)
3. **Section split: 5 sections, one topic each.** New sections: `## AWS SDK — ALWAYS enforce` (bullets 1 + 6: Kotlin SDK preference, Java v2 fallback, suspend functions where available), `## AWS service selection — ALWAYS enforce` (bullet 3: managed > self-hosted), `## IAM — ALWAYS enforce` (bullet 2: least-privilege), `## Lambda — ALWAYS enforce` (bullet 4: handler shape, event types, thin handler delegating to service), `## DynamoDB — ALWAYS enforce` (bullet 5: Enhanced Client + annotated data classes). Every bullet has a natural home; no fold-stretches; sharp discoverability per the go-developer precedent (Decision 10 of `tasks/add-go-developer.md`). (Q3)
4. **Section ordering and naming.** Order: general → specific (`AWS SDK` → `AWS service selection` → `IAM` → `Lambda` → `DynamoDB`) — reads as a coherent narrative. Naming: mixed form, each name in its most natural shape. `AWS` prefix only where needed for disambiguation (`AWS SDK`, `AWS service selection`); `IAM` / `Lambda` / `DynamoDB` are unambiguous AWS terms and stand alone. Asymmetry is acceptable — each section name is the form a developer would naturally write. (Q4)
5. **Slice structure: one atomic slice for the refactor + one slice for the TODO update.** The refactor is atomic by nature (replace one section with five — every bullet moves at the same time). Splitting into per-section slices would leave 5 intermediate commits with duplicated/inconsistent state for no real benefit. One atomic acceptance check is stronger than 5 isolated grep checks because it verifies bullet-substance preservation, ordering, and old-section removal together. Future revert is `git revert <one sha>`. The TODO.md update is a separate concern (different file, different purpose) and gets its own slice. (Q5)

---

## Slices

_Strict one-cycle TDD per slice. "Test (Red)" is a verifiable grep acceptance check (markdown deliverable, no executable tests). Each slice = one commit._

### Slice 1 — Atomic AWS rules split
**Outcome:** `agents/kotlin-backend-developer.md`'s `## AWS rules — ALWAYS enforce` section is replaced by 5 new top-level sections in order — `## AWS SDK — ALWAYS enforce`, `## AWS service selection — ALWAYS enforce`, `## IAM — ALWAYS enforce`, `## Lambda — ALWAYS enforce`, `## DynamoDB — ALWAYS enforce` — each carrying the substance of the corresponding original bullet(s). The `## Slice-aware execution` anchor below the new sections remains valid (DynamoDB becomes the new last `## ... — ALWAYS enforce`).

**Test (Red — verifiable acceptance check):** all of the following must hold:
- `! grep -qE "^## AWS rules" agents/kotlin-backend-developer.md` (old heading gone)
- `grep -qF "## AWS SDK — ALWAYS enforce" agents/kotlin-backend-developer.md`
- `grep -qF "## AWS service selection — ALWAYS enforce" agents/kotlin-backend-developer.md`
- `grep -qF "## IAM — ALWAYS enforce" agents/kotlin-backend-developer.md`
- `grep -qF "## Lambda — ALWAYS enforce" agents/kotlin-backend-developer.md`
- `grep -qF "## DynamoDB — ALWAYS enforce" agents/kotlin-backend-developer.md`
- Original-bullet substance preservation grep:
  - `grep -qF "AWS SDK for Kotlin" agents/kotlin-backend-developer.md` (SDK preference)
  - `grep -qF "least privilege" agents/kotlin-backend-developer.md` (IAM)
  - `grep -qF "managed AWS services" agents/kotlin-backend-developer.md` (service selection)
  - `grep -qF "aws-lambda-java-events" agents/kotlin-backend-developer.md` (Lambda events)
  - `grep -qF "Enhanced Client" agents/kotlin-backend-developer.md` (DynamoDB)
  - `grep -qF "suspend functions" agents/kotlin-backend-developer.md` (SDK coroutines)
- Ordering check: `grep -nE "^## " agents/kotlin-backend-developer.md` lists `AWS SDK` immediately after `Testing rules`, then `AWS service selection`, `IAM`, `Lambda`, `DynamoDB` in order, with `Slice-aware execution` immediately following.

**Implementation (Green):** Read `agents/kotlin-backend-developer.md` to confirm the current state of `## AWS rules — ALWAYS enforce` and the lines above/below it. Use a single `Edit` that replaces the entire `## AWS rules — ALWAYS enforce` block (heading + 6 bullets + trailing blank) with the 5 new sections. Each new section follows the shape `## <name> — ALWAYS enforce\n- <bullet>\n` (a single bullet for IAM/service-selection/Lambda/DynamoDB; two bullets for AWS SDK since it absorbs original bullets 1 and 6). Preserve original bullet wording verbatim where it stands as a complete sentence; lightly rephrase only when needed for the new section's standalone readability (e.g. promote a clause that referenced "AWS rules" to standalone form).

**Refactor:** Read the resulting file top-to-bottom; verify the 5 new sections read as a coherent SDK→specific narrative; verify the surrounding sections (`## Testing rules` above, `## Slice-aware execution` below) are byte-unchanged; run the full multi-clause acceptance check.

**Acceptance:** All grep clauses above pass; commit touches only `agents/kotlin-backend-developer.md`; the file's total line count grew by no more than ~6 lines (5 new headings + reformatting overhead — substance is preserved, not expanded).

### Slice 2 — TODO update
**Outcome:** `TODO.md` no longer contains the `## Clean up kotlin-backend AWS rules section` entry (work is now complete). The other entry (`## Fix lint-step / test-step wording in agents/go-developer.md`) remains untouched.

**Test (Red — verifiable acceptance check):**
- `! grep -qF "Clean up kotlin-backend AWS rules section" TODO.md`
- `grep -qF "Fix lint-step / test-step wording" TODO.md`
- `[ "$(grep -c '^## ' TODO.md)" = "1" ]` (exactly one second-level heading remains)

**Implementation (Green):** Edit `TODO.md` — delete the entire `## Clean up kotlin-backend AWS rules section` block (heading + body, including any trailing blank line that would leave a double-blank).

**Refactor:** Read `TODO.md` top-to-bottom; verify it remains internally consistent (no orphan markdown, the lint-step entry's deferral lineage still mentions the right context).

**Acceptance:** Acceptance check passes; commit touches only `TODO.md`.

---

## Open Questions

_None._
