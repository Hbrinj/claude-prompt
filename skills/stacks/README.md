# Stack briefs

Reference briefs loaded by the `developer` agent (`agents/developer.md`) — one per tech stack. Each brief supplies **only** the stack-specific content: testing rules, idioms, verification commands, and stack stop-and-ask items. The TDD loop with enforced outcomes, the evidence-report format, and all generic rules live in the developer agent and apply to every stack.

These are not slash-command skills — they are read by the developer agent at dispatch time. The coordinator picks the brief via `## Stack-brief routing` in `skills/implement-feature.md`.

| Brief | Stack |
|-------|-------|
| [android.md](android.md) | Android/Kotlin mobile — MVVM/Clean Architecture, Jetpack Compose |
| [ios.md](ios.md) | iOS/Swift — SwiftUI, MVVM/Clean Architecture |
| [flutter.md](flutter.md) | Flutter/Dart — clean architecture with BLoC or Riverpod |
| [kotlin-backend.md](kotlin-backend.md) | Kotlin backend — Spring Boot, AWS SDK v2 |
| [go.md](go.md) | Go — CLI tools, services, libraries |
| [shell.md](shell.md) | Bash/shell scripts + the adjacent markdown prose documenting them |
| [react-typescript.md](react-typescript.md) | React + TypeScript web — SPAs, components, hooks |

Adding a stack: create `skills/stacks/<stack>.md` with `name`/`description` frontmatter (name = filename stem), add a row here and to the routing table in `skills/implement-feature.md`.
