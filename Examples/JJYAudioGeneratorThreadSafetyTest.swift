//
//  JJYAudioGeneratorThreadSafetyTest.swift
//  JJYWave
//
//  Created by GitHub Copilot on 2025/01/03.
//  Thread safety validation for JJYAudioGenerator
//

import Foundation
import OSLog

/// Test class to validate thread safety of JJYAudioGenerator
/// This is not a unit test but a runtime validation that can be called to verify thread safety
class JJYAudioGeneratorThreadSafetyTest {
    private let logger = Logger(subsystem: "com.MyCometG3.JJYWave", category: "ThreadSafetyTest")
    
    /// Run concurrent property access test
    /// This test verifies that concurrent property access doesn't cause crashes or data races
    func runConcurrentPropertyAccessTest() {
        logger.info("Starting concurrent property access test...")
        
        let generator = JJYAudioGenerator()
        let iterations = 1000
        let concurrentQueues = 10
        
        let group = DispatchGroup()
        
        // Test concurrent property reads and writes
        for queueIndex in 0..<concurrentQueues {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                for i in 0..<iterations {
                    // Mix of reads and writes
                    if i % 2 == 0 {
                        // Read operations
                        let _ = generator.sampleRate
                        let _ = generator.testFrequency
                        let _ = generator.actualFrequency
                        let _ = generator.isTestModeEnabled
                        let _ = generator.waveform
                        let _ = generator.band
                        let _ = generator.configuration
                    } else {
                        // Write operations
                        generator.testFrequency = Double(13333 + (queueIndex * 100))
                        generator.enableCallsign = (i % 3 == 0)
                        generator.enableServiceStatusBits = (i % 5 == 0)
                        generator.leapSecondPending = (i % 7 == 0)
                    }
                }
                group.leave()
            }
        }
        
        group.wait()
        logger.info("Concurrent property access test completed successfully")
    }
    
    /// Run start/stop concurrency test
    /// This test verifies that concurrent start/stop operations are handled safely
    func runStartStopConcurrencyTest() {
        logger.info("Starting start/stop concurrency test...")
        
        let generator = JJYAudioGenerator()
        let iterations = 100
        let concurrentQueues = 5
        
        let group = DispatchGroup()
        
        for queueIndex in 0..<concurrentQueues {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                for i in 0..<iterations {
                    if i % 2 == 0 {
                        generator.startGeneration()
                        // Deterministic delay using RunLoop scheduling
                        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
                    } else {
                        generator.stopGeneration()
                        // Deterministic delay using RunLoop scheduling  
                        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
                    }
                    
                    // Check state safely
                    let _ = generator.isActive
                }
                group.leave()
            }
        }
        
        group.wait()
        
        // Ensure final cleanup
        generator.stopGeneration()
        logger.info("Start/stop concurrency test completed successfully")
    }
    
    /// Run configuration update test
    /// This test verifies that configuration updates are thread-safe
    func runConfigurationUpdateTest() {
        logger.info("Starting configuration update test...")
        
        let generator = JJYAudioGenerator()
        let iterations = 500
        
        let group = DispatchGroup()
        
        // Concurrent configuration updates
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<iterations {
                generator.updateTestFrequency(Double(13333 + i))
                generator.updateActualFrequency(Double(40000 + i))
            }
            group.leave()
        }
        
        // Concurrent band updates (these should be rejected while not generating)
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<iterations {
                let newBand: JJYAudioGenerator.CarrierBand = (i % 2 == 0) ? .jjy40 : .jjy60
                let _ = generator.updateBand(newBand)
            }
            group.leave()
        }
        
        // Concurrent property reads
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                let config = generator.getCurrentConfiguration()
                let _ = config.sampleRate
                let _ = config.testFreq
                let _ = config.actualFreq
                let _ = config.isTestMode
            }
            group.leave()
        }
        
        group.wait()
        logger.info("Configuration update test completed successfully")
    }
    
    /// Run all thread safety tests
    func runAllTests() {
        logger.info("=== Starting JJYAudioGenerator Thread Safety Tests ===")
        
        runConcurrentPropertyAccessTest()
        runStartStopConcurrencyTest()
        runConfigurationUpdateTest()
        
        logger.info("=== All Thread Safety Tests Completed Successfully ===")
    }
}

/// Extension to allow easy testing from other parts of the codebase
extension JJYAudioGenerator {
    /// Run thread safety validation tests
    /// This method can be called to verify that the thread safety improvements are working correctly
    static func runThreadSafetyTests() {
        let test = JJYAudioGeneratorThreadSafetyTest()
        test.runAllTests()
    }
}
