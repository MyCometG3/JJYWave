# Swift Concurrency Review and Improvement Plan (Swift 6)

## Scope

This document is a revised, implementation-focused proposal for improving concurrency in **JJYWave**.
It replaces earlier generic guidance with recommendations validated against the current codebase.

## Review Summary

After reviewing the branch and repository, these are the key findings:

1. The project is currently **GCD-first** (`DispatchQueue`, `DispatchSourceTimer`, `DispatchQueue.main.async`) and does not yet use Swift structured concurrency (`async/await`, `Task`, `actor`) in production code.
2. There is **no existing Swift concurrency proposal file** in the repo; this document is added as the authoritative version.
3. Thread safety is currently achieved with private serial queues (for example in `JJYAudioGenerator`, `AudioEngine`, `TransmissionScheduler`), which works, but increases complexity and makes correctness harder to reason about over time.
4. UI updates are manually dispatched to main queue in many places; this is a good candidate for `@MainActor` isolation.

## Why the Prior Proposal Needed Correction

The prior draft contained suggestions that were either too generic or not aligned with this codebase.
Specific issues:

- It assumed existing heavy use of `Task`, `TaskGroup`, `TaskLocal`, and continuations, but those patterns are mostly not present.
- It overemphasized APIs not needed for this app's current architecture.
- It lacked a staged migration plan and clear file-by-file implementation targets.

This revision focuses on practical, low-risk migration steps for the current code.

## Codebase-Constrained Recommendations

### A. Introduce Actor/Global Actor Boundaries Deliberately

#### Target files

- `App/ViewController.swift`
- `JJYKit/Services/AudioGeneratorCoordinator.swift`

#### Recommendation

1. Annotate UI-facing types/functions with `@MainActor`.
2. Remove repetitive `DispatchQueue.main.async` calls where main-actor isolation already guarantees correctness.

#### Expected impact

- Safer UI updates.
- Less boilerplate and fewer accidental off-main UI accesses.

---

### B. Convert Queue-Owned Mutable State to Actors (Phase 2)

#### Candidate types

- `JJYKit/Time/TransmissionScheduler.swift`
- `JJYKit/Audio/AudioEngine.swift`
- `JJYKit/Generator/JJYAudioGenerator.swift`

#### Recommendation

Migrate one component at a time from manual serial queue synchronization to actor isolation.

Example migration direction:

- `TransmissionScheduler` -> `actor TransmissionScheduler`
- Convert internal mutating methods to actor-isolated methods.
- Keep AVAudio scheduling delegate protocol boundaries explicit and minimal.

#### Expected impact

- Centralized state isolation enforced by compiler.
- Fewer queue reentrancy edge cases.

---

### C. Keep Real-Time Audio Path Deterministic

The app has audio scheduling constraints. Not all code should be converted to arbitrary `Task` usage.

#### Recommendation

1. Preserve deterministic scheduling in audio-critical paths.
2. Introduce structured concurrency around orchestration and state transitions, not inside timing-critical callbacks unless measured safe.
3. Avoid `Task.detached` in audio pipeline unless a strong reason exists.

#### Expected impact

- Concurrency modernization without real-time regressions.

---

### D. Replace Callback-Style Main Thread Dispatch with Main-Actor Methods

#### Current pattern

- `DispatchQueue.main.async { ... }` appears repeatedly in:
  - `App/ViewController.swift`
  - `JJYKit/Services/AudioGeneratorCoordinator.swift`
  - `JJYKit/Generator/JJYAudioGenerator.swift`

#### Recommendation

Refactor to:

- `@MainActor` methods for UI/presentation updates.
- `await MainActor.run { ... }` only when crossing from non-main contexts.

#### Expected impact

- Stronger compile-time guarantees.
- Clearer ownership of UI mutations.

---

### E. Strengthen Sendable and Isolation Annotations (Swift 6 readiness)

#### Recommendation

1. Audit closure parameters that cross concurrency domains; add `@Sendable` where appropriate.
2. For shared immutable value types used across tasks/actors, add `Sendable` conformance where valid.
3. Enable strict concurrency checking in build settings and resolve warnings incrementally.

#### Expected impact

- Better Swift 6 diagnostics.
- Earlier detection of unsafe captures.

## Detailed Implementation Plan

## Phase 0: Baseline and Safety Net

1. Enable Swift 6 strict concurrency warnings in project settings.
2. Run full test suite and record baseline timing for key audio/scheduler tests.
3. Add/extend tests for thread and state transitions before migration.

Exit criteria:

- Baseline tests are green.
- Baseline performance metrics captured.

---

## Phase 1: UI/MainActor Cleanup (Low risk, high value)

1. Mark `ViewController` UI update methods as `@MainActor` (or type-level if acceptable).
2. Mark `AudioGeneratorCoordinator` presentation update paths as `@MainActor`.
3. Remove redundant `DispatchQueue.main.async` wrappers where isolation already guarantees main-thread execution.

Suggested file edits:

- `App/ViewController.swift`
- `JJYKit/Services/AudioGeneratorCoordinator.swift`

Validation:

- Build without main-thread warnings.
- UI tests and manual smoke test (start/stop, frequency switching).

---

## Phase 2: Scheduler Isolation Migration (Moderate risk)

1. Convert `TransmissionScheduler` to actor-based state ownership.
2. Keep external delegate interface stable initially to reduce churn.
3. Replace queue-specific checks (`DispatchQueue.getSpecific`) with actor-isolated logic.
4. Re-run scheduler drift and boundary tests.

Suggested file edits:

- `JJYKit/Time/TransmissionScheduler.swift`
- `Tests/TransmissionSchedulerTests.swift`
- `Tests/ThreadSafetyTests.swift`

Validation:

- No regressions in minute rollover and drift handling tests.
- Comparable or improved scheduling determinism.

---

## Phase 3: Generator/Engine Isolation Hardening (Higher risk)

1. Introduce actor-backed state container(s) for `JJYAudioGenerator` and/or `AudioEngine`.
2. Separate real-time callback execution path from orchestration/state mutation path.
3. Remove legacy queue synchronization only after parity is confirmed.

Suggested file edits:

- `JJYKit/Generator/JJYAudioGenerator.swift`
- `JJYKit/Audio/AudioEngine.swift`
- `JJYKit/Audio/AudioEngineProtocol.swift`
- related tests under `Tests/`

Validation:

- Audio start/stop reliability unchanged.
- No buffer scheduling regressions.
- Stress tests remain stable.

---

## Phase 4: Sendable + Diagnostics Closure

1. Add `@Sendable` to escaping closures crossing async boundaries.
2. Add `Sendable` conformance for safe value types.
3. Resolve all remaining strict concurrency warnings.
4. Document rules in README ("Concurrency Guidelines").

Validation:

- Zero strict-concurrency warnings in CI.
- Documentation updated.

## Recommended PR Breakdown

To reduce risk, use multiple PRs:

1. PR-1: MainActor/UI cleanup only.
2. PR-2: TransmissionScheduler isolation migration.
3. PR-3: Generator/Engine isolation improvements.
4. PR-4: Sendable audit + docs.

## Risk Register

- **Audio timing regressions**: mitigate with benchmark/stress tests and phased rollout.
- **Behavioral drift during actor migration**: keep public interfaces stable while migrating internals.
- **Test flakiness**: update tests to avoid race-prone assumptions tied to queue timing.

## Definition of Done

1. Strict concurrency checks enabled and clean.
2. UI code main-actor isolated.
3. At least one core stateful component migrated from serial queue synchronization to actor isolation.
4. No regression in audio and scheduler integration tests.
5. README includes a short concurrency guideline section.

## Appendix: Concrete Next Actions

Immediate next steps (recommended order):

1. Implement Phase 1 in `App/ViewController.swift` and `JJYKit/Services/AudioGeneratorCoordinator.swift`.
2. Add a focused PR with test evidence.
3. Start Phase 2 migration for `TransmissionScheduler` behind tests.
