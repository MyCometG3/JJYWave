import Foundation
import AVFoundation

// MARK: - AudioEngineProtocol
/// Protocol abstraction for audio engine to improve testability and reduce coupling
protocol AudioEngineProtocol: AnyObject {
    // MARK: - State Properties
    var isEngineRunning: Bool { get }
    var isPlayerPlaying: Bool { get }
    
    // MARK: - Setup and Configuration
    func setupAudioEngine(sampleRate: Double, channelCount: AVAudioChannelCount)
    
    // MARK: - Lifecycle Management
    func startEngine() -> Bool
    func stopEngine()
    func startPlayer()
    func stopPlayer()
    
    // MARK: - Audio Scheduling
    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, completionHandler: AVAudioNodeCompletionHandler?)

    // MARK: - Hardware Interaction
    func trySetHardwareSampleRate(_ desired: Double) -> Bool
    
    // MARK: - Format Retrieval
    func getPlayerFormat() -> AVAudioFormat?
}

// MARK: - AudioEngine Conformance
extension AudioEngine: AudioEngineProtocol {
    // AudioEngine already implements all required methods
    // This extension makes it conform to the protocol
}