import Foundation
@testable import JJYWave

// MARK: - Shared Mock Presentation Controller
/// Shared mock implementation for presentation controller to avoid duplication across test files
class MockPresentationController: PresentationControllerProtocol {
    // MARK: - Call Tracking Properties
    var updateStatusWasCalled = false
    var revertSelectionWasCalled = false
    var updateFrequencyDisplayWasCalled = false
    var updateSegmentSelectionWasCalled = false
    var updateButtonTitleWasCalled = false
    var updateTimeDisplayWasCalled = false
    
    // MARK: - Value Tracking Properties
    var lastStatusMessage: String?
    var lastRevertIndex: Int?
    var lastFrequencyDisplay: String?
    var lastSegmentIndex: Int?
    var lastButtonTitle: String?
    var lastTimeDisplay: String?
    
    // MARK: - PresentationControllerProtocol Implementation
    func updateButtonTitle(_ title: String) {
        updateButtonTitleWasCalled = true
        lastButtonTitle = title
    }
    
    func updateStatusMessage(_ message: String) {
        updateStatusWasCalled = true
        lastStatusMessage = message
    }
    
    func updateTimeDisplay(_ timeString: String) {
        updateTimeDisplayWasCalled = true
        lastTimeDisplay = timeString
    }
    
    func updateFrequencyDisplay(_ frequencyString: String) {
        updateFrequencyDisplayWasCalled = true
        lastFrequencyDisplay = frequencyString
    }
    
    func updateSegmentSelection(_ index: Int) {
        updateSegmentSelectionWasCalled = true
        lastSegmentIndex = index
    }
    
    func revertSegmentSelection(to index: Int) {
        revertSelectionWasCalled = true
        lastRevertIndex = index
    }
    
    // MARK: - Test Helper Methods
    func reset() {
        updateStatusWasCalled = false
        revertSelectionWasCalled = false
        updateFrequencyDisplayWasCalled = false
        updateSegmentSelectionWasCalled = false
        updateButtonTitleWasCalled = false
        updateTimeDisplayWasCalled = false
        
        lastStatusMessage = nil
        lastRevertIndex = nil
        lastFrequencyDisplay = nil
        lastSegmentIndex = nil
        lastButtonTitle = nil
        lastTimeDisplay = nil
    }
}
