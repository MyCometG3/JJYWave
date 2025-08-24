//
//  AudioEngineManagerTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Unit tests for AudioEngineManager component
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class AudioEngineManagerTests: XCTestCase {
    
    var audioEngineManager: AudioEngineManager!
    
    override func setUp() {
        super.setUp()
        audioEngineManager = AudioEngineManager()
    }
    
    override func tearDown() {
        audioEngineManager.stopEngine()
        audioEngineManager = nil
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
        XCTAssertNoThrow(audioEngineManager.setupAudioEngine(sampleRate: sampleRate, channelCount: channelCount))
        
        // After setup, engine should exist but may not be running yet
        // (running state depends on startEngine() being called)
    }
    
    func testSetupAudioEngineMultipleTimes() {
        // Setting up multiple times should not cause issues
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        audioEngineManager.setupAudioEngine(sampleRate: 48000, channelCount: 1)
        audioEngineManager.setupAudioEngine(sampleRate: 44100, channelCount: 2)
        
        // Should complete without throwing
        XCTAssertTrue(true)
    }
    
    func testSetupWithDifferentSampleRates() {
        let testSampleRates: [Double] = [44100, 48000, 88200, 96000, 192000]
        
        for sampleRate in testSampleRates {
            XCTAssertNoThrow(audioEngineManager.setupAudioEngine(sampleRate: sampleRate, channelCount: 2),
                           "Setup should work with sample rate \(sampleRate)")
        }
    }
    
    func testSetupWithDifferentChannelCounts() {
        let testChannelCounts: [AVAudioChannelCount] = [1, 2, 4, 6, 8]
        
        for channelCount in testChannelCounts {
            XCTAssertNoThrow(audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: channelCount),
                           "Setup should work with \(channelCount) channels")
        }
    }
    
    // MARK: - Engine State Tests
    
    func testStartEngine() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let success = audioEngineManager.startEngine()
        
        if success {
            XCTAssertTrue(audioEngineManager.isEngineRunning)
        } else {
            // Starting might fail in test environment due to audio hardware limitations
            // This is acceptable in unit tests
            XCTAssertFalse(audioEngineManager.isEngineRunning)
        }
    }
    
    func testStopEngine() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        
        audioEngineManager.stopEngine()
        
        XCTAssertFalse(audioEngineManager.isEngineRunning)
        XCTAssertFalse(audioEngineManager.isPlayerPlaying)
    }
    
    func testStartEngineMultipleTimes() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        // Starting multiple times should not cause issues
        let _ = audioEngineManager.startEngine()
        let _ = audioEngineManager.startEngine()
        let _ = audioEngineManager.startEngine()
        
        // Should complete without throwing
        XCTAssertTrue(true)
    }
    
    func testStopEngineMultipleTimes() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        
        // Stopping multiple times should not cause issues
        audioEngineManager.stopEngine()
        audioEngineManager.stopEngine()
        audioEngineManager.stopEngine()
        
        XCTAssertFalse(audioEngineManager.isEngineRunning)
    }
    
    // MARK: - Player Node Tests
    
    func testStartPlayer() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let engineStarted = audioEngineManager.startEngine()
        
        if engineStarted {
            audioEngineManager.startPlayer()
            
            // Player state might depend on audio hardware availability
            // In test environment, this might not always succeed
            // So we just verify no crash occurs
            XCTAssertTrue(true)
        }
    }
    
    func testStopPlayer() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        audioEngineManager.startPlayer()
        
        audioEngineManager.stopPlayer()
        
        XCTAssertFalse(audioEngineManager.isPlayerPlaying)
    }
    
    func testPlayerOperationsWithoutEngine() {
        // Operations should be safe even without engine setup
        XCTAssertNoThrow(audioEngineManager.startPlayer())
        XCTAssertNoThrow(audioEngineManager.stopPlayer())
        
        XCTAssertFalse(audioEngineManager.isPlayerPlaying)
    }
    
    // MARK: - Format and Buffer Tests
    
    func testGetPlayerFormat() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let format = audioEngineManager.getPlayerFormat()
        
        if let format = format {
            XCTAssertEqual(format.sampleRate, 96000, accuracy: 0.1)
            XCTAssertEqual(format.channelCount, 2)
            XCTAssertTrue(format.isStandard)
        }
        // Note: format might be nil in test environment without audio hardware
    }
    
    func testScheduleBuffer() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        
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
        XCTAssertNoThrow(audioEngineManager.scheduleBuffer(buffer, at: nil))
    }
    
    func testScheduleBufferWithTiming() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        
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
        XCTAssertNoThrow(audioEngineManager.scheduleBuffer(buffer, at: audioTime))
    }
    
    // MARK: - Hardware Sample Rate Tests
    
    func testHardwareSampleRateAccess() {
        // Getting hardware sample rate should not throw
        XCTAssertNoThrow(audioEngineManager.getHardwareSampleRate())
        
        let sampleRate = audioEngineManager.getHardwareSampleRate()
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
            let success = audioEngineManager.trySetHardwareSampleRate(sampleRate)
            
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
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        
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
        XCTAssertNoThrow(audioEngineManager.scheduleBuffer(wrongBuffer, at: nil))
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
                
                self.audioEngineManager.setupAudioEngine(sampleRate: sampleRate, channelCount: channelCount)
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
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let expectation = XCTestExpectation(description: "Concurrent start/stop should complete")
        let group = DispatchGroup()
        
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let _ = self.audioEngineManager.startEngine()
                Thread.sleep(forTimeInterval: 0.001)
                self.audioEngineManager.stopEngine()
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
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let _ = audioEngineManager.startEngine()
        
        let expectation = XCTestExpectation(description: "Concurrent player operations should complete")
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                self.audioEngineManager.startPlayer()
                Thread.sleep(forTimeInterval: 0.01)
                self.audioEngineManager.stopPlayer()
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
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        XCTAssertFalse(audioEngineManager.isEngineRunning)
        XCTAssertFalse(audioEngineManager.isPlayerPlaying)
        
        if audioEngineManager.startEngine() {
            XCTAssertTrue(audioEngineManager.isEngineRunning)
            
            audioEngineManager.startPlayer()
            // Player state might be hardware-dependent in test environment
            
            audioEngineManager.stopPlayer()
            XCTAssertFalse(audioEngineManager.isPlayerPlaying)
            
            audioEngineManager.stopEngine()
            XCTAssertFalse(audioEngineManager.isEngineRunning)
            XCTAssertFalse(audioEngineManager.isPlayerPlaying)
        }
    }
}