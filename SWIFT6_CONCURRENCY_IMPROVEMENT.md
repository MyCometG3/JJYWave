# Swift Concurrency Improvement Plan (Swift 6)

## Scope

This document tracks concurrency modernization in **JJYWave**, including what is already complete and what should be implemented next after PR #23.

## Current State (Post-PR #23)

The codebase remains primarily queue-based (`DispatchQueue`, `DispatchSourceTimer`) for real-time audio safety, with selective Swift concurrency usage (`Task { @MainActor ... }`) for UI-facing callback hops.

## Completed Work

### Implemented and merged

1. Main-actor callback hops for UI-facing delegate events.
   - `JJYKit/Generator/JJYAudioGenerator.swift`
   - `JJYKit/Services/AudioGeneratorCoordinator.swift`
2. Queue reentrancy hardening for scheduler/generator/engine.
   - `JJYKit/Time/TransmissionScheduler.swift`
   - `JJYKit/Generator/JJYAudioGenerator.swift`
   - `JJYKit/Audio/AudioEngine.swift`
3. Synchronous teardown safety improvements.
   - `JJYAudioGenerator.deinit` synchronous cleanup with reentrancy handling.
   - `AudioEngine.stopEngine()` synchronous cleanup path with reentrancy handling.
4. Repository-level concurrency guidance added.
   - `README.md` section: `Concurrency Guidelines`.

### Plan items removed as already done

- The prior “Phase 1/2/3 initial hardening” tasks from the first draft are complete and are no longer listed as next actions.

## Observed Gap Requiring Immediate Follow-up

There is an existing flaky test that should be stabilized before deeper actor migration:

- `AudioEngineTests.testConcurrentSetup()` intermittently fails in CI/local test runs.

This test currently uses a fixed timeout while performing concurrent setup work that can exceed the timeout under load.

## Next Step Strategy (Recommended)

## Phase A: Stabilize Test Reliability First

### Goal

Eliminate false-negative test failures before introducing larger concurrency refactors.

### Implementation plan

1. Refactor `testConcurrentSetup()` to avoid fragile fixed wait assumptions.
2. Use deterministic completion criteria (`group.wait` with robust timeout handling or expectation fulfillment tied to actual operation completion).
3. Add additional diagnostics in the test when timeout occurs (operation count completed vs expected).
4. Re-run this test repeatedly (at least 20 times) to verify stability.

### Target files

- `Tests/AudioEngineTests.swift`

### Exit criteria

- No flake observed in repeated runs.
- Full `JJYWaveTests` passes consistently across multiple runs.

---

## Phase B: Expand MainActor Isolation to Presentation Boundary

### Goal

Move from ad-hoc main hops to explicit actor boundaries in presentation/UI orchestration code.

### Implementation plan

1. Audit `App/ViewController.swift` UI mutation methods.
2. Mark UI-only methods (or the type where safe) with `@MainActor`.
3. Remove redundant dispatches now covered by actor isolation.
4. Validate behavior with manual smoke tests (start/stop generation, frequency switching, UI labels).

### Target files

- `App/ViewController.swift`
- `JJYKit/Services/AudioGeneratorCoordinator.swift` (follow-up cleanup only if needed)

### Exit criteria

- No UI-thread warnings.
- Same runtime behavior as current release path.

---

## Phase C: Strict Concurrency Readiness (Incremental)

### Goal

Prepare for stricter Swift 6 concurrency checks without destabilizing real-time paths.

### Implementation plan

1. Enable stricter concurrency diagnostics in build settings for local validation.
2. Audit closure boundaries for safe `@Sendable` adoption.
3. Add `Sendable` only to value types that are semantically safe.
4. Avoid broad `@Sendable` application that introduces non-Sendable capture warnings in queue-bound classes.

### Target files

- Build settings (`.xcodeproj`)
- `JJYKit/Audio/*`
- `JJYKit/Generator/*`
- `JJYKit/Services/*`

### Exit criteria

- Concurrency warnings trend downward without changing runtime behavior.
- No new race-condition regressions in tests.

---

## Phase D: Actor Feasibility Prototype (Do not replace production path yet)

### Goal

Evaluate actor-based isolation for one non-audio-critical slice before broader migration.

### Implementation plan

1. Choose a low-risk candidate (configuration/state coordination only).
2. Implement a prototype actor behind existing interfaces.
3. Benchmark against current queue-based path.
4. Decide go/no-go based on determinism and complexity.

### Candidate area

- `TransmissionScheduler` configuration state path only (not timing-critical dispatch internals)

### Exit criteria

- No timing regression.
- Clear maintainability gain vs current queue approach.

## Suggested Branch/PR Order

1. `swift6-concurrency-phase-a-test-stability`
2. `swift6-concurrency-phase-b-mainactor-boundary`
3. `swift6-concurrency-phase-c-strict-diagnostics`
4. `swift6-concurrency-phase-d-actor-prototype`

## Definition of Done (Updated)

1. Existing flaky concurrency test is stabilized.
2. UI boundary isolation is explicit and consistent.
3. Strict concurrency diagnostics are improved with no functional regressions.
4. Actor migration decisions are based on measured prototype results, not assumptions.
