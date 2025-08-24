//
//  ThreadSafetyTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Comprehensive thread safety tests for all components
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class ThreadSafetyTests: XCTestCase {
    
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
    
    // MARK: - MockClock Thread Safety Tests
    
    func testMockClockConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent clock access should be thread-safe")
        let group = DispatchGroup()
        let iterations = 100
        var results: [Date] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // Concurrent reads
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let date = self.mockClock.currentDate()
                resultsQueue.async {
                    results.append(date)
                    group.leave()
                }
            }
        }
        
        // Concurrent writes
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                self.mockClock.advanceTime(by: Double(i) * 0.1)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(results.count, iterations, "All concurrent reads should complete")
    }
    
    func testMockClockStateConsistency() {
        let expectation = XCTestExpectation(description: "Clock state should remain consistent")
        let group = DispatchGroup()
        
        // Multiple threads advancing time and reading state
        for i in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                let initialDate = self.mockClock.currentDate()
                let initialHostTime = self.mockClock.currentHostTime()
                
                self.mockClock.advanceTime(by: 1.0)
                
                let newDate = self.mockClock.currentDate()
                let newHostTime = self.mockClock.currentHostTime()
                
                // Verify advancement occurred
                XCTAssertGreaterThanOrEqual(newDate, initialDate)
                XCTAssertGreaterThanOrEqual(newHostTime, initialHostTime)
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - FrameService Thread Safety Tests
    
    func testFrameServiceConcurrentFrameBuilding() {
        let expectation = XCTestExpectation(description: "Concurrent frame building should be safe")
        let group = DispatchGroup()
        var frameResults: [Int] = []
        let resultsQueue = DispatchQueue(label: "frameResults")
        
        // Build frames concurrently with different configurations
        for i in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let frame = self.frameService.buildFrame(
                    enableCallsign: i % 2 == 0,
                    enableServiceStatusBits: i % 3 == 0,
                    leapSecondPlan: nil,
                    leapSecondPending: i % 5 == 0,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                resultsQueue.async {
                    frameResults.append(frame.count)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // All frames should be valid length
        XCTAssertEqual(frameResults.count, 20)
        for frameLength in frameResults {
            XCTAssertEqual(frameLength, 60, "All frames should be 60 seconds long")
        }
    }
    
    func testFrameServiceWithConcurrentClockUpdates() {
        let expectation = XCTestExpectation(description: "Frame service should handle concurrent clock updates")
        let group = DispatchGroup()
        
        // Clock updates and frame building happening simultaneously
        for i in 0..<30 {
            group.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    // Update clock
                    self.mockClock.advanceTime(by: Double(i) * 0.1)
                } else {
                    // Build frame
                    let frame = self.frameService.buildFrame(
                        enableCallsign: false,
                        enableServiceStatusBits: false,
                        leapSecondPlan: nil,
                        leapSecondPending: false,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                    XCTAssertEqual(frame.count, 60)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - TransmissionScheduler Thread Safety Tests
    
    func testSchedulerConcurrentConfigurationUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent configuration updates should be safe")
        let group = DispatchGroup()
        
        for i in 0..<25 {
            group.enter()
            DispatchQueue.global().async {
                self.scheduler.updateConfiguration(
                    enableCallsign: i % 2 == 0,
                    enableServiceStatusBits: i % 3 == 0,
                    leapSecondPlan: i % 7 == 0 ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                    leapSecondPending: i % 5 == 0,
                    leapSecondInserted: i % 4 != 0,
                    serviceStatusBits: (
                        i % 2 == 0, i % 3 == 0, i % 5 == 0,
                        i % 7 == 0, i % 11 == 0, i % 13 == 0
                    )
                )
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSchedulerStartStopConcurrency() {
        let expectation = XCTestExpectation(description: "Concurrent start/stop should be handled safely")
        let group = DispatchGroup()
        
        // Rapid start/stop cycles from multiple threads
        for _ in 0..<15 {
            group.enter()
            DispatchQueue.global().async {
                self.scheduler.startScheduling()
                usleep(10000) // 10ms
                self.scheduler.stopScheduling()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Should end in a consistent state
        XCTAssertNoThrow(scheduler.stopScheduling())
    }
    
    // MARK: - AudioBufferFactory Thread Safety Tests
    
    func testBufferFactoryConcurrentGeneration() {
        let expectation = XCTestExpectation(description: "Concurrent buffer generation should be safe")
        let group = DispatchGroup()
        var bufferResults: [AVAudioPCMBuffer?] = []
        let resultsQueue = DispatchQueue(label: "bufferResults")
        
        let symbols: [JJYAudioGenerator.JJYSymbol] = [.mark, .bit0, .bit1, .morse]
        
        // Generate buffers concurrently
        for i in 0..<40 {
            group.enter()
            DispatchQueue.global().async {
                let symbol = symbols[i % symbols.count]
                let buffer = self.bufferFactory.createBuffer(
                    for: symbol,
                    secondIndex: i % 60,
                    carrierFrequency: Double(40000 + i * 100)
                )
                
                resultsQueue.async {
                    bufferResults.append(buffer)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(bufferResults.count, 40)
        
        // Check that buffers were created successfully
        let successfulBuffers = bufferResults.compactMap { $0 }
        XCTAssertGreaterThan(successfulBuffers.count, 0, "Should create some valid buffers")
    }
    
    // MARK: - MorseCodeGenerator Thread Safety Tests
    
    func testMorseGeneratorConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent morse generation should be safe")
        let group = DispatchGroup()
        var results: [Bool] = []
        let resultsQueue = DispatchQueue(label: "morseResults")
        
        // Access morse generator from multiple threads
        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                let time = Double(i) * 0.1
                let dit = 0.1
                let result = self.morseGenerator.isOnAt(timeInWindow: time, dit: dit)
                
                resultsQueue.async {
                    results.append(result)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(results.count, 100, "All morse evaluations should complete")
    }
    
    // MARK: - Cross-Component Thread Safety Tests
    
    func testFullSystemConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Full system concurrent operations should be stable")
        let group = DispatchGroup()
        
        // Start scheduler
        scheduler.startScheduling()
        
        // Mix of operations across all components
        for i in 0..<30 {
            group.enter()
            DispatchQueue.global().async {
                switch i % 4 {
                case 0:
                    // Clock advancement
                    self.mockClock.advanceTime(by: 0.1)
                case 1:
                    // Frame building
                    let _ = self.frameService.buildFrame(
                        enableCallsign: i % 2 == 0,
                        enableServiceStatusBits: false,
                        leapSecondPlan: nil,
                        leapSecondPending: false,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                case 2:
                    // Configuration update
                    self.scheduler.updateConfiguration(
                        enableCallsign: i % 3 == 0,
                        enableServiceStatusBits: i % 5 == 0,
                        leapSecondPlan: nil,
                        leapSecondPending: false,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                case 3:
                    // Morse generation
                    let _ = self.morseGenerator.isOnAt(timeInWindow: Double(i) * 0.1, dit: 0.1)
                default:
                    break
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // System should remain stable
        XCTAssertNoThrow(scheduler.stopScheduling())
    }
    
    // MARK: - Race Condition Detection Tests
    
    func testRaceConditionDetection() {
        let expectation = XCTestExpectation(description: "Race condition detection")
        let iterations = 1000
        let group = DispatchGroup()
        var inconsistencies = 0
        let inconsistencyQueue = DispatchQueue(label: "inconsistencies")
        
        // Rapid operations that could expose race conditions
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let startDate = self.mockClock.currentDate()
                
                // Rapid sequence of operations
                self.mockClock.advanceTime(by: 0.001)
                let _ = self.frameService.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                let endDate = self.mockClock.currentDate()
                
                // Check for consistency
                if endDate < startDate {
                    inconsistencyQueue.async {
                        inconsistencies += 1
                    }
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Should not have any inconsistencies
        XCTAssertEqual(inconsistencies, 0, "Should not have any timing inconsistencies")
    }
    
    // MARK: - Memory Safety Tests
    
    func testConcurrentMemoryAccess() {
        let expectation = XCTestExpectation(description: "Concurrent memory access should be safe")
        let group = DispatchGroup()
        
        // Create and release objects concurrently
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let localClock = MockClock()
                let localFrameService = FrameService(clock: localClock)
                let localScheduler = TransmissionScheduler(clock: localClock, frameService: localFrameService)
                
                // Use the objects briefly
                localClock.advanceTime(by: 1.0)
                let _ = localFrameService.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                localScheduler.startScheduling()
                localScheduler.stopScheduling()
                
                // Objects should be deallocated when this scope ends
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}