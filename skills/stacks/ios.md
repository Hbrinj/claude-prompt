---
name: ios
description: Stack brief for iOS/Swift work — loaded by the developer agent. SwiftUI and MVVM/Clean Architecture conventions with mandatory unit tests for every ViewModel, UseCase, and Service.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`.

## Stack NEVERs
- NEVER use deprecated Apple APIs — check against the project's deployment target
- NEVER touch `Package.swift`, `Podfile`, `xcconfig`, or project settings unless explicitly asked (dependency additions go through the generic approval rule)

## Testing rules
- Unit tests for every ViewModel, UseCase, Repository, Service, and utility function
- Use XCTest for all unit and integration tests
- Use Swift Testing (`@Test`, `#expect`) when the project already uses it — otherwise default to XCTest
- Use protocol-based mocking — create a mock conforming to the dependency's protocol; no third-party mock frameworks unless already present
- Test file location: mirror the source path under the project's `*Tests` target
- Every test file MUST cover: happy path, error/failure path, and at least one edge case
- Test naming convention: `test_methodName_givenCondition_shouldExpectedBehavior`
- For async code use `async/await` in tests; `XCTestExpectation` only as a fallback

## Verification commands
- `xcodebuild test -scheme [SchemeName] -destination 'platform=iOS Simulator,name=iPhone 16'` (scope with `-only-testing:[TestTargetName/TestClassName]` per slice) — all passing
- `swiftlint` if present in the project — clean

## Stop and ask (stack)
- Creating a new target or scheme
- Modifying shared protocols, base classes, or dependency injection setup
- Any task touching Core Data schema, CloudKit containers, or network contracts
