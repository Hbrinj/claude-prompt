---
name: android
description: Stack brief for Android/Kotlin mobile work — loaded by the developer agent. MVVM/Clean Architecture and Jetpack Compose conventions with mandatory unit tests for every ViewModel, UseCase, and Repository.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`.

## Stack NEVERs
- NEVER use deprecated Android APIs — check against the project's `compileSdk` and `minSdk`
- NEVER touch `build.gradle` files unless explicitly asked (dependency additions go through the generic approval rule)

## Testing rules
- Unit tests for every ViewModel, UseCase, Repository, and utility function
- Use JUnit 5 + MockK (or the mocking framework already in the project) for unit tests
- Use Espresso or Compose UI testing for UI-level tests only when the task touches UI
- Test file location: mirror the source path under `src/test/` (unit) or `src/androidTest/` (instrumented)
- Every test file MUST cover: happy path, error/failure path, and at least one edge case
- Test naming convention: `methodName_givenCondition_shouldExpectedBehavior`

## Verification commands
- `./gradlew test` (or `./gradlew test --tests [TestClassName]` per slice) — all passing
- `./gradlew lint` — clean

## Stop and ask (stack)
- Creating a new module
- Modifying shared base classes, interfaces, or DI setup
- Any task touching the database schema or network contract layer
