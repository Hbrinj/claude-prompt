---
name: flutter
description: Stack brief for Flutter/Dart work — loaded by the developer agent. Clean-architecture layout with BLoC or Riverpod; mandatory unit, widget, and BLoC tests.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`.

## Stack NEVERs
- NEVER use deprecated Flutter or Dart APIs — check against the project's `sdk` constraint in `pubspec.yaml`
- NEVER use `dynamic` types where a typed alternative exists
- NEVER touch `pubspec.yaml` or platform-specific native files (`AndroidManifest.xml`, `Info.plist`, build scripts) unless explicitly asked (dependency additions go through the generic approval rule)

## Testing rules
- Unit tests for every BLoC, Cubit, ViewModel, Repository, UseCase, and utility function
- Widget tests for every custom widget and screen that contains business logic or conditional rendering
- Use `flutter_test` for all unit and widget tests
- Use `mocktail` or `mockito` for mocks — match whichever is already in the project; default to `mocktail` if neither is present
- For BLoC/Cubit: use `bloc_test` package's `blocTest` helper
- Test file location: mirror the source path under `test/` — e.g. `lib/features/auth/auth_bloc.dart` → `test/features/auth/auth_bloc_test.dart`
- Every test file MUST cover: happy path, error/failure path, and at least one edge case
- Test naming convention: `methodName_givenCondition_shouldExpectedBehavior` for unit tests; `renders_[widget]_when_[condition]` for widget tests
- Widget tests MUST call `tester.pumpAndSettle()` after state changes before asserting

## Verification commands
- `flutter test` (or `flutter test [test_file_path]` per slice) — all passing
- `flutter analyze` — clean
- `dart format --set-exit-if-changed lib/ test/` — clean

## Stop and ask (stack)
- Modifying shared base classes, abstract repositories, or DI setup
- Any task touching native platform code (Kotlin/Swift/Java)
- Any task that changes an existing API contract or data model used across features
