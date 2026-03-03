# Branch Review Follow-up Plan

## Objectives
1. Clarify the review by keeping only the valid issues (unused `previousSelectedIndex`, timing-sensitive tests, missing device-failure coverage) and dropping the invalid ones (scheduler race, audio engine sample rate race, stale `isGenerating`).
2. Provide Copilot with a structured set of implementation steps for the remaining actionable items.

## Steps for Copilot
1. **Remove dead state in `AudioGeneratorCoordinator`.** Drop `previousSelectedIndex` since it is assigned but never read; confirm no downstream reliance before deleting.
2. **Stabilize timing-dependent tests.** Replace `usleep`/`DispatchQueue.main.asyncAfter` waits in `AudioEngineQualityTests` (and the other timing-heavy suites) with `XCTestExpectation`-based synchronization so CI deterministically waits for each asynchronous phase.
3. **Add hardware-failure scenarios.** Introduce mocks or stubs in `AudioEngineProtocol` tests (and possibly scheduler tests) that simulate device disconnection, inability to start, or timeline jumps to ensure the production code handles those states gracefully.
4. **Document verification results.** Update the review summary (in this plan or the eventual review doc) to explain why the previously flagged issues were false positives so the next reader understands what was validated.

## Deliverables
- `AudioGeneratorCoordinator.swift`: cleaned state property.
- `Tests/AudioEngineQualityTests.swift` (and related timing tests): refactored expectations to avoid `sleep`.
- New or extended tests/mocks that exercise device failure/error handling paths.
- Updated review notes summarizing verified issues and remaining action items.
