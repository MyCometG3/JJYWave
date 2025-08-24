//
//  AudioEngineQualityTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Additional audio engine quality and safety tests
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class AudioEngineQualityTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
    }
    
    override func tearDown() {
        audioEngine?.stopEngine()
        audioEngine = nil
        super.tearDown()
    }
    
    // MARK: - Safety Tests
    
    func testEngineOperationsBeforeSetup() {
        // Test that operations are safe before setup
        XCTAssertFalse(audioEngine.isEngineRunning, "Engine should not be running before setup")
        XCTAssertFalse(audioEngine.isPlayerPlaying, "Player should not be playing before setup")
        
        // These should not crash
        XCTAssertNoThrow(audioEngine.stopEngine())
        
        // Starting without setup should fail
        let success = audioEngine.startEngine()
        XCTAssertFalse(success, "Starting without setup should fail")
    }
    
    func testMultipleSetupCalls() {
        // Multiple setup calls should be safe
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2))
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 48000, channelCount: 1))
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2))
    }
    
    func testInvalidAudioFormats() {
        // Test with extreme values
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 8000, channelCount: 1))   // Very low
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 192000, channelCount: 8)) // Very high
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 44100, channelCount: 2))  // Standard
    }
    
    func testEngineStartStopCycles() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        // Multiple start/stop cycles should be safe
        for _ in 0..<5 {
            let success = audioEngine.startEngine()
            XCTAssertTrue(success, "Engine should start successfully")
            XCTAssertTrue(audioEngine.isEngineRunning, "Engine should be running after start")
            
            audioEngine.stopEngine()
            // Allow time for async stop
            let expectation = XCTestExpectation(description: "Engine stop")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSetupAndAccess() {
        let expectation = XCTestExpectation(description: "Concurrent operations should complete safely")
        let group = DispatchGroup()
        
        // Concurrent setup calls
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                self.audioEngine.setupAudioEngine(
                    sampleRate: Double(44100 + i * 1000),
                    channelCount: AVAudioChannelCount(1 + i % 2)
                )
                group.leave()
            }
        }
        
        // Concurrent property access
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let _ = self.audioEngine.isEngineRunning
                let _ = self.audioEngine.isPlayerPlaying
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentStartStop() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let expectation = XCTestExpectation(description: "Concurrent start/stop should be safe")
        let group = DispatchGroup()
        
        // Concurrent start/stop operations
        for _ in 0..<5 {
            group.enter()
            DispatchQueue.global().async {
                let _ = self.audioEngine.startEngine()
                usleep(10000) // 10ms
                self.audioEngine.stopEngine()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testEngineMemoryManagement() {
        weak var weakEngine: AudioEngine?
        
        autoreleasepool {
            let localEngine = AudioEngine()
            weakEngine = localEngine
            
            localEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
            let success = localEngine.startEngine()
            XCTAssertTrue(success, "Local engine should start successfully")
            localEngine.stopEngine()
        }
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Engine should be deallocated
        XCTAssertNil(weakEngine, "AudioEngine should be deallocated")
    }
    
    // MARK: - Hardware Sample Rate Tests
    
    func testHardwareSampleRateHandling() {
        // Test different sample rates
        let sampleRates = [44100.0, 48000.0, 88200.0, 96000.0, 176400.0, 192000.0]
        
        for sampleRate in sampleRates {
            XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: sampleRate, channelCount: 2))
            
            // Should be able to start with any reasonable sample rate
            let success = audioEngine.startEngine()
            XCTAssertTrue(success, "Engine should start with sample rate \(sampleRate)")
            audioEngine.stopEngine()
            
            // Allow time for cleanup
            usleep(50000) // 50ms
        }
    }
    
    // MARK: - Buffer Scheduling Tests
    
    func testBufferSchedulingWithoutCrash() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let success = audioEngine.startEngine()
        XCTAssertTrue(success, "Engine should start for buffer scheduling tests")
        
        // Create a test buffer
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 96000, channels: 2) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = 96000 // 1 second of audio
        
        // Fill buffer with test data
        for channel in 0..<Int(buffer.format.channelCount) {
            if let channelData = buffer.floatChannelData?[channel] {
                for frame in 0..<Int(buffer.frameLength) {
                    let frequency = 440.0
                    let sampleRate = 96000.0
                    let amplitude = 0.1
                    let phase = 2.0 * .pi * frequency * Double(frame) / sampleRate
                    channelData[frame] = Float(sin(phase) * amplitude) // 440Hz at low volume
                }
            }
        }
        
        // Test buffer scheduling - this should not crash even if player is not playing
        XCTAssertNoThrow(audioEngine.scheduleBuffer(buffer, at: nil, completionHandler: nil))
        
        audioEngine.stopEngine()
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingRobustness() {
        // Test operations in various states
        
        // 1. Before setup
        let successBeforeSetup = audioEngine.startEngine()
        XCTAssertFalse(successBeforeSetup, "Starting without setup should fail")
        
        // 2. After setup but before start
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        XCTAssertNoThrow(audioEngine.stopEngine()) // Should be safe
        
        // 3. After start
        let success = audioEngine.startEngine()
        XCTAssertTrue(success, "Engine should start successfully")
        XCTAssertNoThrow(audioEngine.stopEngine())
        
        // 4. Multiple stops
        XCTAssertNoThrow(audioEngine.stopEngine())
        XCTAssertNoThrow(audioEngine.stopEngine())
        
        // 5. Start after stop
        let success2 = audioEngine.startEngine()
        XCTAssertTrue(success2, "Engine should start again after stop")
        audioEngine.stopEngine()
    }
}

// MARK: - AudioEngineError Comparison for Testing

/// Helper function to compare AudioEngineError instances for testing
/// Note: Avoiding extension to prevent conflicts with future conformance
func areEqual(_ lhs: AudioEngineError, _ rhs: AudioEngineError) -> Bool {
    switch (lhs, rhs) {
    case (.engineNotSetup, .engineNotSetup):
        return true
    case (.startFailed(let msg1), .startFailed(let msg2)):
        return msg1 == msg2
    default:
        return false
    }
}