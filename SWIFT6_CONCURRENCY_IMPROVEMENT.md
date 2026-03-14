# Swift Concurrency Improvement Plan (Swift 6)

## Scope

This document tracks concurrency modernization in **JJYWave**, including what is already complete and what should be implemented next after PR #24.

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

1. Prototyped a low-risk actor-backed configuration slice for scheduler state.
2. Validated behavior under tests, then removed the actor-backed path due to blocking/complexity trade-offs in this code path.
3. Finalized scheduler configuration as queue-isolated state (`SchedulerConfiguration` on `syncQueue`) with synchronous snapshot semantics.

### Outcome (Go/No-Go)

- **Go for incremental actor use in non-real-time state boundaries.**
- **No-Go for replacing timing-critical scheduling/audio paths with actors at this stage.**
- Prototype confirmed actor adoption can improve state-model clarity, but this scheduler path currently remains queue-isolated to preserve deterministic behavior and simpler call-site semantics.

## Next Step Strategy (Post-Phase D)

1. Continue hybrid model: queue isolation for real-time/timing-critical code, actors for configuration and UI-adjacent state boundaries.
2. Enable strict-concurrency checks as a default quality gate (warnings-as-errors in CI for touched modules first, then repository-wide).
3. Resolve remaining isolation mismatch hotspots before Swift 6 language mode migration (notably `PresentationControllerProtocol` / `ViewController` conformance boundary).
4. Keep validating with strict diagnostics build plus focused and full test suites per phase.
5. Reassess broader actor migration only after strict checks remain stable with zero timing regressions.

## Recommended Immediate Next Tasks (Phase E)

### E1. Strict Concurrency by default (Swift 5 mode)

1. Keep `SWIFT_VERSION = 5.0`, but run with strict concurrency diagnostics enabled by default in CI.
2. Treat new strict-concurrency warnings as merge blockers for changed files.
3. Preserve current runtime behavior; avoid broad async refactors in this step.

### E2. Remove temporary suppression at UI boundary

1. Replace `@preconcurrency` conformance workaround in `App/ViewController.swift` with an explicit actor-safe protocol boundary.
2. Preferred target shape: main-actor-isolated presentation protocol and explicit main-actor hop strategy at coordinator call boundaries.
3. Update affected tests to match the final isolation boundary.

### E3. Swift 6 language mode pilot (module-by-module)

1. After E1/E2 are green, pilot `SWIFT_VERSION = 6.0` on the smallest safe target surface first.
2. Promote to repository-wide Swift 6 language mode only after pilot completes without timing regressions or flaky tests.

## Should We Enable Strict Concurrency Now?

Short answer: **Yes, as diagnostics gate; not yet as full Swift 6 language-mode switch across the whole repository.**

1. Immediate go: strict-concurrency diagnostics should be continuously enforced.
2. Controlled follow-up: remove current workaround hotspots (especially UI protocol isolation boundary).
3. Then switch: move to Swift 6 language mode once diagnostics are clean and stable under repeated test runs.

## Suggested Branch/PR Order

Completed:

1. `swift6-concurrency-phase-a-test-stability`
2. `swift6-concurrency-phase-b-mainactor-boundary`
3. `swift6-concurrency-phase-c-strict-diagnostics`
4. `swift6-concurrency-phase-d-actor-prototype`

Suggested next:

5. `swift6-concurrency-phase-e-strict-gate`
6. `swift6-concurrency-phase-f-ui-boundary-alignment`
7. `swift6-concurrency-phase-g-swift6-pilot`

## Definition of Done (Updated)

1. Existing flaky concurrency test is stabilized.
2. UI boundary isolation is explicit and consistent.
3. Strict concurrency diagnostics are improved with no functional regressions.
4. Actor migration decisions are based on measured prototype results, not assumptions.
5. Strict-concurrency diagnostics are continuously enforced in CI.
6. Swift 6 language mode migration is completed only after hotspot cleanup and stable repeated test runs.
