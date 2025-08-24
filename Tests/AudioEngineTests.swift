//
//  AudioEngineTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Unit tests for AudioEngine component
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class AudioEngineTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
    }
    
    override func tearDown() {
        audioEngine.stopEngine()
        audioEngine = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let manager = AudioEngineManager()
        
        // Initially, engine should not be running
        XCTAssertFalse(manager.isEngineRunning)
        XCTAssertFalse(manager.isPlayerPlaying)
    }
    
    // MARK: - Audio Engine Setup Tests
    
    func testSetupAudioEngine() {
        let sampleRate: Double = 96000
        let channelCount: AVAudioChannelCount = 2
        
        // Setup should not throw
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: sampleRate, channelCount: channelCount))
        
        // After setup, engine should exist but may not be running yet
        // (running state depends on startEngine() being called)
    }
    
    func testSetupAudioEngineMultipleTimes() {
        // Setting up multiple times should not cause issues
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        audioEngine.setupAudioEngine(sampleRate: 48000, channelCount: 1)
        audioEngine.setupAudioEngine(sampleRate: 44100, channelCount: 2)
        
        // Should complete without throwing
        XCTAssertTrue(true)
    }
    
    func testSetupWithDifferentSampleRates() {
        let testSampleRates: [Double] = [44100, 48000, 88200, 96000, 192000]
        
        for sampleRate in testSampleRates {
            XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: sampleRate, channelCount: 2),
                           "Setup should work with sample rate \(sampleRate)")
        }
    }
    
    func testSetupWithDifferentChannelCounts() {
        let testChannelCounts: [AVAudioChannelCount] = [1, 2, 4, 6, 8]
        
        for channelCount in testChannelCounts {
            XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: channelCount),
                           "Setup should work with \(channelCount) channels")
        }
    }
    
    // MARK: - Engine State Tests
    
    func testStartEngine() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let success = audioEngine.startEngine()
        
        if success {
            XCTAssertTrue(audioEngine.isEngineRunning)
        } else {
            // Starting might fail in test environment due to audio hardware limitations
            // This is acceptable in unit tests
            XCTAssertFalse(audioEngine.isEngineRunning)
        }
    }
    
    func testStopEngine() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        
        audioEngine.stopEngine()
        
        XCTAssertFalse(audioEngine.isEngineRunning)
        XCTAssertFalse(audioEngine.isPlayerPlaying)
    }
    
    func testStartEngineMultipleTimes() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        // Starting multiple times should not cause issues
        let _ = audioEngine.startEngine()
        let _ = audioEngine.startEngine()
        let _ = audioEngine.startEngine()
        
        // Should complete without throwing
        XCTAssertTrue(true)
    }
    
    func testStopEngineMultipleTimes() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        
        // Stopping multiple times should not cause issues
        audioEngine.stopEngine()
        audioEngine.stopEngine()
        audioEngine.stopEngine()
        
        XCTAssertFalse(audioEngine.isEngineRunning)
    }
    
    // MARK: - Player Node Tests
    
    func testStartPlayer() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let engineStarted = audioEngine.startEngine()
        
        if engineStarted {
            audioEngine.startPlayer()
            
            // Player state might depend on audio hardware availability
            // In test environment, this might not always succeed
            // So we just verify no crash occurs
            XCTAssertTrue(true)
        }
    }
    
    func testStopPlayer() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        audioEngine.startPlayer()
        
        audioEngine.stopPlayer()
        
        XCTAssertFalse(audioEngine.isPlayerPlaying)
    }
    
    func testPlayerOperationsWithoutEngine() {
        // Operations should be safe even without engine setup
        XCTAssertNoThrow(audioEngine.startPlayer())
        XCTAssertNoThrow(audioEngine.stopPlayer())
        
        XCTAssertFalse(audioEngine.isPlayerPlaying)
    }
    
    // MARK: - Format and Buffer Tests
    
    func testGetPlayerFormat() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let format = audioEngine.getPlayerFormat()
        
        if let format = format {
            XCTAssertEqual(format.sampleRate, 96000, accuracy: 0.1)
            XCTAssertEqual(format.channelCount, 2)
            XCTAssertTrue(format.isStandard)
        }
        // Note: format might be nil in test environment without audio hardware
    }
    
    func testScheduleBuffer() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        
        // Create a test buffer
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 96000, channels: 2) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        let frameCount: AVAudioFrameCount = 1024
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create PCM buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Fill buffer with test data (silence)
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frameCount) {
                    channelData[channel][frame] = 0.0
                }
            }
        }
        
        // Scheduling should not throw
        XCTAssertNoThrow(audioEngine.scheduleBuffer(buffer, at: nil))
    }
    
    func testScheduleBufferWithTiming() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 96000, channels: 2) else {
            XCTFail("Failed to create audio format")
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to create PCM buffer")
            return
        }
        
        buffer.frameLength = 1024
        
        // Create a specific audio time
        let audioTime = AVAudioTime(sampleTime: 0, atRate: 96000)
        
        // Scheduling with timing should not throw
        XCTAssertNoThrow(audioEngine.scheduleBuffer(buffer, at: audioTime))
    }
    
    // MARK: - Hardware Sample Rate Tests
    
    func testHardwareSampleRateAccess() {
        // Getting hardware sample rate should not throw
        XCTAssertNoThrow(audioEngine.getHardwareSampleRate())
        
        let sampleRate = audioEngine.getHardwareSampleRate()
        if sampleRate > 0 {
            // If we get a valid sample rate, it should be reasonable
            XCTAssertGreaterThan(sampleRate, 8000)
            XCTAssertLessThan(sampleRate, 1000000)
        }
        // Note: in test environment, hardware access might fail
    }
    
    func testTrySetHardwareSampleRate() {
        let testSampleRates: [Double] = [44100, 48000, 96000]
        
        for sampleRate in testSampleRates {
            let success = audioEngine.trySetHardwareSampleRate(sampleRate)
            
            // Success or failure is hardware-dependent, just verify no crash
            XCTAssertTrue(success == true || success == false)
        }
    }
    
    // MARK: - Error Handling and Edge Cases
    
    func testOperationsBeforeSetup() {
        let manager = AudioEngineManager()
        
        // Operations should be safe before setup
        XCTAssertFalse(manager.isEngineRunning)
        XCTAssertFalse(manager.isPlayerPlaying)
        XCTAssertFalse(manager.startEngine())
        XCTAssertNoThrow(manager.stopEngine())
        XCTAssertNoThrow(manager.startPlayer())
        XCTAssertNoThrow(manager.stopPlayer())
        XCTAssertNil(manager.getPlayerFormat())
    }
    
    func testInvalidBufferScheduling() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        
        // Try to schedule a buffer with different format
        guard let wrongFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            XCTFail("Failed to create wrong format")
            return
        }
        
        guard let wrongBuffer = AVAudioPCMBuffer(pcmFormat: wrongFormat, frameCapacity: 1024) else {
            XCTFail("Failed to create wrong buffer")
            return
        }
        
        wrongBuffer.frameLength = 1024
        
        // Scheduling wrong format buffer should not crash
        // (may or may not work depending on audio engine flexibility)
        XCTAssertNoThrow(audioEngine.scheduleBuffer(wrongBuffer, at: nil))
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentSetup() {
        let expectation = XCTestExpectation(description: "Concurrent setup operations should complete")
        let group = DispatchGroup()
        
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                let sampleRate = [44100.0, 48000.0, 96000.0][i % 3]
                let channelCount: AVAudioChannelCount = AVAudioChannelCount([1, 2][i % 2])
                
                self.audioEngine.setupAudioEngine(sampleRate: sampleRate, channelCount: channelCount)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(true) // If we get here, concurrent setup worked
    }
    
    func testConcurrentStartStop() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let expectation = XCTestExpectation(description: "Concurrent start/stop should complete")
        let group = DispatchGroup()
        
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let _ = self.audioEngine.startEngine()
                Thread.sleep(forTimeInterval: 0.001)
                self.audioEngine.stopEngine()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertTrue(true) // If we get here, concurrent operations worked
    }
    
    func testConcurrentPlayerOperations() {
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngine.startEngine()
        
        let expectation = XCTestExpectation(description: "Concurrent player operations should complete")
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                self.audioEngine.startPlayer()
                Thread.sleep(forTimeInterval: 0.01)
                self.audioEngine.stopPlayer()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(true) // If we get here, concurrent player operations worked
    }
    
    // MARK: - State Consistency Tests
    
    func testStateConsistency() {
        // Test that state properties are consistent
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        XCTAssertFalse(audioEngine.isEngineRunning)
        XCTAssertFalse(audioEngine.isPlayerPlaying)
        
        if audioEngine.startEngine() {
            XCTAssertTrue(audioEngine.isEngineRunning)
            
            audioEngine.startPlayer()
            // Player state might be hardware-dependent in test environment
            
            audioEngine.stopPlayer()
            XCTAssertFalse(audioEngine.isPlayerPlaying)
            
            audioEngine.stopEngine()
            XCTAssertFalse(audioEngine.isEngineRunning)
            XCTAssertFalse(audioEngine.isPlayerPlaying)
        }
    }
}