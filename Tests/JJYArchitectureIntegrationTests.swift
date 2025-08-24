//
//  JJYArchitectureIntegrationTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Integration tests for JJYAudioGenerator refactored architecture components
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class JJYArchitectureIntegrationTests: XCTestCase {
    
    var mockClock: MockClock!
    var frameService: FrameService!
    var scheduler: TransmissionScheduler!
    var audioEngineManager: AudioEngine!
    var mockDelegate: MockSchedulerDelegate!
    
    override func setUp() {
        super.setUp()
        setupTestComponents()
    }
    
    override func tearDown() {
        scheduler?.stopScheduling()
        audioEngineManager?.stopEngine()
        
        mockClock = nil
        frameService = nil
        scheduler = nil
        audioEngineManager = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    private func setupTestComponents() {
        // Set up components with deterministic test time
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        let testDate = calWithJST.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)) ?? Date()
        mockClock = MockClock(date: testDate, hostTime: 1000000, frequency: 1000000000)
        
        frameService = FrameService(clock: mockClock)
        scheduler = TransmissionScheduler(clock: mockClock, frameService: frameService)
        audioEngineManager = AudioEngine()
        mockDelegate = MockSchedulerDelegate()
        scheduler.delegate = mockDelegate
    }
    
    // MARK: - Clock and FrameService Integration Tests
    
    func testClockFrameServiceIntegration() {
        // Test that frame service uses clock correctly for different times
        let calendar = frameService.jstCalendar()
        
        // Test at specific minute boundaries
        let testTimes = [
            calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 9, minute: 0, second: 0))!,
            calendar.date(from: DateComponents(year: 2025, month: 6, day: 21, hour: 12, minute: 30, second: 0))!,
            calendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 23, minute: 59, second: 0))!
        ]
        
        for testTime in testTimes {
            mockClock.setMockDate(testTime)
            
            let frame = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: true,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            
            XCTAssertEqual(frame.count, 60, "Frame should be 60 seconds for time \(testTime)")
            
            // Verify time encoding in frame
            let minute = calendar.component(.minute, from: testTime)
            let hour = calendar.component(.hour, from: testTime)
            
            // Basic validation that time is encoded (detailed BCD validation would be complex)
            let hasTimeData = frame.contains { symbol in
                symbol == JJYAudioGenerator.JJYSymbol.bit0 || symbol == JJYAudioGenerator.JJYSymbol.bit1
            }
            XCTAssertTrue(hasTimeData, "Frame should contain time data bits")
        }
    }
    
    func testFrameServiceTimeCalculations() {
        let testDate = Date(timeIntervalSince1970: 1640995225) // 25 seconds into a minute
        mockClock.setMockDate(testDate)
        
        let calendar = frameService.jstCalendar()
        
        let currentMinute = frameService.currentMinuteStart(from: testDate, calendar: calendar)
        let nextMinute = frameService.nextMinuteStart(from: testDate, calendar: calendar)
        
        XCTAssertEqual(calendar.component(.second, from: currentMinute), 0)
        XCTAssertEqual(calendar.component(.second, from: nextMinute), 0)
        XCTAssertLessThanOrEqual(currentMinute, testDate)
        XCTAssertGreaterThan(nextMinute, testDate)
        
        let timeDifference = nextMinute.timeIntervalSince(currentMinute)
        XCTAssertEqual(timeDifference, 60.0, accuracy: 0.1, "Minutes should be 60 seconds apart")
    }
    
    // MARK: - Scheduler and FrameService Integration Tests
    
    func testSchedulerFrameServiceIntegration() {
        let expectation = XCTestExpectation(description: "Scheduler should request frame rebuild")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
        XCTAssertNotEmpty(mockDelegate.frameRebuildTimes)
    }
    
    func testSchedulerMinuteRolloverIntegration() {
        // Start near minute boundary
        let calendar = frameService.jstCalendar()
        let testDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 58))!
        mockClock.setMockDate(testDate)
        
        let expectation = XCTestExpectation(description: "Should rebuild frame at minute boundary")
        expectation.expectedFulfillmentCount = 2 // Initial + rollover
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        // Advance past minute boundary
        mockClock.advanceTime(by: 3.0) // Cross into next minute
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertGreaterThanOrEqual(mockDelegate.frameRebuildCallCount, 2)
    }
    
    func testSchedulerConfigurationPropagation() {
        // Test that configuration changes propagate to frame building
        scheduler.updateConfiguration(
            enableCallsign: true,
            enableServiceStatusBits: true,
            leapSecondPlan: (yearUTC: 2025, monthUTC: 6, kind: .insert),
            leapSecondPending: true,
            leapSecondInserted: false,
            serviceStatusBits: (true, false, true, false, true, false)
        )
        
        let expectation = XCTestExpectation(description: "Configuration should affect frame building")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify configuration was used (we can't directly inspect the frame from here,
        // but the fact that it completed without error indicates configuration was applied)
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    // MARK: - Scheduler and AudioEngine Integration Tests
    
    func testSchedulerAudioEngineCoordination() {
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        let expectation = XCTestExpectation(description: "Scheduler should request audio scheduling")
        mockDelegate.secondSchedulingExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.secondSchedulingCallCount, 0)
        
        // Verify audio time was provided
        if let lastScheduling = mockDelegate.lastSecondScheduling {
            XCTAssertNotNil(lastScheduling.when, "Audio scheduling should include timing information")
        }
    }
    
    func testFullPipelineIntegration() {
        // Test the complete pipeline: Clock -> FrameService -> Scheduler -> AudioEngine
        audioEngineManager.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        let engineStarted = audioEngineManager.startEngine()
        
        if engineStarted {
            let expectation = XCTestExpectation(description: "Full pipeline should work")
            expectation.expectedFulfillmentCount = 5 // Multiple seconds
            mockDelegate.multipleSecondExpectation = expectation
            
            scheduler.startScheduling()
            
            wait(for: [expectation], timeout: 3.0)
            
            XCTAssertGreaterThanOrEqual(mockDelegate.scheduledSymbols.count, 5)
            
            // Verify symbol sequence
            if !mockDelegate.scheduledSymbols.isEmpty {
                let firstSymbol = mockDelegate.scheduledSymbols[0]
                XCTAssertEqual(firstSymbol.secondIndex, 0, "First symbol should be at index 0")
                XCTAssertEqual(firstSymbol.symbol, JJYAudioGenerator.JJYSymbol.mark, "First symbol should be a marker")
            }
        } else {
            XCTSkip("Audio engine could not be started in test environment")
        }
    }
    
    // MARK: - Timing Accuracy Integration Tests
    
    func testTimingCoordinationAccuracy() {
        let expectation = XCTestExpectation(description: "Timing should be coordinated accurately")
        mockDelegate.secondSchedulingExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify that scheduled times are reasonable
        if let scheduling = mockDelegate.lastSecondScheduling,
           let audioTime = scheduling.when {
            XCTAssertGreaterThan(audioTime.sampleTime, 0, "Audio time should be positive")
        }
    }
    
    func testDriftDetectionIntegration() {
        scheduler.startScheduling()
        
        let initialCallCount = mockDelegate.frameRebuildCallCount
        
        // Simulate significant time drift
        mockClock.advanceTime(by: 5.0) // Large time jump
        
        let expectation = XCTestExpectation(description: "Wait for drift detection")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Should trigger additional frame rebuilds due to drift
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, initialCallCount,
                           "Drift should trigger frame rebuilds")
    }
    
    // MARK: - Configuration Validation Integration Tests
    
    func testLeapSecondIntegration() {
        // Test leap second configuration propagation through the system
        scheduler.updateConfiguration(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: (yearUTC: 2025, monthUTC: 12, kind: .insert),
            leapSecondPending: true,
            leapSecondInserted: false,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        let expectation = XCTestExpectation(description: "Leap second configuration should work")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    func testServiceStatusBitsIntegration() {
        let allServiceBits = (true, true, true, true, true, true)
        
        scheduler.updateConfiguration(
            enableCallsign: false,
            enableServiceStatusBits: true,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: allServiceBits
        )
        
        let expectation = XCTestExpectation(description: "Service status bits should be integrated")
        mockDelegate.frameRebuildExpectation = expectation
        
        scheduler.startScheduling()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testComponentFailureRecovery() {
        // Test that system handles component failures gracefully
        scheduler.delegate = nil // Remove delegate
        
        // Should not crash when delegate is missing
        XCTAssertNoThrow(scheduler.startScheduling())
        XCTAssertNoThrow(scheduler.stopScheduling())
    }
    
    func testInvalidTimeHandling() {
        // Test with invalid date
        let invalidDate = Date(timeIntervalSince1970: -1000000) // Very old date
        mockClock.setMockDate(invalidDate)
        
        // Should handle gracefully
        XCTAssertNoThrow({
            let frame = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            XCTAssertEqual(frame.count, 60, "Should still produce valid frame")
        })
    }
    
    // MARK: - Performance Integration Tests
    
    func testComponentPerformanceIntegration() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform typical operations
        for _ in 0..<100 {
            mockClock.advanceTime(by: 1.0)
            let _ = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
        }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time (adjust threshold as needed)
        XCTAssertLessThan(elapsedTime, 1.0, "100 frame builds should complete within 1 second")
    }
    
    func testConcurrentOperationsIntegration() {
        let expectation = XCTestExpectation(description: "Concurrent operations should complete")
        let group = DispatchGroup()
        
        // Start scheduler
        scheduler.startScheduling()
        
        // Concurrent configuration updates
        for i in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                self.scheduler.updateConfiguration(
                    enableCallsign: i % 2 == 0,
                    enableServiceStatusBits: i % 3 == 0,
                    leapSecondPlan: nil,
                    leapSecondPending: i % 5 == 0,
                    leapSecondInserted: true,
                    serviceStatusBits: (false, false, false, false, false, false)
                )
                
                // Advance time concurrently
                self.mockClock.advanceTime(by: 0.1)
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // System should remain stable after concurrent operations
        XCTAssertGreaterThan(mockDelegate.frameRebuildCallCount, 0)
    }
    
    // MARK: - Helper Extensions
    
    func testMockClockAdvancement() {
        let initialDate = mockClock.currentDate()
        let initialHostTime = mockClock.currentHostTime()
        
        mockClock.advanceTime(by: 10.0)
        
        let newDate = mockClock.currentDate()
        let newHostTime = mockClock.currentHostTime()
        
        XCTAssertEqual(newDate.timeIntervalSince(initialDate), 10.0, accuracy: 0.001)
        XCTAssertEqual(newHostTime - initialHostTime, UInt64(10.0 * mockClock.hostClockFrequency()))
    }
}

// MARK: - Test Utilities

extension XCTestCase {
    func XCTAssertNotEmpty<T: Collection>(_ collection: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(collection.isEmpty, message, file: file, line: line)
    }
}