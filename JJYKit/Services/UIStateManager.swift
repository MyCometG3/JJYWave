import Foundation
import Cocoa

// MARK: - UIStateManagerProtocol
/// Protocol for managing UI state and presentation logic
protocol UIStateManagerProtocol {
    func updateTimeDisplay() -> String
    func formatButtonTitle(isGenerating: Bool) -> String
    func formatStatusMessage(state: UIState) -> String
}

// MARK: - UIState
enum UIState {
    case ready
    case generating
    case stopped
    case error(String)
    case frequencyChangeBlocked(String)
}

// MARK: - UIStateManager
/// Service responsible for UI state management and formatting
class UIStateManager: UIStateManagerProtocol {
    
    // MARK: - Time Display Management
    func updateTimeDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let format = NSLocalizedString("current_time_format", comment: "Current time label format")
        return String(format: format, formatter.string(from: Date()))
    }
    
    // MARK: - Button State Management
    func formatButtonTitle(isGenerating: Bool) -> String {
        return isGenerating ? 
            NSLocalizedString("stop_generation", comment: "Stop button title") :
            NSLocalizedString("start_generation", comment: "Start button title")
    }
    
    // MARK: - Status Message Management
    func formatStatusMessage(state: UIState) -> String {
        switch state {
        case .ready:
            return NSLocalizedString("ready", comment: "Initial status")
        case .generating:
            return NSLocalizedString("generating", comment: "Generating status")
        case .stopped:
            return NSLocalizedString("stopped", comment: "Stopped status")
        case .error(_):
            return NSLocalizedString("error_failed_to_start", comment: "Generic start error")
        case .frequencyChangeBlocked(let message):
            return message
        }
    }
}

// MARK: - UI Description Management
/// Service for managing UI description text and view hierarchy operations
class UIDescriptionManager {
    
    func updateDescriptionText(in view: NSView) {
        guard let textView = findTextView(in: view) else { return }
        let newText = NSLocalizedString("app_description", comment: "App description text")
        textView.string = newText
        textView.textColor = .secondaryLabelColor
        textView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    
    func adjustDescriptionScrollViewHeight(in view: NSView, minHeight: CGFloat) {
        guard let scrollView = findScrollView(in: view) else { return }
        
        // Update or add height constraint
        if let heightConstraint = scrollView.constraints.first(where: { $0.firstAttribute == .height }) {
            if heightConstraint.constant < minHeight { 
                heightConstraint.constant = minHeight 
            }
        } else {
            let constraint = scrollView.heightAnchor.constraint(equalToConstant: minHeight)
            constraint.priority = .required
            constraint.isActive = true
        }
        
        scrollView.needsLayout = true
    }
    
    // MARK: - Private Helper Methods
    private func findTextView(in view: NSView) -> NSTextView? {
        for subview in view.subviews {
            if let textView = subview as? NSTextView {
                return textView
            }
            if let textView = findTextView(in: subview) {
                return textView
            }
        }
        return nil
    }
    
    private func findScrollView(in view: NSView) -> NSScrollView? {
        for subview in view.subviews {
            if let scrollView = subview as? NSScrollView {
                return scrollView
            }
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }
}