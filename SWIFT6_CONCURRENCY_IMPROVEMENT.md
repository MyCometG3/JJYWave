# Swift 6 Concurrency Status

## Current State

- Swift 6 language mode is enabled for app and test targets.
- Concurrency-related warning debt in tests has been cleaned up through phased follow-up work.
- `Gen2` baseline validation is green with:
  - `xcodebuild analyze` (warnings-as-errors)
  - `xcodebuild test` (warnings-as-errors)

## What Is Enforced in CI

- Workflow: `.github/workflows/swift6-validation.yml`
- Jobs:
  1. `xcodebuild analyze` with warnings-as-errors
  2. `xcodebuild test` on `JJYWaveTests`

## Operational Guidelines

1. Keep concurrency-related fixes minimal and scoped.
2. Treat newly introduced Swift 6/concurrency warnings as regressions.
3. Preserve queue-based design in timing-critical audio paths unless a change is explicitly justified and verified.
4. Handle flaky test stabilization in dedicated PRs, separate from warning cleanup.

## Historical Note

- The previous strict-concurrency gate script/workflow (`scripts/strict_concurrency_check.sh`, `.github/workflows/strict-concurrency-check.yml`) was retired after Swift 6 migration and steady-state validation were established.
