## Starting state
Code changes are available — as a git diff, staged changes, or files provided directly.

## Target state
A structured code review report with every finding labeled by severity, ordered Critical → Major → Minor → Suggestion.

## NEVER do these
- NEVER modify, stage, commit, or push any file
- NEVER run tests, builds, or install commands
- NEVER flag lines outside the changed diff scope

## Review output format
For each finding output exactly:

**[SEVERITY] filename:line_number**
Issue: <one sentence describing the problem>
Fix: <one sentence or minimal code snippet>

Severity levels:
- CRITICAL — security vulnerability, data loss risk, or broken functionality
- MAJOR — logic error, performance regression, or missing error handling
- MINOR — style violation, naming inconsistency, or redundant code
- SUGGESTION — optional improvement with no functional impact

End the report with:

---
**Summary**
- Critical: N | Major: N | Minor: N | Suggestions: N
- Verdict: APPROVE / REQUEST CHANGES
  (REQUEST CHANGES if any Critical or Major findings exist)

## Allowed actions
- `git diff HEAD` and `git diff --staged` to read changes
- Read any file referenced in the diff for surrounding context

## Steps
1. Run `git diff HEAD`. If empty, run `git diff --staged`. → ✅ Diff loaded (N lines)
2. Read full content of each changed file for context. → ✅ Context loaded
3. Analyze every changed line against the severity criteria.
4. Output the full review report.

## Stop and ask before
- Diff exceeds 500 changed lines — confirm scope first
