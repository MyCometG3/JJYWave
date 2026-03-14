import XCTest
@testable import JJYWave

@MainActor
class ModularArchitectureIntegrationTests: XCTestCase {
    var audioGenerator: JJYAudioGenerator!
    var coordinator: AudioGeneratorCoordinator!
    var mockPresentationController: MockPresentationController!
    
    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            // Use real audio generator with mock audio engine for testing
            let mockAudioEngine = MockAudioEngine()
            audioGenerator = JJYAudioGenerator(audioEngine: mockAudioEngine)

            mockPresentationController = MockPresentationController()

            // Initialize coordinator without automatic delegate setup (weak reference pattern)
            coordinator = AudioGeneratorCoordinator(audioGenerator: audioGenerator)
            coordinator.setPresentationController(mockPresentationController)
            coordinator.setupAudioGeneratorDelegate()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            coordinator = nil
            audioGenerator = nil
            mockPresentationController = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteFrequencyChangeWorkflow() {
        // Initial state should be test mode
        XCTAssertTrue(audioGenerator.isTestModeEnabled, "Should start in test mode")
        
        // Test frequency change to 15 kHz
        coordinator.handleFrequencyChange(to: 1, currentIndex: 0)
        
        XCTAssertEqual(audioGenerator.testFrequency, 15000, "Should update to 15 kHz")
        XCTAssertTrue(audioGenerator.isTestModeEnabled, "Should remain in test mode")
        
        // Test frequency change to JJY40 (should be allowed when not generating)
        coordinator.handleFrequencyChange(to: 3, currentIndex: 1)
        
        XCTAssertFalse(audioGenerator.isTestModeEnabled, "Should switch to JJY mode")
        XCTAssertEqual(audioGenerator.band, .jjy40, "Should switch to JJY40")
    }
    
    func testFrequencyChangeBlockedWhileGenerating() async {
        // Start generation
        coordinator.handleStartStopAction()
        
        // Verify generation started
        XCTAssertTrue(audioGenerator.isActive, "Should be generating")

        let revertExpectation = expectation(description: "revert selection callback")
        let statusExpectation = expectation(description: "status callback")
        mockPresentationController.onRevertSelection = { [weak mockPresentationController] in
            revertExpectation.fulfill()
            mockPresentationController?.onRevertSelection = nil
        }
        mockPresentationController.onUpdateStatus = { [weak mockPresentationController] in
            statusExpectation.fulfill()
            mockPresentationController?.onUpdateStatus = nil
        }
        
        // Try to change to JJY60 while generating (should be blocked)
        coordinator.handleFrequencyChange(to: 4, currentIndex: 0)
        await fulfillment(of: [revertExpectation, statusExpectation], timeout: 1.0)
        
        // Verify change was blocked
        let revertSelectionWasCalled = mockPresentationController.revertSelectionWasCalled
        let updateStatusWasCalled = mockPresentationController.updateStatusWasCalled
        XCTAssertTrue(revertSelectionWasCalled, "Should revert selection")
        XCTAssertTrue(updateStatusWasCalled, "Should show error message")
        
        // Verify frequency didn't change
        XCTAssertTrue(audioGenerator.isTestModeEnabled, "Should remain in test mode")
    }
    
    func testUIStateUpdatesCorrectly() async {
        let frequencyExpectation = expectation(description: "frequency display callback")
        let segmentExpectation = expectation(description: "segment selection callback")
        let buttonExpectation = expectation(description: "button title callback")
        let timeExpectation = expectation(description: "time display callback")
        mockPresentationController.onUpdateFrequencyDisplay = { [weak mockPresentationController] in
            frequencyExpectation.fulfill()
            mockPresentationController?.onUpdateFrequencyDisplay = nil
        }
        mockPresentationController.onUpdateSegmentSelection = { [weak mockPresentationController] in
            segmentExpectation.fulfill()
            mockPresentationController?.onUpdateSegmentSelection = nil
        }
        mockPresentationController.onUpdateButtonTitle = { [weak mockPresentationController] in
            buttonExpectation.fulfill()
            mockPresentationController?.onUpdateButtonTitle = nil
        }
        mockPresentationController.onUpdateTimeDisplay = { [weak mockPresentationController] in
            timeExpectation.fulfill()
            mockPresentationController?.onUpdateTimeDisplay = nil
        }

        // Refresh UI state
        coordinator.refreshUIState()
        await fulfillment(of: [frequencyExpectation, segmentExpectation, buttonExpectation, timeExpectation], timeout: 1.0)
        
        // Verify UI updates were called
        let updateFrequencyDisplayWasCalled = mockPresentationController.updateFrequencyDisplayWasCalled
        let updateSegmentSelectionWasCalled = mockPresentationController.updateSegmentSelectionWasCalled
        let updateButtonTitleWasCalled = mockPresentationController.updateButtonTitleWasCalled
        let updateTimeDisplayWasCalled = mockPresentationController.updateTimeDisplayWasCalled
        XCTAssertTrue(updateFrequencyDisplayWasCalled, "Should update frequency display")
        XCTAssertTrue(updateSegmentSelectionWasCalled, "Should update segment selection")
        XCTAssertTrue(updateButtonTitleWasCalled, "Should update button title")
        XCTAssertTrue(updateTimeDisplayWasCalled, "Should update time display")
    }
    
    func testStartStopWorkflow() {
        // Initial state
        XCTAssertFalse(audioGenerator.isActive, "Should not be generating initially")
        
        // Start generation
        coordinator.handleStartStopAction()
        XCTAssertTrue(audioGenerator.isActive, "Should be generating after start")
        
        // Stop generation
        coordinator.handleStartStopAction()
        XCTAssertFalse(audioGenerator.isActive, "Should not be generating after stop")
    }
    
    // MARK: - Service Integration Tests
    
    func testFrequencyServiceIntegration() {
        let frequencyService = FrequencyManagementService()
        
        // Test with real audio generator
        audioGenerator.isTestModeEnabled = true
        audioGenerator.updateTestFrequency(13333)
        
        let segmentIndex = frequencyService.getSegmentIndex(for: audioGenerator)
        XCTAssertEqual(segmentIndex, 0, "Should return correct segment index for 13333 Hz")
        
        let frequencyDisplay = frequencyService.formatFrequencyDisplay(for: audioGenerator, sampleRate: audioGenerator.sampleRate)
        XCTAssertFalse(frequencyDisplay.isEmpty, "Should return formatted frequency display")
    }
    
    func testUIStateServiceIntegration() {
        let uiStateService = UIStateManager()
        
        let timeDisplay = uiStateService.updateTimeDisplay()
        XCTAssertFalse(timeDisplay.isEmpty, "Should return formatted time display")
        
        let buttonTitle = uiStateService.formatButtonTitle(isGenerating: false)
        XCTAssertFalse(buttonTitle.isEmpty, "Should return button title")
        
        let statusMessage = uiStateService.formatStatusMessage(state: .ready)
        XCTAssertFalse(statusMessage.isEmpty, "Should return status message")
    }
    
    // MARK: - Protocol Abstraction Tests
    
    func testAudioEngineAbstraction() {
        // Verify that the audio generator is using the mock audio engine
        // This is validated by the fact that audio generation works in tests
        // without requiring actual audio hardware
        
        coordinator.handleStartStopAction()
        
        // If abstraction works, this should not crash in test environment
        XCTAssertTrue(audioGenerator.isActive, "Should work with mock audio engine")
    }
    
    func testConfigurationProtocolAbstraction() {
        let frequencyService = FrequencyManagementService()
        
        // Test that frequency service works with the protocol abstraction
        frequencyService.configureFrequency(for: audioGenerator, segmentIndex: 2)
        
        XCTAssertTrue(audioGenerator.isTestModeEnabled, "Should configure test mode")
        XCTAssertEqual(audioGenerator.testFrequency, 20000, "Should configure 20 kHz")
    }
    
    // MARK: - Thread Safety Integration
    
    func testConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations should complete")
        let group = DispatchGroup()
        let coordinator = self.coordinator!
        
        // Test concurrent frequency changes
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                coordinator.handleFrequencyChange(to: i % 3, currentIndex: 0)
                group.leave()
            }
        }
        
        // Test concurrent UI updates
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                coordinator.refreshUIState()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        XCTAssertTrue(true, "Concurrent operations should complete without crashes")
    }
}
