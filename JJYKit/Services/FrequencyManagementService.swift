import Foundation

// MARK: - FrequencyManagementProtocol
/// Protocol for managing frequency calculations and formatting
protocol FrequencyManagementProtocol {
    func formatFrequencyDisplay(for generator: AudioGeneratorConfigurationProtocol, sampleRate: Double) -> String
    func formatTestFrequency(_ frequency: Double) -> String
    func getSegmentIndex(for generator: AudioGeneratorConfigurationProtocol) -> Int
    func validateFrequencyChange(from currentIndex: Int, to newIndex: Int, isGenerating: Bool) -> FrequencyChangeResult
    func configureFrequency(for generator: AudioGeneratorConfigurationProtocol, segmentIndex: Int)
}

// MARK: - FrequencyChangeResult
struct FrequencyChangeResult {
    let isAllowed: Bool
    let errorMessage: String?
    
    static let allowed = FrequencyChangeResult(isAllowed: true, errorMessage: nil)
    
    static func blocked(_ message: String) -> FrequencyChangeResult {
        return FrequencyChangeResult(isAllowed: false, errorMessage: message)
    }
}

// MARK: - FrequencyManagementService
/// Service responsible for frequency calculations, formatting, and validation
class FrequencyManagementService: FrequencyManagementProtocol {
    
    // MARK: - Constants
    private struct FrequencyConstants {
        static let testFrequency13kHz: Double = 13333
        static let testFrequency15kHz: Double = 15000
        static let testFrequency20kHz: Double = 20000
        static let jjy40Frequency: Double = 40000
        static let jjy60Frequency: Double = 60000
        static let tolerance: Double = 0.5
    }
    
    // MARK: - Frequency Display Formatting
    func formatFrequencyDisplay(for generator: AudioGeneratorConfigurationProtocol, sampleRate: Double) -> String {
        let freqText: String
        if generator.isTestModeEnabled {
            let suffix = NSLocalizedString("test_mode_suffix", comment: "Test mode suffix")
            freqText = "\(formatTestFrequency(generator.testFrequency)) (\(suffix))"
        } else {
            let jjy60 = NSLocalizedString("jjy60_label", comment: "JJY60 label")
            let jjy40 = NSLocalizedString("jjy40_label", comment: "JJY40 label")
            freqText = (generator.band == .jjy60) ? "60.000 kHz (\(jjy60))" : "40.000 kHz (\(jjy40))"
        }
        let srK = Int((sampleRate / 1000.0).rounded())
        let format = NSLocalizedString("frequency_display_format", comment: "Frequency label format")
        return String(format: format, freqText, srK)
    }
    
    func formatTestFrequency(_ frequency: Double) -> String {
        let khz = frequency / 1000.0
        return String(format: "%.3f kHz", khz)
    }
    
    // MARK: - Segment Index Calculation
    func getSegmentIndex(for generator: AudioGeneratorConfigurationProtocol) -> Int {
        if generator.isTestModeEnabled {
            let tf = generator.testFrequency
            if abs(tf - FrequencyConstants.testFrequency13kHz) < FrequencyConstants.tolerance {
                return 0
            } else if abs(tf - FrequencyConstants.testFrequency15kHz) < FrequencyConstants.tolerance {
                return 1
            } else if abs(tf - FrequencyConstants.testFrequency20kHz) < FrequencyConstants.tolerance {
                return 2
            } else {
                return 0 // Default to first test frequency
            }
        } else {
            return (generator.band == .jjy60) ? 4 : 3
        }
    }
    
    // MARK: - Frequency Change Validation
    func validateFrequencyChange(from currentIndex: Int, to newIndex: Int, isGenerating: Bool) -> FrequencyChangeResult {
        // Allow test frequency changes anytime
        if newIndex < 3 {
            return .allowed
        }
        
        // Block JJY frequency changes while generating
        if isGenerating {
            let message = (newIndex == 3) ? 
                NSLocalizedString("change_to_jjy40_blocked", comment: "Block switching to 40 kHz while active") :
                NSLocalizedString("change_to_jjy60_blocked", comment: "Block switching to 60 kHz while active")
            return .blocked(message)
        }
        
        return .allowed
    }
    
    // MARK: - Frequency Configuration
    func configureFrequency(for generator: AudioGeneratorConfigurationProtocol, segmentIndex: Int) {
        switch segmentIndex {
        case 0: // 13.333 kHz Test
            generator.isTestModeEnabled = true
            generator.updateTestFrequency(FrequencyConstants.testFrequency13kHz)
        case 1: // 15.000 kHz Test
            generator.isTestModeEnabled = true
            generator.updateTestFrequency(FrequencyConstants.testFrequency15kHz)
        case 2: // 20.000 kHz Test
            generator.isTestModeEnabled = true
            generator.updateTestFrequency(FrequencyConstants.testFrequency20kHz)
        case 3: // JJY40 40 kHz
            generator.isTestModeEnabled = false
            _ = generator.updateBand(.jjy40)
        case 4: // JJY60 60 kHz
            generator.isTestModeEnabled = false
            _ = generator.updateBand(.jjy60)
        default:
            break
        }
    }
}