# Agent Catalogue

| Agent | Description |
|-------|-------------|
| [developer](developer.md) | Implements any stack: loads the matching stack brief from `skills/stacks/`, follows `/tdd` with enforced outcomes (test observed failing before the code that passes it, one slice per commit), returns an evidence report of red/green runs |
| [reviewer](reviewer.md) | Fresh-context, intent-fed review of the current diff against the issue brief — code, prompt definitions, docs, and config in one pass; findings are claims with evidence, ending in a verdict |
| [security-reviewer](security-reviewer.md) | Scans repository for security vulnerabilities and maintains a persistent SECURITY-ISSUES.md log; dispatched at the gate in the high-risk lane, on demand otherwise |
| [issue-liaison](issue-liaison.md) | Manages GitHub Issue communication — clarifying questions, per-phase status comments (the workflow's pause/resume state), and the final PR link (issue/spec breakdown lives in `/to-prd` + `/to-issues`) |
