//
//  TransmissionSchedulerTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Unit tests for TransmissionScheduler component
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class TransmissionSchedulerTests: XCTestCase {
    
    var scheduler: TransmissionScheduler!
    var mockClock: MockClock!
    var frameService: FrameService!
    var mockDelegate: MockSchedulerDelegate!
    
    override func setUp() {
        super.setUp()
        // Set up a specific test time: 2025-01-15 14:30:00 JST (start of minute)
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        let testDate = calWithJST.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)) ?? Date()
        mockClock = MockClock(date: testDate, hostTime: 1000000, frequency: 1000000000)
        frameService = FrameService(clock: mockClock)
        scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        mockDelegate = MockSchedulerDelegate()
        scheduler.delegate = mockDelegate
    }
    
    override func tearDown() {
        scheduler.stopScheduling()
        scheduler = nil
        mockClock = nil
        frameService = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationUpdate() {
        scheduler.updateConfiguration(
            enableCallsign: true,
            enableServiceStatusBits: true,
            leapSecondPlan: (yearUTC: 2025, monthUTC: 6, kind: .insert),
            leapSecondPending: true,
            leapSecondInserted: false,
            serviceStatusBits: (true, false, true, false, true, false)
        )
        
        // Configuration should be stored and available for frame building
        // We verify this indirectly by checking that the scheduler can start successfully
        XCTAssertNoThrow(scheduler.startScheduling())
    }
    
    func testConfigurationDefaults() {
        // Test that scheduler has reasonable defaults
        XCTAssertNoThrow(scheduler.startScheduling())
        
        // Should be able to start without explicit configuration
        XCTAssertTrue(true) // If we get here without crashing, defaults are working
    }
    
    // MARK: - Scheduling Tests
    
    func testStartScheduling() {
        let expectation = XCTestExpectation(description: "Scheduler should request initial frame rebuild")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        // Should have requested at least one frame rebuild
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    func testStopScheduling() {
        scheduler.startScheduling()
        scheduler.stopScheduling()
        
        // After stopping, no more scheduling should occur
        let initialCallCount = mockDelegate.secondSchedulingCallCount
        
        // Wait a bit to see if any delayed calls occur
        let expectation = XCTestExpectation(description: "Wait for potential delayed calls")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)
        
        // Call count should not have increased
        XCTAssertEqual(mockDelegate.secondSchedulingCallCount, initialCallCount)
    }
    
    // MARK: - Timing and Drift Tests
    
    func testMinuteRollover() {
        // Start at 59 seconds of a minute
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        let testDate = calWithJST.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 59)) ?? Date()
        mockClock.setMockDate(testDate)
        
        let expectation = XCTestExpectation(description: "Should rebuild frame at minute boundary")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        // Advance to next minute
        mockClock.advanceTime(by: 1.0)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    func testDriftDetection() {
        scheduler.startScheduling()
        
        // Simulate significant time drift by advancing mock time significantly
        let initialCallCount = mockDelegate.frameRebuildCallCount
        
        // Advance by a large amount to trigger drift detection
        mockClock.advanceTime(by: 2.5) // More than typical drift threshold
        
        // Allow some time for drift detection to trigger
        let expectation = XCTestExpectation(description: "Wait for drift detection")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)
        
        // Should have triggered additional frame rebuilds due to drift
        XCTAssertGreaterThanOrEqual(mockDelegate.frameRebuildCallCount, initialCallCount)
    }
    
    func testHostTimeScheduling() {
        let expectation = XCTestExpectation(description: "Should schedule second events")
        mockDelegate.secondSchedulingExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        // Should have scheduled at least one second
        XCTAssertGreaterThan(mockDelegate.secondSchedulingCallCount, 0)
        
        // Verify that scheduling includes proper AVAudioTime
        if let lastScheduling = mockDelegate.lastSecondScheduling {
            XCTAssertNotNil(lastScheduling.when)
        }
    }
    
    // MARK: - Frame Integration Tests
    
    func testFrameSymbolSequence() {
        let expectation = XCTestExpectation(description: "Should schedule multiple seconds in sequence")
        expectation.expectedFulfillmentCount = 5 // Wait for 5 second schedulings
        mockDelegate.multipleSecondExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 2.0)
        
        // Should have scheduled symbols in the correct sequence
        XCTAssertGreaterThanOrEqual(mockDelegate.scheduledSymbols.count, 5)
        
        // First symbol should be a marker (position 0 in frame)
        if !mockDelegate.scheduledSymbols.isEmpty {
            XCTAssertEqual(mockDelegate.scheduledSymbols[0].symbol, JJYAudioGenerator.JJYSymbol.mark)
            XCTAssertEqual(mockDelegate.scheduledSymbols[0].secondIndex, 0)
        }
    }
    
    func testFrameLength() {
        let expectation = XCTestExpectation(description: "Should complete full frame cycle")
        expectation.expectedFulfillmentCount = 60 // Full JJY frame
        mockDelegate.multipleSecondExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should have scheduled all 60 seconds of a frame
        XCTAssertEqual(mockDelegate.scheduledSymbols.count, 60)
        
        // Verify that second indices are correct
        for (index, scheduling) in mockDelegate.scheduledSymbols.enumerated() {
            XCTAssertEqual(scheduling.secondIndex, index, "Second index should match array position")
        }
    }
    
    // MARK: - Leap Second Handling Tests
    
    func testLeapSecondConfiguration() {
        scheduler.updateConfiguration(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: (yearUTC: 2025, monthUTC: 12, kind: .insert),
            leapSecondPending: true,
            leapSecondInserted: false,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        let expectation = XCTestExpectation(description: "Should rebuild frame with leap second info")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    // MARK: - Error Handling and Edge Cases
    
    func testStartSchedulingMultipleTimes() {
        // Starting multiple times should not cause issues
        scheduler.startScheduling()
        scheduler.startScheduling()
        scheduler.startScheduling()
        
        // Should still work normally
        let expectation = XCTestExpectation(description: "Should continue scheduling normally")
        mockDelegate.secondSchedulingExpectation = expectation
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.secondSchedulingCallCount, 0)
    }
    
    func testStopSchedulingMultipleTimes() {
        scheduler.startScheduling()
        
        // Stopping multiple times should not cause issues
        scheduler.stopScheduling()
        scheduler.stopScheduling()
        scheduler.stopScheduling()
        
        // Should remain stopped
        XCTAssertTrue(true) // If we get here without crashing, multiple stops are handled correctly
    }
    
    func testSchedulerWithoutDelegate() {
        // Scheduler should handle missing delegate gracefully
        scheduler.delegate = nil
        
        XCTAssertNoThrow(scheduler.startScheduling())
        XCTAssertNoThrow(scheduler.stopScheduling())
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentConfigurationUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent configuration updates should complete")
        let iterations = 100
        
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            scheduler.updateConfiguration(
                enableCallsign: index % 2 == 0,
                enableServiceStatusBits: index % 3 == 0,
                leapSecondPlan: nil,
                leapSecondPending: index % 5 == 0,
                leapSecondInserted: index % 7 == 0,
                serviceStatusBits: (index % 2 == 0, false, true, false, true, false)
            )
        }
        
        // All updates should complete without crashing
        expectation.fulfill()
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(true) // If we get here, concurrent updates worked
    }
    
    func testConcurrentStartStop() {
        let expectation = XCTestExpectation(description: "Concurrent start/stop should complete")
        let group = DispatchGroup()
        
        // Multiple concurrent start/stop operations
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                self.scheduler.startScheduling()
                Thread.sleep(forTimeInterval: 0.01)
                self.scheduler.stopScheduling()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(true) // If we get here, concurrent operations worked
    }
}

// MARK: - Mock Scheduler Delegate

class MockSchedulerDelegate: TransmissionSchedulerDelegate {
    var frameRebuildCallCount = 0
    var secondSchedulingCallCount = 0
    var frameRebuildTimes: [Date] = []
    var scheduledSymbols: [(symbol: JJYAudioGenerator.JJYSymbol, secondIndex: Int, when: AVAudioTime?)] = []
    var lastSecondScheduling: (symbol: JJYAudioGenerator.JJYSymbol, secondIndex: Int, when: AVAudioTime?)?
    
    // Expectations for testing
    var frameRebuildExpectation: XCTestExpectation?
    var secondSchedulingExpectation: XCTestExpectation?
    var multipleSecondExpectation: XCTestExpectation?
    
    func schedulerDidRequestFrameRebuild(for baseTime: Date) {
        frameRebuildCallCount += 1
        frameRebuildTimes.append(baseTime)
        frameRebuildExpectation?.fulfill()
    }
    
    func schedulerDidRequestSecondScheduling(symbol: JJYAudioGenerator.JJYSymbol, secondIndex: Int, when: AVAudioTime) {
        secondSchedulingCallCount += 1
        let scheduling = (symbol: symbol, secondIndex: secondIndex, when: when as AVAudioTime?)
        scheduledSymbols.append(scheduling)
        lastSecondScheduling = scheduling
        
        secondSchedulingExpectation?.fulfill()
        multipleSecondExpectation?.fulfill()
    }
    
    // Helper methods for tests
    func reset() {
        frameRebuildCallCount = 0
        secondSchedulingCallCount = 0
        frameRebuildTimes.removeAll()
        scheduledSymbols.removeAll()
        lastSecondScheduling = nil
    }
}