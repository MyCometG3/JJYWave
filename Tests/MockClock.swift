//
//  MockClock.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Enhanced mock clock for deterministic testing
//

import Foundation
@testable import JJYWave

/// Enhanced mock clock for deterministic testing with additional features
public class MockClock: Clock {
    private var mockDate: Date
    private var mockHostTime: UInt64
    private var mockFrequency: Double
    private var isRunning: Bool = false
    private var advancementRate: Double = 1.0 // Rate at which time advances (1.0 = real-time)
    private let queue = DispatchQueue(label: "MockClock.queue")
    
    // MARK: - Initialization
    
    public init(date: Date = Date(), hostTime: UInt64 = 1000000, frequency: Double = 1000000000) {
        self.mockDate = date
        self.mockHostTime = hostTime
        self.mockFrequency = frequency
    }
    
    // MARK: - Clock Protocol
    
    public func currentDate() -> Date {
        return queue.sync { mockDate }
    }
    
    public func currentHostTime() -> UInt64 {
        return queue.sync { mockHostTime }
    }
    
    public func hostClockFrequency() -> Double {
        return queue.sync { mockFrequency }
    }
    
    // MARK: - Mock Control Methods
    
    /// Set the mock date directly
    public func setMockDate(_ date: Date) {
        queue.sync {
            self.mockDate = date
        }
    }
    
    /// Set the mock host time directly
    public func setMockHostTime(_ hostTime: UInt64) {
        queue.sync {
            self.mockHostTime = hostTime
        }
    }
    
    /// Set the mock host clock frequency
    public func setMockFrequency(_ frequency: Double) {
        queue.sync {
            self.mockFrequency = frequency
        }
    }
    
    /// Advance time by a specific amount
    public func advanceTime(by seconds: TimeInterval) {
        queue.sync {
            self.mockDate = mockDate.addingTimeInterval(seconds)
            let hostTimeChange = seconds * mockFrequency
            if hostTimeChange >= 0 {
                self.mockHostTime += UInt64(hostTimeChange)
            } else {
                // 負の値の場合の処理
                let absChange = UInt64(-hostTimeChange)
                if absChange <= self.mockHostTime {
                    self.mockHostTime -= absChange
                } else {
                    self.mockHostTime = 0
                }
            }
        }
    }
    
    /// Advance time to a specific date
    public func advanceTime(to date: Date) {
        queue.sync {
            let interval = date.timeIntervalSince(mockDate)
            if interval >= 0 {
                self.mockDate = date
                self.mockHostTime += UInt64(interval * mockFrequency)
            }
        }
    }
    
    /// Set advancement rate for automatic time progression
    public func setAdvancementRate(_ rate: Double) {
        queue.sync {
            self.advancementRate = rate
        }
    }
    
    /// Start automatic time advancement
    public func startAutomaticAdvancement() {
        queue.sync {
            self.isRunning = true
        }
        // In a real implementation, you might start a timer here
    }
    
    /// Stop automatic time advancement
    public func stopAutomaticAdvancement() {
        queue.sync {
            self.isRunning = false
        }
    }
    
    // MARK: - Test Utilities
    
    /// Advance time to the next minute boundary
    public func advanceToNextMinute() {
        let calendar = Calendar.current
        let currentSeconds = calendar.component(.second, from: currentDate())
        let secondsToNextMinute = 60 - currentSeconds
        advanceTime(by: TimeInterval(secondsToNextMinute))
    }
    
    /// Advance time to the next hour boundary
    public func advanceToNextHour() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .second], from: currentDate())
        let minutesToNextHour = 60 - (components.minute ?? 0)
        let secondsToNextHour = 60 - (components.second ?? 0)
        let totalSeconds = (minutesToNextHour - 1) * 60 + secondsToNextHour
        advanceTime(by: TimeInterval(totalSeconds))
    }
    
    /// Create a specific JST time for testing
    public static func createJSTTime(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        return calWithJST.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)) ?? Date()
    }
    
    /// Set to a specific JST time
    public func setToJSTTime(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) {
        let jstDate = MockClock.createJSTTime(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        setMockDate(jstDate)
    }
    
    // MARK: - Leap Second Testing Support
    
    /// Advance to a time just before a leap second
    public func advanceToPreLeapSecond() {
        // Set to 23:59:59 on December 31st of a leap second year
        setToJSTTime(year: 2015, month: 12, day: 31, hour: 23, minute: 59, second: 59)
    }
    
    /// Simulate leap second insertion
    public func simulateLeapSecondInsertion() {
        // Advance by 61 seconds instead of 60 to simulate leap second
        advanceTime(by: 61.0)
    }
    
    // MARK: - Time Zone Testing Support
    
    /// Test with different time zones by creating UTC times
    public func setToUTCTime(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) {
        let calendar = Calendar(identifier: .gregorian)
        var calWithUTC = calendar
        calWithUTC.timeZone = TimeZone(identifier: "UTC") ?? .current
        
        let utcDate = calWithUTC.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)) ?? Date()
        setMockDate(utcDate)
    }
    
    // MARK: - Debugging Support
    
    /// Get current state for debugging
    public func debugState() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        return """
        MockClock State:
        - Date (JST): \(formatter.string(from: currentDate()))
        - Host Time: \(currentHostTime())
        - Frequency: \(hostClockFrequency()) Hz
        - Running: \(isRunning)
        - Advancement Rate: \(advancementRate)
        """
    }
}

// MARK: - Convenience Extensions

extension MockClock {
    /// Create a mock clock set to a typical test time
    public static func testClock() -> MockClock {
        return MockClock(date: createJSTTime(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0))
    }
    
    /// Create a mock clock at minute boundary
    public static func minuteBoundaryClock() -> MockClock {
        return MockClock(date: createJSTTime(year: 2025, month: 3, day: 15, hour: 9, minute: 0, second: 0))
    }
    
    /// Create a mock clock near minute rollover
    public static func minuteRolloverClock() -> MockClock {
        return MockClock(date: createJSTTime(year: 2025, month: 6, day: 21, hour: 12, minute: 30, second: 58))
    }
    
    /// Create a mock clock for leap second testing
    public static func leapSecondClock() -> MockClock {
        let clock = MockClock()
        clock.advanceToPreLeapSecond()
        return clock
    }
}

// MARK: - Test Scenario Support

extension MockClock {
    /// Simulate typical JJY operating scenarios
    public enum TestScenario {
        case normalOperation
        case minuteRollover
        case hourRollover
        case leapSecond
        case clockDrift
        case timeZoneTransition
    }
    
    /// Configure the clock for a specific test scenario
    public func configureFor(scenario: TestScenario) {
        switch scenario {
        case .normalOperation:
            setToJSTTime(year: 2025, month: 6, day: 15, hour: 12, minute: 30, second: 25)
            
        case .minuteRollover:
            setToJSTTime(year: 2025, month: 6, day: 15, hour: 12, minute: 59, second: 58)
            
        case .hourRollover:
            setToJSTTime(year: 2025, month: 6, day: 15, hour: 11, minute: 59, second: 58)
            
        case .leapSecond:
            advanceToPreLeapSecond()
            
        case .clockDrift:
            setToJSTTime(year: 2025, month: 6, day: 15, hour: 12, minute: 30, second: 25)
            setAdvancementRate(1.001) // Slight drift
            
        case .timeZoneTransition:
            // Set to a time when daylight saving time changes occur
            setToJSTTime(year: 2025, month: 3, day: 10, hour: 2, minute: 30, second: 0)
        }
    }
}
