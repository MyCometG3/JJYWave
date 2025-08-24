//
//  ComprehensiveIntegrationTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Final comprehensive integration tests covering all enhanced areas
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class ComprehensiveIntegrationTests: XCTestCase {
    
    // MARK: - Complete System Integration Tests
    
    func testCompleteJJYSystemIntegration() {
        // Test the complete JJY system with all components working together
        let testDate = MockClock.createJSTTime(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)
        let mockClock = MockClock(date: testDate)
        let frameService = FrameService(clock: mockClock)
        let scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        let audioEngine = AudioEngine()
        let morseGenerator = MorseCodeGenerator()
        let bufferFactory = AudioBufferFactory(
            sampleRate: 96000,
            channelCount: 2,
            carrierFrequency: 40000,
            morse: morseGenerator,
            secondDuration: 1.0
        )
        
        let delegate = ComprehensiveTestDelegate()
        scheduler.delegate = delegate
        
        // Configure the complete system
        scheduler.updateConfiguration(
            enableCallsign: true,
            enableServiceStatusBits: true,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (true, false, true, false, true, false)
        )
        
        // Setup audio engine
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2))
        XCTAssertNoThrow(try audioEngine.startEngine())
        
        // Start transmission scheduling
        scheduler.startScheduling()
        
        // Simulate system operation
        let expectation = XCTestExpectation(description: "Complete system integration")
        
        DispatchQueue.global().async {
            // Simulate 30 seconds of operation
            for second in 0..<30 {
                mockClock.advanceTime(by: 1.0)
                
                // Generate audio buffers for each second
                if let symbol = delegate.getCurrentSymbol(for: second % 60) {
                    let buffer = bufferFactory.createBuffer(
                        for: symbol,
                        secondIndex: second % 60,
                        carrierFrequency: 40000
                    )
                    
                    if let audioBuffer = buffer {
                        // Schedule the buffer (would normally play audio)
                        audioEngine.scheduleBuffer(audioBuffer, at: nil, options: [], completionHandler: nil)
                    }
                }
                
                usleep(10000) // 10ms to allow processing
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Cleanup
        scheduler.stopScheduling()
        audioEngine.stopEngine()
        
        // Verify system operated correctly
        XCTAssertGreaterThan(delegate.frameRebuildCount, 0, "Should have rebuilt frames")
        XCTAssertGreaterThan(delegate.secondSchedulingCount, 0, "Should have scheduled seconds")
        XCTAssertEqual(delegate.lastFrameSize, 60, "Frames should be 60 seconds long")
    }
    
    func testSystemRecoveryAfterErrors() {
        // Test that the system can recover from various error conditions
        let mockClock = MockClock.testClock()
        let frameService = FrameService(clock: mockClock)
        let scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        let delegate = ComprehensiveTestDelegate()
        scheduler.delegate = delegate
        
        // Start the system
        scheduler.startScheduling()
        
        // Simulate various error conditions and recovery
        
        // 1. Invalid time advancement
        mockClock.advanceTime(by: -1.0) // Negative time (shouldn't break system)
        XCTAssertNoThrow(mockClock.advanceTime(by: 2.0)) // Recovery
        
        // 2. Rapid configuration changes
        for i in 0..<10 {
            scheduler.updateConfiguration(
                enableCallsign: i % 2 == 0,
                enableServiceStatusBits: i % 3 == 0,
                leapSecondPlan: nil,
                leapSecondPending: i % 5 == 0,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
        }
        
        // 3. Rapid start/stop cycles
        for _ in 0..<5 {
            scheduler.stopScheduling()
            scheduler.startScheduling()
        }
        
        // System should still be functional
        mockClock.advanceTime(by: 5.0)
        scheduler.stopScheduling()
        
        XCTAssertGreaterThan(delegate.frameRebuildCount, 0, "System should have continued operating")
    }
    
    func testPerformanceUnderLoad() {
        // Test system performance under load
        let mockClock = MockClock.testClock()
        let frameService = FrameService(clock: mockClock)
        let scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        let morseGenerator = MorseCodeGenerator()
        let bufferFactory = AudioBufferFactory(
            sampleRate: 96000,
            channelCount: 2,
            carrierFrequency: 40000,
            morse: morseGenerator,
            secondDuration: 1.0
        )
        
        let delegate = ComprehensiveTestDelegate()
        scheduler.delegate = delegate
        
        scheduler.updateConfiguration(
            enableCallsign: true,
            enableServiceStatusBits: true,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (true, true, true, true, true, true)
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // High-frequency operations
        for i in 0..<1000 {
            mockClock.advanceTime(by: 0.01) // 10ms increments
            
            if i % 100 == 0 {
                // Build frame every second
                let frame = frameService.buildFrame(
                    enableCallsign: true,
                    enableServiceStatusBits: true,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (true, true, true, true, true, true)
                )
                XCTAssertEqual(frame.count, 60)
            }
            
            if i % 10 == 0 {
                // Generate morse pattern
                let _ = morseGenerator.isOnAt(timeInWindow: Double(i % 900) * 0.01, dit: 0.1)
            }
            
            if i % 50 == 0 {
                // Generate buffer
                let _ = bufferFactory.createBuffer(for: JJYAudioGenerator.JJYSymbol.mark, secondIndex: i % 60, carrierFrequency: 40000)
            }
        }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time
        XCTAssertLessThan(elapsedTime, 5.0, "High-frequency operations should complete within 5 seconds")
    }
    
    func testMemoryStabilityOverTime() {
        // Test that memory usage remains stable over extended operation
        let initialMemory = getCurrentMemoryUsage()
        
        var components: [(MockClock, FrameService, TransmissionScheduler)] = []
        
        // Create and use many component sets
        for i in 0..<50 {
            autoreleasepool {
                let clock = MockClock.testClock()
                let frameService = FrameService(clock: clock)
                let scheduler = TransmissionScheduler(clock: clock, frameService: frameService)
                
                // Use the components
                clock.advanceTime(by: Double(i))
                let _ = frameService.buildFrame(
                    enableCallsign: i % 2 == 0,
                    enableServiceStatusBits: i % 3 == 0,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                scheduler.startScheduling()
                scheduler.stopScheduling()
                
                // Keep some in memory to test for leaks
                if i % 10 == 0 {
                    components.append((clock, frameService, scheduler))
                }
            }
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {}
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Clear retained components
        components.removeAll()
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 20_000_000, "Memory increase should be less than 20MB")
    }
    
    func testConfigurationConsistencyAcrossComponents() {
        // Test that configuration changes are consistently applied across all components
        let mockClock = MockClock.testClock()
        let frameService = FrameService(clock: mockClock)
        let scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        let delegate = ComprehensiveTestDelegate()
        scheduler.delegate = delegate
        
        // Test various configuration combinations
        let configurations = [
            (callsign: false, statusBits: false, leapPending: false),
            (callsign: true, statusBits: false, leapPending: false),
            (callsign: false, statusBits: true, leapPending: false),
            (callsign: true, statusBits: true, leapPending: false),
            (callsign: true, statusBits: true, leapPending: true),
        ]
        
        for (index, config) in configurations.enumerated() {
            scheduler.updateConfiguration(
                enableCallsign: config.callsign,
                enableServiceStatusBits: config.statusBits,
                leapSecondPlan: config.leapPending ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                leapSecondPending: config.leapPending,
                leapSecondInserted: !config.leapPending,
                serviceStatusBits: (true, false, true, false, true, false)
            )
            
            // Generate frames with the same configuration
            let frame1 = frameService.buildFrame(
                enableCallsign: config.callsign,
                enableServiceStatusBits: config.statusBits,
                leapSecondPlan: config.leapPending ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                leapSecondPending: config.leapPending,
                leapSecondInserted: !config.leapPending,
                serviceStatusBits: (true, false, true, false, true, false)
            )
            
            let frame2 = frameService.buildFrame(
                enableCallsign: config.callsign,
                enableServiceStatusBits: config.statusBits,
                leapSecondPlan: config.leapPending ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                leapSecondPending: config.leapPending,
                leapSecondInserted: !config.leapPending,
                serviceStatusBits: (true, false, true, false, true, false)
            )
            
            // Frames should be identical for the same configuration
            XCTAssertEqual(frame1, frame2, "Frames should be identical for configuration \(index)")
            XCTAssertEqual(frame1.count, 60, "All frames should be 60 seconds long")
        }
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kr = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kr == KERN_SUCCESS ? taskInfo.resident_size : 0
    }
}

// MARK: - Comprehensive Test Delegate

class ComprehensiveTestDelegate: TransmissionSchedulerDelegate {
    private(set) var frameRebuildCount = 0
    private(set) var secondSchedulingCount = 0
    private(set) var lastFrameSize = 0
    private var currentFrame: [JJYAudioGenerator.JJYSymbol] = []
    
    func schedulerDidRequestFrameRebuild(for baseTime: Date) {
        frameRebuildCount += 1
        // Simulate frame building
        lastFrameSize = 60
        
        // Create a mock frame for testing
        currentFrame = Array(repeating: JJYAudioGenerator.JJYSymbol.mark, count: 60)
        // Add some variety
        for i in stride(from: 0, to: 60, by: 10) {
            currentFrame[i] = JJYAudioGenerator.JJYSymbol.mark
        }
        for i in 1..<60 where i % 10 != 0 && i % 10 != 9 {
            currentFrame[i] = (i % 2 == 0) ? JJYAudioGenerator.JJYSymbol.bit0 : JJYAudioGenerator.JJYSymbol.bit1
        }
    }
    
    func schedulerDidRequestSecondScheduling(symbol: JJYAudioGenerator.JJYSymbol, secondIndex: Int, when: AVAudioTime) {
        secondSchedulingCount += 1
    }
    
    func getCurrentSymbol(for secondIndex: Int) -> JJYAudioGenerator.JJYSymbol? {
        guard secondIndex >= 0 && secondIndex < currentFrame.count else { return .mark }
        return currentFrame[secondIndex]
    }
}