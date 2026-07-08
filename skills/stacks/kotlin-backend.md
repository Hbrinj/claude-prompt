---
name: kotlin-backend
description: Stack brief for Kotlin backend (Spring Boot, AWS) work — loaded by the developer agent. Mandatory unit tests, AWS SDK v2 best practices, existing module/package layout respected.
---

Stack brief for the `developer` agent. Stack-specific rules only — the TDD loop, evidence rules, and generic NEVERs live in `agents/developer.md`.

## Stack NEVERs
- NEVER hardcode AWS credentials, region, or resource ARNs — use environment variables or AWS SDK defaults
- NEVER use deprecated AWS SDK v1 APIs — use AWS SDK for Kotlin or AWS SDK for Java v2
- NEVER touch `build.gradle.kts`, `pom.xml`, Terraform, or CDK unless explicitly asked (dependency additions go through the generic approval rule)

## Testing rules
- Unit tests for every Service, Repository, UseCase, handler, and utility function
- Use JUnit 5 + MockK for unit tests
- Use Testcontainers for integration tests that touch a real database or message queue
- For AWS service calls: mock using MockK against the AWS SDK client interface — never call real AWS in unit tests
- For Lambda handlers: write a unit test that invokes the handler directly with a crafted event object
- Test file location: mirror the source path under `src/test/kotlin/`
- Every test file MUST cover: happy path, error/failure path, and at least one edge case
- Test naming convention: `methodName_givenCondition_shouldExpectedBehavior`

## AWS rules
- Prefer AWS SDK for Kotlin; fall back to AWS SDK for Java v2 if the Kotlin SDK lacks the service
- For S3, SQS, SNS, Secrets Manager, SSM: use the appropriate AWS SDK v2 client with suspend functions where available
- Prefer managed AWS services over self-managed infrastructure (e.g. RDS over self-hosted Postgres, SQS over self-managed queues)
- IAM: principle of least privilege — never suggest a wildcard IAM action or resource unless the task explicitly requires it
- Lambda: use `aws-lambda-java-events` for typed event models; keep handler classes thin — delegate to a testable service class
- DynamoDB: use the DynamoDB Enhanced Client with annotated data classes
- Report any IAM permissions the new code requires in the evidence report

## Verification commands
- `./gradlew test` (or `./gradlew test --tests [TestClassName]` per slice) — all passing
- `./gradlew ktlintCheck` or `./gradlew detekt` if present — clean

## Stop and ask (stack)
- Creating a new Lambda function, SQS queue, SNS topic, DynamoDB table, or S3 bucket definition
- Modifying shared infrastructure code, CDK stacks, or Terraform modules
- Any task that changes an existing DynamoDB schema, database migration, or API contract
- Any IAM policy change or new IAM role definition
