//
//  ClockTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Unit tests for Clock protocol and SystemClock implementation
//

import XCTest
import Foundation
import AudioToolbox
@testable import JJYWave

final class ClockTests: XCTestCase {
    
    // MARK: - SystemClock Tests
    
    func testSystemClockCurrentDate() {
        let systemClock = SystemClock()
        let beforeDate = Date()
        let clockDate = systemClock.currentDate()
        let afterDate = Date()
        
        // The clock date should be between before and after dates
        XCTAssertGreaterThanOrEqual(clockDate, beforeDate)
        XCTAssertLessThanOrEqual(clockDate, afterDate)
    }
    
    func testSystemClockHostTime() {
        let systemClock = SystemClock()
        let hostTime1 = systemClock.currentHostTime()
        let hostTime2 = systemClock.currentHostTime()
        
        // Host time should be monotonically increasing
        XCTAssertGreaterThanOrEqual(hostTime2, hostTime1)
    }
    
    func testSystemClockFrequency() {
        let systemClock = SystemClock()
        let frequency = systemClock.hostClockFrequency()
        
        // Host clock frequency should be positive and reasonable (typically in MHz range)
        XCTAssertGreaterThan(frequency, 0)
        XCTAssertLessThan(frequency, 10_000_000_000) // Less than 10 GHz
    }
    
    // MARK: - MockClock Tests
    
    func testMockClockInitialization() {
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let testHostTime: UInt64 = 1000000
        let testFrequency: Double = 1000000000
        
        let mockClock = MockClock(date: testDate, hostTime: testHostTime, frequency: testFrequency)
        
        XCTAssertEqual(mockClock.currentDate(), testDate)
        XCTAssertEqual(mockClock.currentHostTime(), testHostTime)
        XCTAssertEqual(mockClock.hostClockFrequency(), testFrequency)
    }
    
    func testMockClockDefaultValues() {
        let mockClock = MockClock()
        
        // Should have reasonable default values
        XCTAssertNotNil(mockClock.currentDate())
        XCTAssertGreaterThan(mockClock.currentHostTime(), 0)
        XCTAssertEqual(mockClock.hostClockFrequency(), 1000000000) // 1 GHz default
    }
    
    func testMockClockSetMockDate() {
        let mockClock = MockClock()
        let newDate = Date(timeIntervalSince1970: 1640995200)
        
        mockClock.setMockDate(newDate)
        
        XCTAssertEqual(mockClock.currentDate(), newDate)
    }
    
    func testMockClockSetMockHostTime() {
        let mockClock = MockClock()
        let newHostTime: UInt64 = 5000000
        
        mockClock.setMockHostTime(newHostTime)
        
        XCTAssertEqual(mockClock.currentHostTime(), newHostTime)
    }
    
    func testMockClockAdvanceTime() {
        let initialDate = Date(timeIntervalSince1970: 1640995200)
        let initialHostTime: UInt64 = 1000000
        let frequency: Double = 1000000000
        let mockClock = MockClock(date: initialDate, hostTime: initialHostTime, frequency: frequency)
        
        let advanceBy: TimeInterval = 5.5 // 5.5 seconds
        mockClock.advanceTime(by: advanceBy)
        
        XCTAssertEqual(mockClock.currentDate(), initialDate.addingTimeInterval(advanceBy))
        XCTAssertEqual(mockClock.currentHostTime(), initialHostTime + UInt64(advanceBy * frequency))
    }
    
    func testMockClockAdvanceTimeMultiple() {
        let initialDate = Date(timeIntervalSince1970: 1640995200)
        let mockClock = MockClock(date: initialDate)
        
        mockClock.advanceTime(by: 1.0)
        mockClock.advanceTime(by: 2.5)
        mockClock.advanceTime(by: 0.5)
        
        let expectedDate = initialDate.addingTimeInterval(4.0) // Total 4 seconds
        XCTAssertEqual(mockClock.currentDate(), expectedDate)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testClockProtocolConformance() {
        func testClockInterface(_ clock: Clock) {
            _ = clock.currentDate()
            _ = clock.currentHostTime()
            _ = clock.hostClockFrequency()
        }
        
        // Test that both implementations conform to the protocol
        testClockInterface(SystemClock())
        testClockInterface(MockClock())
    }
    
    func testClockConsistency() {
        let systemClock = SystemClock()
        
        // Test that multiple calls in quick succession are consistent
        let date1 = systemClock.currentDate()
        let host1 = systemClock.currentHostTime()
        let freq1 = systemClock.hostClockFrequency()
        
        let date2 = systemClock.currentDate()
        let host2 = systemClock.currentHostTime()
        let freq2 = systemClock.hostClockFrequency()
        
        // Date and host time should advance
        XCTAssertGreaterThanOrEqual(date2, date1)
        XCTAssertGreaterThanOrEqual(host2, host1)
        
        // Frequency should be stable
        XCTAssertEqual(freq1, freq2)
    }
}