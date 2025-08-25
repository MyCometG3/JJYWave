import XCTest
@testable import JJYWave

class UIStateManagerTests: XCTestCase {
    var uiStateManager: UIStateManager!
    
    override func setUp() {
        super.setUp()
        uiStateManager = UIStateManager()
    }
    
    override func tearDown() {
        uiStateManager = nil
        super.tearDown()
    }
    
    // MARK: - Time Display Tests
    
    func testUpdateTimeDisplayFormat() {
        let timeDisplay = uiStateManager.updateTimeDisplay()
        
        // Should contain current date/time formatted correctly
        XCTAssertFalse(timeDisplay.isEmpty, "Time display should not be empty")
        // Basic format check - should contain numbers and separators
        XCTAssertTrue(timeDisplay.contains("-"), "Should contain date separators")
        XCTAssertTrue(timeDisplay.contains(":"), "Should contain time separators")
    }
    
    // MARK: - Button Title Tests
    
    func testFormatButtonTitleWhenNotGenerating() {
        let title = uiStateManager.formatButtonTitle(isGenerating: false)
        
        // Should return start generation title (actual value depends on localization)
        XCTAssertFalse(title.isEmpty, "Button title should not be empty")
        // This test assumes the localized string exists - in real app would be "Start Generation"
    }
    
    func testFormatButtonTitleWhenGenerating() {
        let title = uiStateManager.formatButtonTitle(isGenerating: true)
        
        // Should return stop generation title (actual value depends on localization)
        XCTAssertFalse(title.isEmpty, "Button title should not be empty")
        // This test assumes the localized string exists - in real app would be "Stop Generation"
    }
    
    // MARK: - Status Message Tests
    
    func testFormatStatusMessageReady() {
        let message = uiStateManager.formatStatusMessage(state: .ready)
        
        XCTAssertFalse(message.isEmpty, "Ready status message should not be empty")
    }
    
    func testFormatStatusMessageGenerating() {
        let message = uiStateManager.formatStatusMessage(state: .generating)
        
        XCTAssertFalse(message.isEmpty, "Generating status message should not be empty")
    }
    
    func testFormatStatusMessageStopped() {
        let message = uiStateManager.formatStatusMessage(state: .stopped)
        
        XCTAssertFalse(message.isEmpty, "Stopped status message should not be empty")
    }
    
    func testFormatStatusMessageError() {
        let errorMessage = "Test error"
        let message = uiStateManager.formatStatusMessage(state: .error(errorMessage))
        
        XCTAssertFalse(message.isEmpty, "Error status message should not be empty")
        // Error state returns generic error message from localization, not the specific error
    }
    
    func testFormatStatusMessageFrequencyChangeBlocked() {
        let blockedMessage = "Frequency change blocked"
        let message = uiStateManager.formatStatusMessage(state: .frequencyChangeBlocked(blockedMessage))
        
        XCTAssertEqual(message, blockedMessage, "Should return the specific blocked message")
    }
}

// MARK: - AudioGeneratorCoordinator Tests
class AudioGeneratorCoordinatorTests: XCTestCase {
    var coordinator: AudioGeneratorCoordinator!
    var mockAudioGenerator: MockJJYAudioGenerator!
    var mockFrequencyManager: MockFrequencyManager!
    var mockUIStateManager: MockUIStateManager!
    var mockPresentationController: MockPresentationController!
    
    override func setUp() {
        super.setUp()
        mockAudioGenerator = MockJJYAudioGenerator()
        mockFrequencyManager = MockFrequencyManager()
        mockUIStateManager = MockUIStateManager()
        mockPresentationController = MockPresentationController()
        
        // Create coordinator with real audio generator for integration testing
        let realAudioGenerator = JJYAudioGenerator()
        coordinator = AudioGeneratorCoordinator(
            audioGenerator: realAudioGenerator,
            frequencyManager: mockFrequencyManager,
            uiStateManager: mockUIStateManager
        )
        coordinator.setPresentationController(mockPresentationController)
        coordinator.setupAudioGeneratorDelegate()
    }
    
    override func tearDown() {
        coordinator = nil
        mockAudioGenerator = nil
        mockFrequencyManager = nil
        mockUIStateManager = nil
        mockPresentationController = nil
        super.tearDown()
    }
    
    // MARK: - Frequency Change Tests
    
    func testHandleFrequencyChangeAllowed() {
        // Setup mocks
        mockFrequencyManager.validationResult = .allowed
        
        coordinator.handleFrequencyChange(to: 1, currentIndex: 0)
        
        XCTAssertTrue(mockFrequencyManager.validateChangeWasCalled, "Should validate frequency change")
        XCTAssertTrue(mockFrequencyManager.configureFrequencyWasCalled, "Should configure frequency when allowed")
        XCTAssertFalse(mockPresentationController.revertSelectionWasCalled, "Should not revert selection when allowed")
    }
    
    func testHandleFrequencyChangeBlocked() {
        // Setup mocks
        mockFrequencyManager.validationResult = .blocked("Test error")
        
        coordinator.handleFrequencyChange(to: 3, currentIndex: 0)
        
        XCTAssertTrue(mockFrequencyManager.validateChangeWasCalled, "Should validate frequency change")
        XCTAssertFalse(mockFrequencyManager.configureFrequencyWasCalled, "Should not configure frequency when blocked")
        XCTAssertTrue(mockPresentationController.revertSelectionWasCalled, "Should revert selection when blocked")
        XCTAssertTrue(mockPresentationController.updateStatusWasCalled, "Should show error message when blocked")
    }
    
    // MARK: - Start/Stop Action Tests
    
    func testHandleStartStopActionWhenInactive() {
        // Test starts generation when inactive
        coordinator.handleStartStopAction()
        
        // Note: Since we're using real JJYAudioGenerator, this will attempt real audio generation
        // In a real test environment, we'd mock the audio generator as well
    }
}

// MARK: - Mock Classes
class MockFrequencyManager: FrequencyManagementProtocol {
    var validateChangeWasCalled = false
    var configureFrequencyWasCalled = false
    var validationResult: FrequencyChangeResult = .allowed
    
    func formatFrequencyDisplay(for generator: AudioGeneratorConfigurationProtocol, sampleRate: Double) -> String {
        return "Mock Frequency Display"
    }
    
    func formatTestFrequency(_ frequency: Double) -> String {
        return "Mock Test Frequency"
    }
    
    func getSegmentIndex(for generator: AudioGeneratorConfigurationProtocol) -> Int {
        return 0
    }
    
    func validateFrequencyChange(from currentIndex: Int, to newIndex: Int, isGenerating: Bool) -> FrequencyChangeResult {
        validateChangeWasCalled = true
        return validationResult
    }
    
    func configureFrequency(for generator: AudioGeneratorConfigurationProtocol, segmentIndex: Int) {
        configureFrequencyWasCalled = true
    }
    
    func createFrequencyConfiguration(for segmentIndex: Int) -> FrequencyConfiguration {
        return FrequencyConfiguration(isTestModeEnabled: true, testFrequency: 13333, band: nil)
    }
}

class MockUIStateManager: UIStateManagerProtocol {
    func updateTimeDisplay() -> String {
        return "Mock Time Display"
    }
    
    func formatButtonTitle(isGenerating: Bool) -> String {
        return isGenerating ? "Mock Stop" : "Mock Start"
    }
    
    func formatStatusMessage(state: UIState) -> String {
        return "Mock Status Message"
    }
}
