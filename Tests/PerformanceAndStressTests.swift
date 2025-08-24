//
//  PerformanceAndStressTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Performance and stress tests for timing-critical components
//

import XCTest
import Foundation
import AVFoundation
import Darwin.Mach
@testable import JJYWave

final class PerformanceAndStressTests: XCTestCase {
    
    var mockClock: MockClock!
    var frameService: FrameService!
    var scheduler: TransmissionScheduler!
    var audioEngine: AudioEngine!
    var bufferFactory: AudioBufferFactory!
    var morseGenerator: MorseCodeGenerator!
    
    override func setUp() {
        super.setUp()
        let testDate = MockClock.createJSTTime(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)
        mockClock = MockClock(date: testDate)
        frameService = FrameService(clock: mockClock)
        scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        audioEngine = AudioEngine()
        morseGenerator = MorseCodeGenerator()
        bufferFactory = AudioBufferFactory(
            sampleRate: 96000,
            channelCount: 2,
            carrierFrequency: 40000,
            morse: morseGenerator,
            secondDuration: 1.0
        )
    }
    
    override func tearDown() {
        scheduler?.stopScheduling()
        audioEngine?.stopEngine()
        scheduler = nil
        frameService = nil
        mockClock = nil
        audioEngine = nil
        bufferFactory = nil
        morseGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Frame Service Performance Tests
    
    func testFrameBuildingPerformance() {
        // Requirement: < 10ms per frame
        measure {
            for _ in 0..<100 {
                let _ = frameService.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
            }
        }
    }
    
    func testFrameBuildingWithComplexConfiguration() {
        // Test performance with all features enabled
        measure {
            for i in 0..<50 {
                let _ = frameService.buildFrame(
                    enableCallsign: true,
                    enableServiceStatusBits: true,
                    leapSecondPlan: (yearUTC: 2025, monthUTC: 6, kind: .insert),
                    leapSecondPending: i % 2 == 0,
                    leapSecondInserted: i % 3 == 0,
                    serviceStatusBits: (true, false, true, false, true, false)
                )
            }
        }
    }
    
    func testFrameBuildingMemoryUsage() {
        // Test that memory usage remains stable during frame building
        let initialMemory = getCurrentMemoryUsage()
        
        for _ in 0..<1000 {
            let _ = frameService.buildFrame(
                enableCallsign: true,
                enableServiceStatusBits: true,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be minimal (allow for some variance)
        XCTAssertLessThan(memoryIncrease, 10_000_000, "Memory increase should be less than 10MB")
    }
    
    // MARK: - Audio Buffer Performance Tests
    
    func testBufferGenerationPerformance() {
        // Requirement: < 5ms per second of audio
        let symbols: [JJYAudioGenerator.JJYSymbol] = [.mark, .bit0, .bit1, .morse]
        
        measure {
            for i in 0..<60 {
                let symbol = symbols[i % symbols.count]
                let _ = bufferFactory.createBuffer(
                    for: symbol,
                    secondIndex: i,
                    carrierFrequency: 40000
                )
            }
        }
    }
    
    func testBufferGenerationMemoryEfficiency() {
        let initialMemory = getCurrentMemoryUsage()
        var buffers: [AVAudioPCMBuffer] = []
        
        // Generate many buffers
        for i in 0..<240 { // 4 minutes worth of buffers
            if let buffer = bufferFactory.createBuffer(
                for: JJYAudioGenerator.JJYSymbol.mark,
                secondIndex: i % 60,
                carrierFrequency: 40000
            ) {
                buffers.append(buffer)
            }
        }
        
        let peakMemory = getCurrentMemoryUsage()
        
        // Clear buffers
        buffers.removeAll()
        
        // Force garbage collection
        autoreleasepool {}
        
        let finalMemory = getCurrentMemoryUsage()
        
        // Memory should be released after clearing buffers
        let retainedMemory = finalMemory - initialMemory
        XCTAssertLessThan(retainedMemory, 50_000_000, "Should release memory after clearing buffers")
    }
    
    // MARK: - Scheduler Performance Tests
    
    func testConfigurationUpdatePerformance() {
        // Requirement: < 1ms per configuration update
        measure {
            for i in 0..<1000 {
                scheduler.updateConfiguration(
                    enableCallsign: i % 2 == 0,
                    enableServiceStatusBits: i % 3 == 0,
                    leapSecondPlan: nil,
                    leapSecondPending: i % 5 == 0,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
            }
        }
    }
    
    func testSchedulerStartStopPerformance() {
        measure {
            for _ in 0..<100 {
                scheduler.startScheduling()
                scheduler.stopScheduling()
            }
        }
    }
    
    // MARK: - Clock Performance Tests
    
    func testClockOperationPerformance() {
        measure {
            for i in 0..<10000 {
                let _ = mockClock.currentDate()
                let _ = mockClock.currentHostTime()
                if i % 100 == 0 {
                    mockClock.advanceTime(by: 0.1)
                }
            }
        }
    }
    
    func testClockAdvancementAccuracy() {
        let initialDate = mockClock.currentDate()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Advance time in many small increments
        for _ in 0..<1000 {
            mockClock.advanceTime(by: 0.001) // 1ms increments
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let finalDate = mockClock.currentDate()
        let expectedAdvancement = 1.0 // 1000 * 0.001
        let actualAdvancement = finalDate.timeIntervalSince(initialDate)
        
        XCTAssertEqual(actualAdvancement, expectedAdvancement, accuracy: 0.0001)
        
        // Performance should be reasonable even for many small increments
        let elapsedTime = endTime - startTime
        XCTAssertLessThan(elapsedTime, 1.0, "1000 clock advances should complete within 1 second")
    }
    
    // MARK: - Morse Generator Performance Tests
    
    func testMorseGenerationPerformance() {
        let dit = 0.1
        
        measure {
            for i in 0..<10000 {
                let time = Double(i % 900) * 0.01 // Cycle through 9-second pattern
                let _ = morseGenerator.isOnAt(timeInWindow: time, dit: dit)
            }
        }
    }
    
    func testMorseGenerationConsistency() {
        let dit = 0.1
        let testTimes = Array(stride(from: 0.0, to: 9.0, by: 0.01))
        var results1: [Bool] = []
        var results2: [Bool] = []
        
        // Generate the same pattern twice
        for time in testTimes {
            results1.append(morseGenerator.isOnAt(timeInWindow: time, dit: dit))
        }
        
        for time in testTimes {
            results2.append(morseGenerator.isOnAt(timeInWindow: time, dit: dit))
        }
        
        // Results should be identical
        XCTAssertEqual(results1, results2, "Morse generation should be deterministic")
    }
    
    // MARK: - Stress Tests
    
    func testExtendedOperationStability() {
        let expectation = XCTestExpectation(description: "Extended operation should remain stable")
        
        scheduler.startScheduling()
        
        var iterationCount = 0
        let maxIterations = 1000
        
        func performIteration() {
            // Simulate extended operation
            mockClock.advanceTime(by: 0.1)
            
            if iterationCount % 10 == 0 {
                scheduler.updateConfiguration(
                    enableCallsign: iterationCount % 20 == 0,
                    enableServiceStatusBits: iterationCount % 30 == 0,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
            }
            
            if iterationCount % 100 == 0 {
                let _ = frameService.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
            }
            
            iterationCount += 1
            
            if iterationCount < maxIterations {
                DispatchQueue.global().async {
                    performIteration()
                }
            } else {
                expectation.fulfill()
            }
        }
        
        DispatchQueue.global().async {
            performIteration()
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        scheduler.stopScheduling()
        XCTAssertEqual(iterationCount, maxIterations, "Should complete all iterations")
    }
    
    func testMemoryLeakDetection() {
        let initialMemory = getCurrentMemoryUsage()
        
        // Create and release many objects
        for _ in 0..<100 {
            autoreleasepool {
                let localClock = MockClock()
                let localFrameService = FrameService(clock: localClock)
                let localScheduler = TransmissionScheduler(clock: localClock, frameService: localFrameService)
                
                localClock.advanceTime(by: 1.0)
                let _ = localFrameService.buildFrame(
                    enableCallsign: true,
                    enableServiceStatusBits: true,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                localScheduler.startScheduling()
                localScheduler.stopScheduling()
            }
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {}
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Should not have significant memory leaks
        XCTAssertLessThan(memoryIncrease, 5_000_000, "Memory increase should be minimal (< 5MB)")
    }
    
    func testHighFrequencyOperations() {
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        
        // Perform operations at high frequency for a limited time
        while CFAbsoluteTimeGetCurrent() - startTime < 1.0 { // 1 second test
            mockClock.advanceTime(by: 0.001)
            
            if operationCount % 10 == 0 {
                let _ = morseGenerator.isOnAt(timeInWindow: Double(operationCount % 900) * 0.01, dit: 0.1)
            }
            
            if operationCount % 100 == 0 {
                scheduler.updateConfiguration(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
            }
            
            operationCount += 1
        }
        
        print("Completed \(operationCount) operations in 1 second")
        XCTAssertGreaterThan(operationCount, 1000, "Should handle high frequency operations")
    }
    
    // MARK: - Component Initialization Performance Tests
    
    func testComponentInitializationPerformance() {
        // Requirement: < 100ms for component initialization
        measure {
            for _ in 0..<10 {
                let clock = MockClock()
                let frameService = FrameService(clock: clock)
                let scheduler = TransmissionScheduler(clock: clock, frameService: frameService)
                let audioEngine = AudioEngine()
                let morseGenerator = MorseCodeGenerator()
                let bufferFactory = AudioBufferFactory(
                    sampleRate: 96000,
                    channelCount: 2,
                    carrierFrequency: 40000,
                    morse: morseGenerator,
                    secondDuration: 1.0
                )
                
                // Use the components briefly to ensure they're fully initialized
                clock.advanceTime(by: 0.1)
                let _ = frameService.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                scheduler.startScheduling()
                scheduler.stopScheduling()
                audioEngine.stopEngine()
            }
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
        
        if kr == KERN_SUCCESS {
            return taskInfo.resident_size
        } else {
            return 0
        }
    }
}