//
//  ThreadSafetyTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Comprehensive thread safety tests for all components
//

import XCTest
@preconcurrency import Foundation
@preconcurrency import AVFoundation
@testable import JJYWave

final class ThreadSafetyTests: XCTestCase {

    private struct UnsafeSendableRef<T>: @unchecked Sendable {
        let value: T
    }

    private final class LockedInt: @unchecked Sendable {
        private var value: Int
        private let queue = DispatchQueue(label: "ThreadSafetyTests.LockedInt")

        init(_ value: Int = 0) {
            self.value = value
        }

        func increment() {
            queue.sync { value += 1 }
        }

        func get() -> Int {
            queue.sync { value }
        }
    }

    private final class LockedArray<Element>: @unchecked Sendable {
        private var storage: [Element]
        private let queue = DispatchQueue(label: "ThreadSafetyTests.LockedArray")

        init(_ initial: [Element]) {
            self.storage = initial
        }

        func append(_ element: Element) {
            queue.sync { storage.append(element) }
        }

        func set(_ index: Int, _ element: Element) {
            queue.sync { storage[index] = element }
        }

        func values() -> [Element] {
            queue.sync { storage }
        }

        func count() -> Int {
            queue.sync { storage.count }
        }
    }
    
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
        let iterations = 100
        let mockClock = UnsafeSendableRef(value: mockClock!)
        let initialDate = mockClock.value.currentDate()
        let group = DispatchGroup()

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                if i % 10 == 0 {
                    mockClock.value.advanceTime(by: Double(i / 10) * 0.1)
                } else {
                    let _ = mockClock.value.currentDate()
                }
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5.0), .success, "Concurrent clock access timed out")

        let expectedAdvance: TimeInterval = (0..<10).reduce(0) { $0 + Double($1) * 0.1 }
        let finalDate = mockClock.value.currentDate()
        XCTAssertEqual(finalDate.timeIntervalSince(initialDate), expectedAdvance, accuracy: 0.0001)
    }
    
    func testMockClockStateConsistency() {
        let mockClock = UnsafeSendableRef(value: mockClock!)
        let group = DispatchGroup()

        // Multiple threads advancing time and reading state
        for _ in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let initialDate = mockClock.value.currentDate()
                let initialHostTime = mockClock.value.currentHostTime()

                mockClock.value.advanceTime(by: 1.0)

                let newDate = mockClock.value.currentDate()
                let newHostTime = mockClock.value.currentHostTime()

                // Verify advancement occurred
                XCTAssertGreaterThanOrEqual(newDate, initialDate)
                XCTAssertGreaterThanOrEqual(newHostTime, initialHostTime)
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10.0), .success, "Clock state consistency test timed out")
    }
    
    // MARK: - FrameService Thread Safety Tests
    
    func testFrameServiceConcurrentFrameBuilding() {
        let frameService = UnsafeSendableRef(value: frameService!)
        let frameResults = LockedArray(Array(repeating: 0, count: 20))
        let group = DispatchGroup()

        // Build frames concurrently with different configurations
        for i in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let frame = frameService.value.buildFrame(
                    enableCallsign: i % 2 == 0,
                    enableServiceStatusBits: i % 3 == 0,
                    leapSecondPlan: nil,
                    leapSecondPending: i % 5 == 0,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )

                frameResults.set(i, frame.count)
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5.0), .success, "Concurrent frame building timed out")
        
        // All frames should be valid length
        let values = frameResults.values()
        XCTAssertEqual(values.count, 20)
        for frameLength in values {
            XCTAssertTrue((59...61).contains(frameLength), "All frames should be 59..61 seconds long (allowing leap-second variations)")
        }
    }
    
    func testFrameServiceWithConcurrentClockUpdates() {
        let mockClock = UnsafeSendableRef(value: mockClock!)
        let frameService = UnsafeSendableRef(value: frameService!)
        let group = DispatchGroup()

        // Clock updates and frame building happening simultaneously
        for i in 0..<30 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                if i % 2 == 0 {
                    // Update clock
                    mockClock.value.advanceTime(by: Double(i) * 0.1)
                } else {
                    // Build frame
                    let frame = frameService.value.buildFrame(
                        enableCallsign: false,
                        enableServiceStatusBits: false,
                        leapSecondPlan: nil,
                        leapSecondPending: false,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                    XCTAssertEqual(frame.count, 60)
                }
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5.0), .success, "Concurrent clock update/frame build timed out")
    }
    
    // MARK: - TransmissionScheduler Thread Safety Tests
    
    func testSchedulerConcurrentConfigurationUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent configuration updates should be safe")
        let group = DispatchGroup()
        let scheduler = UnsafeSendableRef(value: scheduler!)
        
        for i in 0..<25 {
            group.enter()
            DispatchQueue.global().async {
                scheduler.value.updateConfiguration(
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
        let scheduler = UnsafeSendableRef(value: scheduler!)
        
        // Rapid start/stop cycles from multiple threads
        for _ in 0..<15 {
            group.enter()
            DispatchQueue.global().async {
                scheduler.value.startScheduling()
                usleep(10000) // 10ms
                scheduler.value.stopScheduling()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Should end in a consistent state
        XCTAssertNoThrow(scheduler.value.stopScheduling())
    }
    
    // MARK: - AudioBufferFactory Thread Safety Tests
    
    func testBufferFactoryConcurrentGeneration() {
        let expectation = XCTestExpectation(description: "Concurrent buffer generation should be safe")
        let group = DispatchGroup()
        let bufferFactory = UnsafeSendableRef(value: bufferFactory!)
        let bufferResults = LockedArray<AVAudioPCMBuffer?>([])
        
        let symbols: [JJYAudioGenerator.JJYSymbol] = [.mark, .bit0, .bit1, .morse]
        
        // Generate buffers concurrently
        for i in 0..<40 {
            group.enter()
            DispatchQueue.global().async {
                let symbol = symbols[i % symbols.count]
                let buffer = bufferFactory.value.createBuffer(
                    for: symbol,
                    secondIndex: i % 60,
                    carrierFrequency: Double(40000 + i * 100)
                )
                bufferResults.append(buffer)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        let results = bufferResults.values()
        XCTAssertEqual(results.count, 40)
        
        // Check that buffers were created successfully
        let successfulBuffers = results.compactMap { $0 }
        XCTAssertGreaterThan(successfulBuffers.count, 0, "Should create some valid buffers")
    }
    
    // MARK: - MorseCodeGenerator Thread Safety Tests
    
    func testMorseGeneratorConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent morse generation should be safe")
        let group = DispatchGroup()
        let morseGenerator = UnsafeSendableRef(value: morseGenerator!)
        let resultsCount = LockedInt(0)
        
        // Access morse generator from multiple threads
        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                let time = Double(i) * 0.1
                let dit = 0.1
                let _ = morseGenerator.value.isOnAt(timeInWindow: time, dit: dit)
                resultsCount.increment()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(resultsCount.get(), 100, "All morse evaluations should complete")
    }
    
    // MARK: - Cross-Component Thread Safety Tests
    
    func testFullSystemConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Full system concurrent operations should be stable")
        let group = DispatchGroup()
        let mockClock = UnsafeSendableRef(value: mockClock!)
        let frameService = UnsafeSendableRef(value: frameService!)
        let scheduler = UnsafeSendableRef(value: scheduler!)
        let morseGenerator = UnsafeSendableRef(value: morseGenerator!)
        
        // Start scheduler
        scheduler.value.startScheduling()
        
        // Mix of operations across all components
        for i in 0..<30 {
            group.enter()
            DispatchQueue.global().async {
                switch i % 4 {
                case 0:
                    // Clock advancement
                    mockClock.value.advanceTime(by: 0.1)
                case 1:
                    // Frame building
                    let _ = frameService.value.buildFrame(
                        enableCallsign: i % 2 == 0,
                        enableServiceStatusBits: false,
                        leapSecondPlan: nil,
                        leapSecondPending: false,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                case 2:
                    // Configuration update
                    scheduler.value.updateConfiguration(
                        enableCallsign: i % 3 == 0,
                        enableServiceStatusBits: i % 5 == 0,
                        leapSecondPlan: nil,
                        leapSecondPending: false,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                case 3:
                    // Morse generation
                    let _ = morseGenerator.value.isOnAt(timeInWindow: Double(i) * 0.1, dit: 0.1)
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
        XCTAssertNoThrow(scheduler.value.stopScheduling())
    }
    
    // MARK: - Race Condition Detection Tests
    
    func testRaceConditionDetection() {
        let expectation = XCTestExpectation(description: "Race condition detection")
        let iterations = 1000
        let group = DispatchGroup()
        let mockClock = UnsafeSendableRef(value: mockClock!)
        let frameService = UnsafeSendableRef(value: frameService!)
        let inconsistencies = LockedInt(0)
        
        // Rapid operations that could expose race conditions
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let startDate = mockClock.value.currentDate()
                
                // Rapid sequence of operations
                mockClock.value.advanceTime(by: 0.001)
                let _ = frameService.value.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: false,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                let endDate = mockClock.value.currentDate()
                
                // Check for consistency
                if endDate < startDate {
                    inconsistencies.increment()
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Should not have any inconsistencies
        XCTAssertEqual(inconsistencies.get(), 0, "Should not have any timing inconsistencies")
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
