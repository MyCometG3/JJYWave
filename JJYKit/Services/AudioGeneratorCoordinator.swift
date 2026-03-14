import Foundation
import Cocoa

// MARK: - PresentationControllerProtocol
/// Protocol for presentation layer to reduce coupling with business logic
@MainActor
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
@preconcurrency
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
    
    // MARK: - Initialization
    init(audioGenerator: JJYAudioGenerator,
         frequencyManager: FrequencyManagementProtocol = FrequencyManagementService(),
         uiStateManager: UIStateManagerProtocol = UIStateManager(),
         presentationController: PresentationControllerProtocol? = nil) {
        self.audioGenerator = audioGenerator
        self.frequencyManager = frequencyManager
        self.uiStateManager = uiStateManager
        self.presentationController = presentationController
        
        // Note: Set up audio generator delegate externally after initialization to avoid tight coupling.
        // Call setupAudioGeneratorDelegate() after initialization.
    }
    
    // MARK: - Configuration
    func setupAudioGeneratorDelegate() {
        self.audioGenerator.delegate = self
    }
    
    @MainActor
    func setPresentationController(_ controller: PresentationControllerProtocol) {
        self.presentationController = controller
    }

    private func performPresentationUpdate(_ update: @escaping @MainActor (PresentationControllerProtocol) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                guard let presentationController = self.presentationController else { return }
                update(presentationController)
            }
            return
        }

        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                guard let presentationController = self.presentationController else { return }
                update(presentationController)
            }
        }
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
            performPresentationUpdate { presentationController in
                presentationController.revertSegmentSelection(to: currentIndex)
            }
            if let errorMessage = validationResult.errorMessage {
                performPresentationUpdate { presentationController in
                    presentationController.updateStatusMessage(errorMessage)
                }
            }
            return
        }
        
        // Apply frequency change
        frequencyManager.configureFrequency(for: audioGenerator, segmentIndex: newIndex)
        // Update UI
        refreshUIState()
    }
    
    func refreshUIState() {
        let frequencyDisplay = frequencyManager.formatFrequencyDisplay(for: audioGenerator, sampleRate: audioGenerator.sampleRate)
        let segmentIndex = frequencyManager.getSegmentIndex(for: audioGenerator)
        let buttonTitle = uiStateManager.formatButtonTitle(isGenerating: audioGenerator.isActive)
        let timeDisplay = uiStateManager.updateTimeDisplay()

        performPresentationUpdate { presentationController in
            presentationController.updateFrequencyDisplay(frequencyDisplay)
            presentationController.updateSegmentSelection(segmentIndex)
            presentationController.updateButtonTitle(buttonTitle)
            presentationController.updateTimeDisplay(timeDisplay)
        }
    }
}

// MARK: - JJYAudioGeneratorDelegate
@MainActor
extension AudioGeneratorCoordinator: JJYAudioGeneratorDelegate {
    func audioGeneratorDidStart() {
        let buttonTitle = uiStateManager.formatButtonTitle(isGenerating: true)
        let statusMessage = uiStateManager.formatStatusMessage(state: .generating)

        presentationController?.updateButtonTitle(buttonTitle)
        presentationController?.updateStatusMessage(statusMessage)
    }
    
    func audioGeneratorDidStop() {
        let buttonTitle = uiStateManager.formatButtonTitle(isGenerating: false)
        let statusMessage = uiStateManager.formatStatusMessage(state: .stopped)

        presentationController?.updateButtonTitle(buttonTitle)
        presentationController?.updateStatusMessage(statusMessage)
    }
    
    func audioGeneratorDidEncounterError(_ error: String) {
        let statusMessage = uiStateManager.formatStatusMessage(state: .error(error))

        presentationController?.updateStatusMessage(statusMessage)
    }
}
