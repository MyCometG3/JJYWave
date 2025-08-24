import Foundation

// MARK: - AudioGeneratorConfigurationProtocol
/// Protocol for configuring audio generator frequency settings
protocol AudioGeneratorConfigurationProtocol: AnyObject {
    var isTestModeEnabled: Bool { get set }
    var testFrequency: Double { get }
    var band: JJYAudioGenerator.CarrierBand { get }
    
    func updateTestFrequency(_ frequency: Double)
    func updateBand(_ newBand: JJYAudioGenerator.CarrierBand) -> Bool
}

// MARK: - JJYAudioGenerator Extension
extension JJYAudioGenerator: AudioGeneratorConfigurationProtocol {
    // Already implements all required methods and properties
}
