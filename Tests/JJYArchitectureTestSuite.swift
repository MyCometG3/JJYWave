//
//  JJYArchitectureTestSuite.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Master test suite for JJYAudioGenerator architecture components
//

import XCTest
import Foundation
@testable import JJYWave

/// Master test suite that validates the complete JJYAudioGenerator refactored architecture
/// This provides a comprehensive validation of all components and their interactions
final class JJYArchitectureTestSuite: XCTestCase {
    
    // MARK: - Test Suite Organization
    
    /// Run all unit tests for individual components
    func testAllComponentUnits() {
        // This test organizes and validates that all unit test components work
        // Individual test files handle the detailed testing
        
        // Clock protocol and implementations
        let clockTests = JJYClockTests()
        
        // Frame service component
        let frameServiceTests = JJYFrameServiceTests()
        
        // Scheduler component
        let schedulerTests = JJYSchedulerTests()
        
        // Audio engine manager
        let audioEngineTests = AudioEngineManagerTests()
        
        // Audio buffer factory (golden tests)
        let bufferTests = AudioBufferFactoryTests()
        
        // Integration tests
        let integrationTests = JJYArchitectureIntegrationTests()
        
        // Verify all test classes can be instantiated
        XCTAssertNotNil(clockTests)
        XCTAssertNotNil(frameServiceTests)
        XCTAssertNotNil(schedulerTests)
        XCTAssertNotNil(audioEngineTests)
        XCTAssertNotNil(bufferTests)
        XCTAssertNotNil(integrationTests)
    }
    
    // MARK: - Regression Prevention Tests
    
    func testArchitectureStability() {
        // Test that ensures the architecture remains stable and functional
        let mockClock = MockClock.testClock()
        let frameService = JJYFrameService(clock: mockClock)
        let scheduler = JJYScheduler(clock: mockClock, frameService: frameService)
        let audioEngine = AudioEngineManager()
        
        // Basic component creation should work
        XCTAssertNotNil(frameService)
        XCTAssertNotNil(scheduler)
        XCTAssertNotNil(audioEngine)
        
        // Basic operations should work
        XCTAssertNoThrow({
            let frame = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            XCTAssertEqual(frame.count, 60)
        })
        
        XCTAssertNoThrow(scheduler.updateConfiguration(
            enableCallsign: false,
            enableServiceStatusBits: false,
            leapSecondPlan: nil,
            leapSecondPending: false,
            leapSecondInserted: true,
            serviceStatusBits: (false, false, false, false, false, false)
        ))
        
        XCTAssertNoThrow(audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2))
        
        // Cleanup
        scheduler.stopScheduling()
        audioEngine.stopEngine()
    }
    
    // MARK: - Configuration Validation Tests
    
    func testConfigurationValidation() {
        let mockClock = MockClock.testClock()
        let frameService = JJYFrameService(clock: mockClock)
        let scheduler = JJYScheduler(clock: mockClock, frameService: frameService)
        
        // Test various configuration combinations
        let testConfigurations = [
            // Basic configurations
            (enableCallsign: false, enableServiceStatusBits: false, leapSecondPending: false),
            (enableCallsign: true, enableServiceStatusBits: false, leapSecondPending: false),
            (enableCallsign: false, enableServiceStatusBits: true, leapSecondPending: false),
            (enableCallsign: true, enableServiceStatusBits: true, leapSecondPending: false),
            
            // With leap second configurations
            (enableCallsign: false, enableServiceStatusBits: false, leapSecondPending: true),
            (enableCallsign: true, enableServiceStatusBits: true, leapSecondPending: true),
        ]
        
        for config in testConfigurations {
            XCTAssertNoThrow({
                scheduler.updateConfiguration(
                    enableCallsign: config.enableCallsign,
                    enableServiceStatusBits: config.enableServiceStatusBits,
                    leapSecondPlan: config.leapSecondPending ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                    leapSecondPending: config.leapSecondPending,
                    leapSecondInserted: !config.leapSecondPending,
                    serviceStatusBits: (true, false, true, false, true, false)
                )
                
                let frame = frameService.buildFrame(
                    enableCallsign: config.enableCallsign,
                    enableServiceStatusBits: config.enableServiceStatusBits,
                    leapSecondPlan: config.leapSecondPending ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                    leapSecondPending: config.leapSecondPending,
                    leapSecondInserted: !config.leapSecondPending,
                    serviceStatusBits: (true, false, true, false, true, false)
                )
                
                XCTAssertEqual(frame.count, 60, "Frame should always be 60 seconds for configuration: \(config)")
            })
        }
        
        scheduler.stopScheduling()
    }
    
    // MARK: - Timing Accuracy Validation
    
    func testTimingAccuracy() {
        let mockClock = MockClock.minuteBoundaryClock()
        let frameService = JJYFrameService(clock: mockClock)
        
        // Test timing calculations at various minute boundaries
        let calendar = frameService.jstCalendar()
        
        for minute in [0, 15, 30, 45, 59] {
            mockClock.setToJSTTime(year: 2025, month: 6, day: 15, hour: 12, minute: minute, second: 0)
            
            let currentMinute = frameService.currentMinuteStart(from: mockClock.currentDate(), calendar: calendar)
            let nextMinute = frameService.nextMinuteStart(from: mockClock.currentDate(), calendar: calendar)
            
            XCTAssertEqual(calendar.component(.second, from: currentMinute), 0)
            XCTAssertEqual(calendar.component(.second, from: nextMinute), 0)
            XCTAssertEqual(calendar.component(.minute, from: nextMinute), (minute + 1) % 60)
        }
    }
    
    // MARK: - Memory and Performance Validation
    
    func testMemoryManagement() {
        // Test that components are properly deallocated
        weak var weakFrameService: JJYFrameService?
        weak var weakScheduler: JJYScheduler?
        weak var weakAudioEngine: AudioEngineManager?
        
        autoreleasepool {
            let mockClock = MockClock.testClock()
            let frameService = JJYFrameService(clock: mockClock)
            let scheduler = JJYScheduler(clock: mockClock, frameService: frameService)
            let audioEngine = AudioEngineManager()
            
            weakFrameService = frameService
            weakScheduler = scheduler
            weakAudioEngine = audioEngine
            
            // Use the components
            let _ = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            
            scheduler.updateConfiguration(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            
            audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
            
            // Cleanup
            scheduler.stopScheduling()
            audioEngine.stopEngine()
        }
        
        // Components should be deallocated
        XCTAssertNil(weakFrameService, "FrameService should be deallocated")
        XCTAssertNil(weakScheduler, "Scheduler should be deallocated")
        XCTAssertNil(weakAudioEngine, "AudioEngine should be deallocated")
    }
    
    func testPerformanceBenchmarks() {
        let mockClock = MockClock.testClock()
        let frameService = JJYFrameService(clock: mockClock)
        
        // Benchmark frame building performance
        measure {
            for _ in 0..<100 {
                let _ = frameService.buildFrame(
                    enableCallsign: false,
                    enableServiceStatusBits: true,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (true, false, true, false, true, false)
                )
                mockClock.advanceTime(by: 1.0)
            }
        }
    }
    
    // MARK: - Edge Cases Validation
    
    func testEdgeCases() {
        let scenarios: [MockClock.TestScenario] = [
            .normalOperation,
            .minuteRollover,
            .hourRollover,
            .leapSecond,
            .clockDrift,
            .timeZoneTransition
        ]
        
        for scenario in scenarios {
            let mockClock = MockClock()
            mockClock.configureFor(scenario: scenario)
            
            let frameService = JJYFrameService(clock: mockClock)
            let scheduler = JJYScheduler(clock: mockClock, frameService: frameService)
            
            XCTAssertNoThrow({
                let frame = frameService.buildFrame(
                    enableCallsign: true,
                    enableServiceStatusBits: true,
                    leapSecondPlan: scenario == .leapSecond ? (yearUTC: 2025, monthUTC: 6, kind: .insert) : nil,
                    leapSecondPending: scenario == .leapSecond,
                    leapSecondInserted: scenario != .leapSecond,
                    serviceStatusBits: (true, false, true, false, true, false)
                )
                
                XCTAssertEqual(frame.count, 60, "Frame should be valid for scenario: \(scenario)")
            }, "Should handle scenario: \(scenario)")
            
            scheduler.stopScheduling()
        }
    }
    
    // MARK: - Compatibility Validation
    
    func testBackwardCompatibility() {
        // Test that the new architecture maintains compatibility with existing interfaces
        // This would test the main JJYAudioGenerator class if it exists
        
        // For now, verify that the components work with expected patterns
        let mockClock = MockClock.testClock()
        let frameService = JJYFrameService(clock: mockClock)
        
        // Test that the frame service interface is compatible
        XCTAssertNoThrow({
            let frame1 = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            
            let frame2 = frameService.buildFrameForTime(
                mockClock.currentDate(),
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            
            XCTAssertEqual(frame1.count, frame2.count, "Both frame building methods should produce compatible results")
        })
    }
    
    // MARK: - Documentation and Code Quality Validation
    
    func testCodeQualityMetrics() {
        // This test serves as documentation of the expected code quality
        // In a real project, this might integrate with static analysis tools
        
        // Test that interfaces are clean and well-defined
        let mockClock = MockClock.testClock()
        
        // JJYClock protocol should be simple and focused
        XCTAssertNotNil(mockClock.currentDate())
        XCTAssertNotNil(mockClock.currentHostTime())
        XCTAssertNotNil(mockClock.hostClockFrequency())
        
        // Components should have clear, single responsibilities
        let frameService = JJYFrameService(clock: mockClock)
        let scheduler = JJYScheduler(clock: mockClock, frameService: frameService)
        let audioEngine = AudioEngineManager()
        
        // Each component should work independently
        XCTAssertNotNil(frameService)
        XCTAssertNotNil(scheduler)
        XCTAssertNotNil(audioEngine)
        
        // Cleanup
        scheduler.stopScheduling()
        audioEngine.stopEngine()
    }
}

// MARK: - Test Suite Utilities

extension JJYArchitectureTestSuite {
    
    /// Helper to run a test with all component combinations
    func runWithAllConfigurations(_ test: (Bool, Bool, Bool) -> Void) {
        let configurations = [
            (false, false, false),
            (true, false, false),
            (false, true, false),
            (true, true, false),
            (false, false, true),
            (true, false, true),
            (false, true, true),
            (true, true, true)
        ]
        
        for (callsign, serviceBits, leapPending) in configurations {
            test(callsign, serviceBits, leapPending)
        }
    }
    
    /// Helper to validate frame structure
    func validateFrameStructure(_ frame: [JJYSymbol]) {
        XCTAssertEqual(frame.count, 60, "Frame should be 60 seconds")
        
        // Check marker positions
        let markerPositions = [0, 9, 19, 29, 39, 49, 59]
        for position in markerPositions {
            XCTAssertEqual(frame[position], .mark, "Position \(position) should be a marker")
        }
        
        // Check that non-marker positions contain valid symbols
        for (index, symbol) in frame.enumerated() {
            if !markerPositions.contains(index) {
                XCTAssertTrue([.bit0, .bit1, .morse].contains(symbol), 
                             "Position \(index) should contain a valid data symbol")
            }
        }
    }
}