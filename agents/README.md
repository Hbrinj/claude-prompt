# Agent Catalogue

| Agent | Description |
|-------|-------------|
| [architecture](architecture.md) | Plans, reviews, and documents repository architecture — outputs a machine-readable ARCHITECTURE.md |
| [code-reviewer](code-reviewer.md) | Reviews code changes from git diff and outputs severity-labeled findings with a verdict |
| [security-reviewer](security-reviewer.md) | Scans repository for security vulnerabilities and maintains a persistent SECURITY-ISSUES.md log |
| [prompt-definition-reviewer](prompt-definition-reviewer.md) | Reviews changed agent and skill prompt files for structural and convention compliance with the repo skeleton, with a verdict |
| [general-reviewer](general-reviewer.md) | Reviews changed docs, configs, plan files, and feature-log files for clarity, completeness, and internal consistency, with a verdict |
| [android-developer](android-developer.md) | Writes Android Kotlin code with mandatory unit tests for every ViewModel, UseCase, and Repository |
| [ios-developer](ios-developer.md) | Writes iOS Swift code with mandatory unit tests for every ViewModel, UseCase, and Service |
| [kotlin-backend-developer](kotlin-backend-developer.md) | Writes Kotlin backend code with mandatory unit tests and AWS SDK v2 best practices |
| [go-developer](go-developer.md) | Writes idiomatic Go code (CLI tools, services, libraries) with mandatory tests, strict error handling, disciplined concurrency, and slice-aware execution |
| [flutter-developer](flutter-developer.md) | Writes Flutter Dart code with mandatory unit, widget, and BLoC tests for every feature |
| [shell-developer](shell-developer.md) | Writes bash/shell scripts with mandatory `scripts/test-*.sh` test scripts, strict-mode hygiene, and portability-aware tooling — also keeps adjacent markdown prose (skill prompts, READMEs) in sync with each script's contract |
| [react-typescript-developer](react-typescript-developer.md) | Writes React + TypeScript SPA code with mandatory Vitest unit tests, React Testing Library component tests, strict type-safety, hooks-only patterns, and slice-aware execution |
| [issue-liaison](issue-liaison.md) | Manages GitHub Issue communication — clarifies requirements, posts status updates, and links the final PR |
