import Foundation

// MARK: - MockClock for Testing
/// A mock clock that allows setting specific times for testing
class MockClock: JJYClock {
    private var mockDate: Date
    private var mockHostTime: UInt64
    private var mockFrequency: Double
    
    init(date: Date = Date(), hostTime: UInt64 = 1000000, frequency: Double = 1000000000) {
        self.mockDate = date
        self.mockHostTime = hostTime
        self.mockFrequency = frequency
    }
    
    func currentDate() -> Date {
        return mockDate
    }
    
    func currentHostTime() -> UInt64 {
        return mockHostTime
    }
    
    func hostClockFrequency() -> Double {
        return mockFrequency
    }
    
    // MARK: - Test Methods
    func setMockDate(_ date: Date) {
        self.mockDate = date
    }
    
    func setMockHostTime(_ hostTime: UInt64) {
        self.mockHostTime = hostTime
    }
    
    func advanceTime(by seconds: TimeInterval) {
        self.mockDate = mockDate.addingTimeInterval(seconds)
        self.mockHostTime += UInt64(seconds * mockFrequency)
    }
}

// MARK: - Example Usage and Testing
/// Example of how the refactored architecture can be tested
class JJYComponentsExample {
    
    // Example: Testing frame service with mock clock
    static func testFrameServiceWithMockTime() {
        // Create a mock clock set to a specific time
        let calendar = Calendar(identifier: .gregorian)
        var calWithJST = calendar
        calWithJST.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        
        // Set to a specific test time: 2025-01-15 14:30:00 JST
        let testDate = calWithJST.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)) ?? Date()
        let mockClock = MockClock(date: testDate)
        
        // Create frame service with mock clock
        let frameService = JJYFrameService(clock: mockClock)
        
        // Build a frame - this will use the mock time
        let frame = frameService.buildFrame(
            enableCallsign: true,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        print("Frame built for mock time: \(testDate)")
        print("Frame length: \(frame.count) seconds")
        
        // Verify the frame contains expected markers
        let markers = [0, 9, 19, 29, 39, 49, 59]
        for marker in markers {
            if marker < frame.count {
                assert(frame[marker] == .mark, "Expected marker at second \(marker)")
            }
        }
        print("Frame validation passed!")
    }
    
    // Example: Testing scheduler in isolation
    static func testSchedulerBehavior() {
        let mockClock = MockClock()
        let frameService = JJYFrameService(clock: mockClock)
        
        // Create scheduler with mock dependencies
        let scheduler = JJYScheduler(clock: mockClock, frameService: frameService)
        
        // Set up configuration
        scheduler.updateConfiguration(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        )
        
        print("Scheduler configured successfully")
        
        // Test that scheduler can be started and stopped without actual audio
        // (Note: In a real test, you'd use a mock delegate to verify the scheduled calls)
        
        print("Scheduler behavior test completed")
    }
}

// MARK: - Run Examples
/// Uncomment to run examples when testing the refactored code
/*
print("=== JJY Components Testing ===")
JJYComponentsExample.testFrameServiceWithMockTime()
JJYComponentsExample.testSchedulerBehavior()
print("=== All Tests Passed ===")
*/

// MARK: - Note for Comprehensive Testing
/// For comprehensive unit and integration tests, see the Tests/ directory:
/// - JJYClockTests.swift: Tests for JJYClock protocol and implementations
/// - JJYFrameServiceTests.swift: Tests for frame construction and leap second logic
/// - JJYSchedulerTests.swift: Tests for timing, scheduling, and drift detection
/// - AudioEngineManagerTests.swift: Tests for audio engine management
/// - AudioBufferFactoryTests.swift: Golden tests for audio buffer generation
/// - JJYArchitectureIntegrationTests.swift: Integration tests for component interactions
/// - JJYArchitectureTestSuite.swift: Master test suite and regression prevention
/// - MockClock.swift: Enhanced mock clock for deterministic testing
///
/// These tests provide comprehensive coverage of:
/// - Unit tests for each refactored component
/// - Configuration validation
/// - Minute rollover and leap second handling
/// - Drift resync policy and timing coordination
/// - Golden tests for audio buffer validation (duty cycle, amplitude, etc.)
/// - Integration tests ensuring components work together correctly
/// - Thread safety and performance validation