import XCTest
@testable import JJYWave

// MARK: - FrequencyPersistenceTests
/// Tests for UserDefaults-based persistence of the frequency segment selection.
@MainActor
class FrequencyPersistenceTests: XCTestCase {

    private let suiteName = "JJYWave.FrequencyPersistenceTests"
    private let key = "frequencySelectedIndex"
    private var userDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create UserDefaults suite for frequency persistence tests")
        }
        await MainActor.run {
            userDefaults = defaults
            userDefaults.removePersistentDomain(forName: suiteName)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            if let userDefaults = userDefaults {
                userDefaults.removePersistentDomain(forName: suiteName)
            }
            userDefaults = nil
        }
        try await super.tearDown()
    }

    // MARK: - Default / Initial State

    func testNoSavedValueByDefault() {
        XCTAssertNil(userDefaults.object(forKey: key),
                     "Key must not exist before any selection is saved")
    }

    // MARK: - Save / Restore Round-Trip

    func testSaveAndRestoreAllSegmentIndices() {
        for index in 0...4 {
            userDefaults.set(index, forKey: key)
            let restored = userDefaults.integer(forKey: key)
            XCTAssertEqual(restored, index,
                           "Restored index should equal saved value (\(index))")
        }
    }

    func testSavedValuePersistsAfterOverwrite() {
        userDefaults.set(2, forKey: key)
        userDefaults.set(4, forKey: key)
        XCTAssertEqual(userDefaults.integer(forKey: key), 4,
                       "Latest saved value should win")
    }

    func testRemoveObjectClearsKey() {
        userDefaults.set(3, forKey: key)
        userDefaults.removeObject(forKey: key)
        XCTAssertNil(userDefaults.object(forKey: key),
                     "Key should be absent after removal")
    }

    // MARK: - Boundary / Invalid Values

    func testInvalidIndexOutOfRange() {
        // Values outside 0...4 are not saved by ViewController, but test that
        // UserDefaults itself handles them without crashing and that the
        // restored integer matches what was written.
        for invalid in [-1, 5, 999] {
            userDefaults.set(invalid, forKey: key)
            let restored = userDefaults.integer(forKey: key)
            XCTAssertEqual(restored, invalid,
                           "UserDefaults should faithfully round-trip value \(invalid)")
            // Production restore code guards against out-of-range values,
            // so the expected behavior is that they are ignored at restore time.
        }
    }

    // MARK: - Coordinator Integration

    /// Verifies that an allowed frequency change does not produce a revert,
    /// which is the precondition for saving.
    func testAllowedFrequencyChangeDoesNotRevert() {
        let audioGenerator = JJYAudioGenerator()
        let mockFrequencyManager = MockFrequencyManager()
        let mockUIStateManager = MockUIStateManager()
        let mockPresentation = MockPresentationController()

        mockFrequencyManager.validationResult = .allowed

        let coordinator = AudioGeneratorCoordinator(
            audioGenerator: audioGenerator,
            frequencyManager: mockFrequencyManager,
            uiStateManager: mockUIStateManager
        )
        coordinator.setPresentationController(mockPresentation)

        coordinator.handleFrequencyChange(to: 1, currentIndex: 0)

        let revertSelectionWasCalled = mockPresentation.revertSelectionWasCalled
        XCTAssertFalse(revertSelectionWasCalled,
                       "Revert must not be called for an allowed change — save should proceed")
    }

    /// Verifies that a blocked frequency change triggers a revert,
    /// which is the precondition for NOT saving.
    func testBlockedFrequencyChangeTriggersRevert() async {
        let audioGenerator = JJYAudioGenerator()
        let mockFrequencyManager = MockFrequencyManager()
        let mockUIStateManager = MockUIStateManager()
        let mockPresentation = MockPresentationController()

        mockFrequencyManager.validationResult = .blocked("Cannot change while generating")

        let coordinator = AudioGeneratorCoordinator(
            audioGenerator: audioGenerator,
            frequencyManager: mockFrequencyManager,
            uiStateManager: mockUIStateManager
        )
        coordinator.setPresentationController(mockPresentation)
        let revertExpectation = expectation(description: "revert selection callback")
        mockPresentation.onRevertSelection = { [weak mockPresentation] in
            revertExpectation.fulfill()
            mockPresentation?.onRevertSelection = nil
        }

        coordinator.handleFrequencyChange(to: 3, currentIndex: 1)
        await fulfillment(of: [revertExpectation], timeout: 1.0)

        let revertSelectionWasCalled = mockPresentation.revertSelectionWasCalled
        XCTAssertTrue(revertSelectionWasCalled,
                      "Revert must be called for a blocked change — save must not proceed")
    }

    // MARK: - Coordinator Save Condition

    /// Verifies that getSegmentIndex reflects the newly applied index after an allowed change,
    /// matching the condition used by ViewController to decide whether to save.
    func testGetSegmentIndexReflectsAppliedIndexAfterAllowedChange() {
        let audioGenerator = JJYAudioGenerator()
        let mockFrequencyManager = MockFrequencyManager()
        let mockUIStateManager = MockUIStateManager()
        let mockPresentation = MockPresentationController()

        mockFrequencyManager.validationResult = .allowed
        mockFrequencyManager.lastConfiguredIndex = 0

        let coordinator = AudioGeneratorCoordinator(
            audioGenerator: audioGenerator,
            frequencyManager: mockFrequencyManager,
            uiStateManager: mockUIStateManager
        )
        coordinator.setPresentationController(mockPresentation)

        coordinator.handleFrequencyChange(to: 2, currentIndex: 0)

        let appliedIndex = coordinator.frequencyManager.getSegmentIndex(for: audioGenerator)
        XCTAssertEqual(appliedIndex, 2,
                       "appliedIndex must equal the requested index after an allowed change, enabling save")
    }

    /// Verifies that getSegmentIndex stays at the old index after a blocked change,
    /// so that ViewController correctly skips saving.
    func testGetSegmentIndexStaysUnchangedAfterBlockedChange() {
        let audioGenerator = JJYAudioGenerator()
        let mockFrequencyManager = MockFrequencyManager()
        let mockUIStateManager = MockUIStateManager()
        let mockPresentation = MockPresentationController()

        mockFrequencyManager.validationResult = .blocked("Cannot change while generating")
        mockFrequencyManager.lastConfiguredIndex = 1  // original index

        let coordinator = AudioGeneratorCoordinator(
            audioGenerator: audioGenerator,
            frequencyManager: mockFrequencyManager,
            uiStateManager: mockUIStateManager
        )
        coordinator.setPresentationController(mockPresentation)

        coordinator.handleFrequencyChange(to: 3, currentIndex: 1)

        let appliedIndex = coordinator.frequencyManager.getSegmentIndex(for: audioGenerator)
        XCTAssertNotEqual(appliedIndex, 3,
                          "appliedIndex must NOT equal the requested index after a blocked change, preventing save")
        XCTAssertEqual(appliedIndex, 1,
                       "Index should remain unchanged (1) after a blocked change")
    }
}
