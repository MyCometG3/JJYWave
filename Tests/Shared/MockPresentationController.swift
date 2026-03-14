import Foundation
@testable import JJYWave

// MARK: - Shared Mock Presentation Controller
/// Shared mock implementation for presentation controller to avoid duplication across test files
@MainActor
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

    // MARK: - Callback Hooks
    var onUpdateStatus: (() -> Void)?
    var onRevertSelection: (() -> Void)?
    var onUpdateFrequencyDisplay: (() -> Void)?
    var onUpdateSegmentSelection: (() -> Void)?
    var onUpdateButtonTitle: (() -> Void)?
    var onUpdateTimeDisplay: (() -> Void)?
    
    // MARK: - PresentationControllerProtocol Implementation
    func updateButtonTitle(_ title: String) {
        updateButtonTitleWasCalled = true
        lastButtonTitle = title
        onUpdateButtonTitle?()
    }
    
    func updateStatusMessage(_ message: String) {
        updateStatusWasCalled = true
        lastStatusMessage = message
        onUpdateStatus?()
    }
    
    func updateTimeDisplay(_ timeString: String) {
        updateTimeDisplayWasCalled = true
        lastTimeDisplay = timeString
        onUpdateTimeDisplay?()
    }
    
    func updateFrequencyDisplay(_ frequencyString: String) {
        updateFrequencyDisplayWasCalled = true
        lastFrequencyDisplay = frequencyString
        onUpdateFrequencyDisplay?()
    }
    
    func updateSegmentSelection(_ index: Int) {
        updateSegmentSelectionWasCalled = true
        lastSegmentIndex = index
        onUpdateSegmentSelection?()
    }
    
    func revertSegmentSelection(to index: Int) {
        revertSelectionWasCalled = true
        lastRevertIndex = index
        onRevertSelection?()
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

        onUpdateStatus = nil
        onRevertSelection = nil
        onUpdateFrequencyDisplay = nil
        onUpdateSegmentSelection = nil
        onUpdateButtonTitle = nil
        onUpdateTimeDisplay = nil
    }
}
