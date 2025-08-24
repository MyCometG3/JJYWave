import Foundation
import Cocoa

// MARK: - PresentationControllerProtocol
/// Protocol for presentation layer to reduce coupling with business logic
protocol PresentationControllerProtocol: AnyObject {
    func updateButtonTitle(_ title: String)
    func updateStatusMessage(_ message: String)
    func updateTimeDisplay(_ timeString: String)
    func updateFrequencyDisplay(_ frequencyString: String)
    func updateSegmentSelection(_ index: Int)
    func revertSegmentSelection(to index: Int)
}

// MARK: - AudioGeneratorCoordinatorProtocol
/// Protocol for coordinating audio generation with presentation layer
protocol AudioGeneratorCoordinatorProtocol {
    var frequencyManager: FrequencyManagementProtocol { get }
    var uiStateManager: UIStateManagerProtocol { get }
    
    func handleStartStopAction()
    func handleFrequencyChange(to newIndex: Int, currentIndex: Int)
    func refreshUIState()
}

// MARK: - AudioGeneratorCoordinator
/// Coordinator that manages the interaction between audio generation and presentation
class AudioGeneratorCoordinator: AudioGeneratorCoordinatorProtocol {
    
    // MARK: - Dependencies
    private let audioGenerator: JJYAudioGenerator
    let frequencyManager: FrequencyManagementProtocol
    let uiStateManager: UIStateManagerProtocol
    private weak var presentationController: PresentationControllerProtocol?
    
    // MARK: - State
    private var previousSelectedIndex: Int = 0
    
    // MARK: - Initialization
    init(audioGenerator: JJYAudioGenerator,
         frequencyManager: FrequencyManagementProtocol = FrequencyManagementService(),
         uiStateManager: UIStateManagerProtocol = UIStateManager(),
         presentationController: PresentationControllerProtocol? = nil) {
        self.audioGenerator = audioGenerator
        self.frequencyManager = frequencyManager
        self.uiStateManager = uiStateManager
        self.presentationController = presentationController
        
        // Set up audio generator delegate
        self.audioGenerator.delegate = self
    }
    
    func setPresentationController(_ controller: PresentationControllerProtocol) {
        self.presentationController = controller
    }
    
    // MARK: - Public Methods
    func handleStartStopAction() {
        if audioGenerator.isActive {
            audioGenerator.stopGeneration()
        } else {
            audioGenerator.startGeneration()
        }
    }
    
    func handleFrequencyChange(to newIndex: Int, currentIndex: Int) {
        // Validate the frequency change
        let validationResult = frequencyManager.validateFrequencyChange(
            from: currentIndex, 
            to: newIndex, 
            isGenerating: audioGenerator.isActive
        )
        
        if !validationResult.isAllowed {
            // Revert segment selection and show error
            presentationController?.revertSegmentSelection(to: currentIndex)
            if let errorMessage = validationResult.errorMessage {
                presentationController?.updateStatusMessage(errorMessage)
            }
            return
        }
        
        // Apply frequency change
        frequencyManager.configureFrequency(for: audioGenerator, segmentIndex: newIndex)
        previousSelectedIndex = newIndex
        
        // Update UI
        refreshUIState()
    }
    
    func refreshUIState() {
        // Update frequency display
        let frequencyDisplay = frequencyManager.formatFrequencyDisplay(for: audioGenerator)
        presentationController?.updateFrequencyDisplay(frequencyDisplay)
        
        // Update segment selection
        let segmentIndex = frequencyManager.getSegmentIndex(for: audioGenerator)
        presentationController?.updateSegmentSelection(segmentIndex)
        
        // Update button title
        let buttonTitle = uiStateManager.formatButtonTitle(isGenerating: audioGenerator.isActive)
        presentationController?.updateButtonTitle(buttonTitle)
        
        // Update time display
        let timeDisplay = uiStateManager.updateTimeDisplay()
        presentationController?.updateTimeDisplay(timeDisplay)
    }
}

// MARK: - JJYAudioGeneratorDelegate
extension AudioGeneratorCoordinator: JJYAudioGeneratorDelegate {
    func audioGeneratorDidStart() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let buttonTitle = self.uiStateManager.formatButtonTitle(isGenerating: true)
            let statusMessage = self.uiStateManager.formatStatusMessage(state: .generating)
            
            self.presentationController?.updateButtonTitle(buttonTitle)
            self.presentationController?.updateStatusMessage(statusMessage)
        }
    }
    
    func audioGeneratorDidStop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let buttonTitle = self.uiStateManager.formatButtonTitle(isGenerating: false)
            let statusMessage = self.uiStateManager.formatStatusMessage(state: .stopped)
            
            self.presentationController?.updateButtonTitle(buttonTitle)
            self.presentationController?.updateStatusMessage(statusMessage)
        }
    }
    
    func audioGeneratorDidEncounterError(_ error: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let statusMessage = self.uiStateManager.formatStatusMessage(state: .error(error))
            
            self.presentationController?.updateStatusMessage(statusMessage)
        }
    }
}