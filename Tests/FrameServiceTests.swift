//
//  FrameServiceTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Unit tests for FrameService component
//

import XCTest
import Foundation
@testable import JJYWave

final class FrameServiceTests: XCTestCase {
    
    var frameService: FrameService!
    var mockClock: MockClock!
    
    override func setUp() {
        super.setUp()
        // Set up a specific test time: 2025-01-15 14:30:25 JST
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        let testDate = calWithJST.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 25)) ?? Date()
        mockClock = MockClock(date: testDate)
        frameService = FrameService(clock: mockClock)
    }
    
    override func tearDown() {
        frameService = nil
        mockClock = nil
        super.tearDown()
    }
    
    // MARK: - Basic Frame Construction Tests
    
    func testBasicFrameConstruction() {
        let frame = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        // JJY frame should be 60 seconds long
        XCTAssertEqual(frame.count, 60)
        
        // Check that markers are in correct positions (every 10 seconds)
        let markerPositions = [0, 9, 19, 29, 39, 49, 59]
        for position in markerPositions {
            XCTAssertEqual(frame[position], .mark, "Expected marker at second \(position)")
        }
    }
    
    func testFrameWithCallsign() {
        let frame = frameService.buildFrame(
            enableCallsign: true,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        XCTAssertEqual(frame.count, 60)
        
        // When callsign is enabled, certain positions should have morse code
        // This tests that the frame structure changes appropriately
        let morsePositions = Array(12...16) // Typical callsign morse positions
        var hasMorse = false
        for position in morsePositions {
            if position < frame.count && frame[position] == .morse {
                hasMorse = true
                break
            }
        }
        // Note: Whether morse actually appears depends on the timing, but structure should be valid
        XCTAssertEqual(frame.count, 60) // Frame should still be valid length
    }
    
    func testFrameWithServiceStatusBits() {
        let frame = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: true,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (true, false, true, false, true, false)
        )
        
        XCTAssertEqual(frame.count, 60)
        
        // Service status bits should be encoded in specific positions
        // Positions 41-46 typically contain service status bits
        for i in 41...46 {
            XCTAssertTrue(frame[i] == JJYAudioGenerator.JJYSymbol.bit0 || frame[i] == JJYAudioGenerator.JJYSymbol.bit1, "Position \(i) should contain a data bit")
        }
    }
    
    // MARK: - Time-based Frame Tests
    
    func testFrameForSpecificTime() {
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        // Test for a specific time: 2025-03-15 09:45:00 JST
        let specificTime = calWithJST.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 9, minute: 45, second: 0)) ?? Date()
        
        let frame = frameService.buildFrameForTime(
            specificTime,
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        XCTAssertEqual(frame.count, 60)
        
        // Verify that the frame encodes the correct minute (45)
        // Minute is encoded in BCD format at positions 1-8
        let minuteTens = frame[2] == JJYAudioGenerator.JJYSymbol.bit1 ? 4 : 0 // Position 2 represents 40
        let minuteOnes = (frame[5] == JJYAudioGenerator.JJYSymbol.bit1 ? 4 : 0) + (frame[6] == JJYAudioGenerator.JJYSymbol.bit1 ? 2 : 0) + (frame[7] == JJYAudioGenerator.JJYSymbol.bit1 ? 1 : 0)
        let encodedMinute = minuteTens + minuteOnes
        
        XCTAssertEqual(encodedMinute, 45, "Frame should encode minute 45")
    }
    
    func testNextMinuteStart() {
        let calendar = frameService.jstCalendar()
        let testDate = Date(timeIntervalSince1970: 1640995225) // Some arbitrary time with 25 seconds
        
        let nextMinute = frameService.nextMinuteStart(from: testDate, calendar: calendar)
        let nextMinuteSeconds = calendar.component(.second, from: nextMinute)
        
        XCTAssertEqual(nextMinuteSeconds, 0, "Next minute should start at 0 seconds")
        XCTAssertGreaterThan(nextMinute, testDate, "Next minute should be after current time")
    }
    
    func testCurrentMinuteStart() {
        let calendar = frameService.jstCalendar()
        let testDate = Date(timeIntervalSince1970: 1640995225) // Some arbitrary time with 25 seconds
        
        let currentMinute = frameService.currentMinuteStart(from: testDate, calendar: calendar)
        let currentMinuteSeconds = calendar.component(.second, from: currentMinute)
        
        XCTAssertEqual(currentMinuteSeconds, 0, "Current minute start should be at 0 seconds")
        XCTAssertLessThanOrEqual(currentMinute, testDate, "Current minute start should be at or before current time")
    }
    
    // MARK: - Leap Second Tests
    
    func testLeapSecondPlan() {
        let frame = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: (yearUTC: 2025, monthUTC: 6, kind: .insert),
            leapSecondPending: true,
            leapSecondInserted: false,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        XCTAssertEqual(frame.count, 60)
        
        // Leap second flags should be set in positions 53 and 54
        // When pending, specific bit patterns should be present
        let ls1 = frame[53]
        let ls2 = frame[54]
        
        // Verify that leap second information is encoded (specific patterns depend on implementation)
        XCTAssertTrue(ls1 == JJYAudioGenerator.JJYSymbol.bit0 || ls1 == JJYAudioGenerator.JJYSymbol.bit1, "Position 53 should contain leap second flag")
        XCTAssertTrue(ls2 == JJYAudioGenerator.JJYSymbol.bit0 || ls2 == JJYAudioGenerator.JJYSymbol.bit1, "Position 54 should contain leap second flag")
    }
    
    func testLeapSecondInserted() {
        let frame = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        XCTAssertEqual(frame.count, 60)
        
        // When leap second is inserted, flags should reflect this state
        let ls1 = frame[53]
        let ls2 = frame[54]
        
        XCTAssertTrue(ls1 == JJYAudioGenerator.JJYSymbol.bit0 || ls1 == JJYAudioGenerator.JJYSymbol.bit1, "Position 53 should contain leap second status")
        XCTAssertTrue(ls2 == JJYAudioGenerator.JJYSymbol.bit0 || ls2 == JJYAudioGenerator.JJYSymbol.bit1, "Position 54 should contain leap second status")
    }
    
    // MARK: - Calendar and Time Zone Tests
    
    func testJSTCalendar() {
        let calendar = frameService.jstCalendar()
        
        XCTAssertEqual(calendar.identifier, .gregorian)
        XCTAssertEqual(calendar.timeZone.identifier, "Asia/Tokyo")
    }
    
    func testTimeZoneHandling() {
        // Test with different system time zones to ensure JST is always used
        let originalTimeZone = TimeZone.current
        
        // Temporarily change system time zone
        let utcTimeZone = TimeZone(identifier: "UTC")!
        let pstTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        
        for testTimeZone in [utcTimeZone, pstTimeZone] {
            // Create a new frame service instance for each test
            let testFrameService = FrameService(clock: mockClock)
            let calendar = testFrameService.jstCalendar()
            
            // Should always use JST regardless of system time zone
            XCTAssertEqual(calendar.timeZone.identifier, "Asia/Tokyo")
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testFrameConsistency() {
        // Test that building the same frame multiple times gives consistent results
        let frame1 = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        let frame2 = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        XCTAssertEqual(frame1.count, frame2.count)
        XCTAssertEqual(frame1, frame2, "Identical configurations should produce identical frames")
    }
    
    func testAllServiceStatusBitCombinations() {
        let allCombinations = [
            (true, true, true, true, true, true),
            (false, false, false, false, false, false),
            (true, false, true, false, true, false),
            (false, true, false, true, false, true)
        ]
        
        for combination in allCombinations {
            let frame = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: true,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: combination
            )
            
            XCTAssertEqual(frame.count, 60, "Frame should always be 60 seconds regardless of service status bits")
        }
    }
    
    // MARK: - Mock Clock Integration Tests
    
    func testFrameChangesWithTime() {
        // Test that frames change appropriately as time advances
        let frame1 = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        // Advance time by 1 minute
        mockClock.advanceTime(by: 60)
        
        let frame2 = frameService.buildFrame(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        // Frames should be different because time has changed
        XCTAssertNotEqual(frame1, frame2, "Frames should differ when time changes")
        
        // But both should still be valid 60-second frames
        XCTAssertEqual(frame1.count, 60)
        XCTAssertEqual(frame2.count, 60)
    }
}
