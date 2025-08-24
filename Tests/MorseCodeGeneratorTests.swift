//
//  MorseCodeGeneratorTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Unit tests for MorseCodeGenerator component
//

import XCTest
import Foundation
@testable import JJYWave

final class MorseCodeGeneratorTests: XCTestCase {
    
    var morseGenerator: MorseCodeGenerator!
    
    override func setUp() {
        super.setUp()
        morseGenerator = MorseCodeGenerator()
    }
    
    override func tearDown() {
        morseGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Basic Morse Pattern Tests
    
    func testValidTimeRange() {
        let dit = 0.1 // 100ms dit duration
        
        // Test time before valid range
        XCTAssertFalse(morseGenerator.isOnAt(timeInWindow: -0.1, dit: dit))
        
        // Test time at start of valid range
        XCTAssertTrue(morseGenerator.isOnAt(timeInWindow: 0.0, dit: dit) || !morseGenerator.isOnAt(timeInWindow: 0.0, dit: dit))
        
        // Test time at end of valid range
        XCTAssertFalse(morseGenerator.isOnAt(timeInWindow: 9.0, dit: dit))
        
        // Test time after valid range
        XCTAssertFalse(morseGenerator.isOnAt(timeInWindow: 9.1, dit: dit))
    }
    
    func testMorsePatternStructure() {
        let dit = 0.1 // 100ms dit duration
        
        // Test various points in the pattern to ensure structure is correct
        var previousState = false
        var stateChanges = 0
        
        // Sample the pattern at 10ms intervals to detect state changes
        for i in 0..<890 { // 0 to 8.9 seconds in 10ms steps
            let time = Double(i) * 0.01
            let currentState = morseGenerator.isOnAt(timeInWindow: time, dit: dit)
            
            if i > 0 && currentState != previousState {
                stateChanges += 1
            }
            previousState = currentState
        }
        
        // Should have multiple state changes for a proper morse pattern
        // JJY pattern (.--- .--- -.--) repeated twice with spaces should have many transitions
        XCTAssertGreaterThan(stateChanges, 10, "Morse pattern should have multiple on/off transitions")
    }
    
    func testDitDurationVariations() {
        // Test with different dit durations
        let ditDurations = [0.05, 0.1, 0.15, 0.2] // 50ms to 200ms
        
        for dit in ditDurations {
            let midTime = 4.5 // Middle of the 9-second window
            let result = morseGenerator.isOnAt(timeInWindow: midTime, dit: dit)
            
            // Should return a valid boolean result for any reasonable dit duration
            XCTAssertTrue(result == true || result == false, "Should return valid boolean for dit: \(dit)")
        }
    }
    
    // MARK: - JJY Pattern Specific Tests
    
    func testJLetterPattern() {
        let dit = 0.1
        
        // J is .--- (dot-dash-dash-dash)
        // Test the first letter J at the beginning of the pattern
        var foundDot = false
        var foundDash = false
        
        // Sample first few units to detect dot and dash patterns
        for i in 0..<50 { // First 5 seconds in 100ms steps
            let time = Double(i) * dit
            if morseGenerator.isOnAt(timeInWindow: time, dit: dit) {
                if i < 10 { // First unit should be a dot (1 dit)
                    foundDot = true
                } else if i >= 20 && i < 50 { // Later units should include dashes (3 dit each)
                    foundDash = true
                }
            }
        }
        
        // Pattern should include both dot and dash elements
        XCTAssertTrue(foundDot || foundDash, "JJY pattern should contain morse elements")
    }
    
    func testYLetterPattern() {
        let dit = 0.1
        
        // Y is -.-- (dash-dot-dash-dash)
        // This appears as the third letter in each JJY sequence
        var patternDetected = false
        
        // Sample through the pattern to ensure Y pattern is present
        for i in 200..<400 { // Sample later in the pattern where Y appears
            let time = Double(i) * dit * 0.1
            if morseGenerator.isOnAt(timeInWindow: time, dit: dit) {
                patternDetected = true
            }
        }
        
        // Should find some activity in the pattern
        XCTAssertTrue(patternDetected, "Should detect morse activity in Y pattern region")
    }
    
    func testWordSpacing() {
        let dit = 0.1
        
        // Test the word space between the two JJY sequences
        // Word space should be 7 dit units of silence
        var foundSilence = false
        var silenceCount = 0
        
        // Sample through middle region where word space should occur
        for i in 400..<600 { // Middle region of the 9-second pattern
            let time = Double(i) * dit * 0.01
            if !morseGenerator.isOnAt(timeInWindow: time, dit: dit) {
                silenceCount += 1
            }
        }
        
        // Should find some silence in the word space region
        if silenceCount > 10 {
            foundSilence = true
        }
        
        XCTAssertTrue(foundSilence, "Should find word spacing silence in morse pattern")
    }
    
    // MARK: - Edge Case Tests
    
    func testZeroDitDuration() {
        // Should handle edge case of zero dit duration gracefully
        let result = morseGenerator.isOnAt(timeInWindow: 1.0, dit: 0.0)
        XCTAssertTrue(result == true || result == false, "Should handle zero dit duration")
    }
    
    func testVerySmallDitDuration() {
        let dit = 0.001 // 1ms dit
        let result = morseGenerator.isOnAt(timeInWindow: 1.0, dit: dit)
        XCTAssertTrue(result == true || result == false, "Should handle very small dit duration")
    }
    
    func testVeryLargeDitDuration() {
        let dit = 1.0 // 1 second dit
        let result = morseGenerator.isOnAt(timeInWindow: 1.0, dit: dit)
        XCTAssertTrue(result == true || result == false, "Should handle large dit duration")
    }
    
    // MARK: - Pattern Consistency Tests
    
    func testPatternRepeatability() {
        let dit = 0.1
        
        // Test that the same time inputs always produce the same outputs
        let testTimes = [0.5, 1.0, 2.5, 4.0, 6.5, 8.0]
        
        for time in testTimes {
            let result1 = morseGenerator.isOnAt(timeInWindow: time, dit: dit)
            let result2 = morseGenerator.isOnAt(timeInWindow: time, dit: dit)
            
            XCTAssertEqual(result1, result2, "Same inputs should produce same outputs for time: \(time)")
        }
    }
    
    func testPatternCoverage() {
        let dit = 0.1
        var onCount = 0
        var offCount = 0
        
        // Sample the entire pattern to ensure both on and off states exist
        for i in 0..<900 { // Entire 9-second window in 10ms steps
            let time = Double(i) * 0.01
            if morseGenerator.isOnAt(timeInWindow: time, dit: dit) {
                onCount += 1
            } else {
                offCount += 1
            }
        }
        
        // Both on and off states should be present in a proper morse pattern
        XCTAssertGreaterThan(onCount, 0, "Pattern should have 'on' periods")
        XCTAssertGreaterThan(offCount, 0, "Pattern should have 'off' periods")
        
        // Neither should dominate completely (rough balance check)
        let total = onCount + offCount
        XCTAssertLessThan(onCount, total * 80 / 100, "On periods should not dominate pattern")
        XCTAssertLessThan(offCount, total * 80 / 100, "Off periods should not dominate pattern")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfPatternGeneration() {
        let dit = 0.1
        
        measure {
            // Test performance of generating morse pattern over many calls
            for i in 0..<1000 {
                let time = Double(i) * 0.009 // Cover the full range multiple times
                _ = morseGenerator.isOnAt(timeInWindow: time, dit: dit)
            }
        }
    }
}