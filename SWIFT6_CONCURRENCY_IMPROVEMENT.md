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

## Phase Status Update

## Phase A: Stabilize Test Reliability — Completed

### Implemented

1. Refactored `AudioEngineTests.testConcurrentSetup()` to use deterministic completion criteria with robust timeout handling.
2. Added timeout diagnostics (completed operations vs expected operations).
3. Validated with repeated and full-suite test runs.

### Outcome

- Removed the original timeout-based flake mechanism.
- Full test suites passed after the change.

## Phase B: MainActor Boundary Expansion — Completed

### Implemented

1. Strengthened UI boundary isolation in `App/ViewController.swift`.
2. Removed redundant main-queue dispatch wrappers where actor isolation now guarantees safety.
3. Consolidated delegate/UI handoff behavior to preserve runtime semantics.

### Outcome

- UI mutation paths are clearer and actor intent is explicit.
- Focused and full tests passed with no behavior regression.

## Phase C: Strict Concurrency Readiness — Completed

### Implemented

1. Performed strict diagnostics validation with `SWIFT_STRICT_CONCURRENCY=complete`.
2. Reduced warnings in queue-isolated components via targeted `@Sendable`, `@preconcurrency`, and `@unchecked Sendable` usage where justified by serialization design.
3. Kept queue-based real-time architecture unchanged.

### Outcome

- Strict diagnostics warning set was reduced to practical, understood boundaries.
- No functional regressions; focused and full test suites passed.

## Phase D: Actor Feasibility Prototype — Completed

### Implemented

1. Added a low-risk actor slice for scheduler configuration state:
   - `SchedulerConfiguration`
   - `SchedulerConfigurationActor`
2. Kept timing-critical scheduling logic on existing sync queue.
3. Added async snapshot API and test coverage for actor-backed configuration observation.

### Outcome (Go/No-Go)

- **Go for incremental actor use in non-real-time state boundaries.**
- **No-Go for replacing timing-critical scheduling/audio paths with actors at this stage.**
- Prototype confirms actor adoption can improve state-model clarity without destabilizing deterministic scheduling when confined to non-critical paths.

## Next Step Strategy (Post-Phase D)

1. Continue hybrid model: queue isolation for real-time/timing-critical code, actors for configuration and UI-adjacent state boundaries.
2. Add one more bounded actor slice (candidate: frequency/UI coordination state facade) behind existing protocols.
3. Keep validating with strict diagnostics build plus focused and full test suites per phase.
4. Reassess broader migration only after multiple bounded slices show net maintainability gain with zero timing regressions.

## Suggested Branch/PR Order

Completed:

1. `swift6-concurrency-phase-a-test-stability`
2. `swift6-concurrency-phase-b-mainactor-boundary`
3. `swift6-concurrency-phase-c-strict-diagnostics`
4. `swift6-concurrency-phase-d-actor-prototype`

Suggested next:

5. `swift6-concurrency-phase-e-state-facade`

## Definition of Done (Updated)

1. Existing flaky concurrency test is stabilized.
2. UI boundary isolation is explicit and consistent.
3. Strict concurrency diagnostics are improved with no functional regressions.
4. Actor migration decisions are based on measured prototype results, not assumptions.
