//
//  DeterministicBehaviorTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Tests to ensure all components behave deterministically with MockClock
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class DeterministicBehaviorTests: XCTestCase {
    
    // MARK: - MockClock Deterministic Tests
    
    func testMockClockDeterministicBehavior() {
        // Create two identical mock clocks
        let testDate = MockClock.createJSTTime(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)
        let clock1 = MockClock(date: testDate, hostTime: 1000000, frequency: 1000000000)
        let clock2 = MockClock(date: testDate, hostTime: 1000000, frequency: 1000000000)
        
        // Perform identical operations
        let operations = [
            1.0, 0.5, 2.0, 0.1, 5.0, 0.25, 3.0, 0.75, 1.5, 0.333
        ]
        
        var results1: [(Date, UInt64)] = []
        var results2: [(Date, UInt64)] = []
        
        for advancement in operations {
            clock1.advanceTime(by: advancement)
            clock2.advanceTime(by: advancement)
            
            results1.append((clock1.currentDate(), clock1.currentHostTime()))
            results2.append((clock2.currentDate(), clock2.currentHostTime()))
        }
        
        // Results should be identical
        XCTAssertEqual(results1.count, results2.count)
        for i in 0..<results1.count {
            XCTAssertEqual(results1[i].0, results2[i].0, "Dates should be identical at step \(i)")
            XCTAssertEqual(results1[i].1, results2[i].1, "Host times should be identical at step \(i)")
        }
    }
    
    func testMockClockScenarioConsistency() {
        let scenarios: [MockClock.TestScenario] = [
            .normalOperation, .minuteRollover, .hourRollover, .leapSecond, .clockDrift
        ]
        
        for scenario in scenarios {
            // Test each scenario multiple times
            var previousResults: [Date] = []
            
            for iteration in 0..<3 {
                let clock = MockClock.testClock()
                clock.configureFor(scenario: scenario)
                
                var currentResults: [Date] = []
                for _ in 0..<10 {
                    clock.advanceTime(by: 1.0)
                    currentResults.append(clock.currentDate())
                }
                
                if iteration == 0 {
                    previousResults = currentResults
                } else {
                    // Results should be consistent across iterations
                    XCTAssertEqual(currentResults.count, previousResults.count, "Result count should be consistent for scenario \(scenario)")
                    for i in 0..<currentResults.count {
                        XCTAssertEqual(currentResults[i], previousResults[i], "Date should be consistent for scenario \(scenario) at step \(i)")
                    }
                }
            }
        }
    }
    
    // MARK: - FrameService Deterministic Tests
    
    func testFrameServiceDeterministicOutput() {
        let testDate = MockClock.createJSTTime(year: 2025, month: 3, day: 15, hour: 9, minute: 30, second: 0)
        
        // Test configurations that should produce identical results
        let configurations = [
            (enableCallsign: false, enableServiceStatusBits: false, leapSecondPending: false),
            (enableCallsign: true, enableServiceStatusBits: false, leapSecondPending: false),
            (enableCallsign: false, enableServiceStatusBits: true, leapSecondPending: false),
            (enableCallsign: true, enableServiceStatusBits: true, leapSecondPending: true),
        ]
        
        for config in configurations {
            var previousFrames: [[JJYSymbol]] = []
            
            // Generate frames multiple times with identical setup
            for iteration in 0..<3 {
                let clock = MockClock(date: testDate)
                let frameService = FrameService(clock: clock)
                
                var currentFrames: [[JJYSymbol]] = []
                for minute in 0..<5 {
                    clock.advanceTime(by: 60.0) // Advance by one minute
                    
                    let frame = frameService.buildFrame(
                        enableCallsign: config.enableCallsign,
                        enableServiceStatusBits: config.enableServiceStatusBits,
                        leapSecondPlan: nil,
                        leapSecondPending: config.leapSecondPending,
                        leapSecondInserted: true,
                        serviceStatusBits: (false, false, false, false, false, false)
                    )
                    currentFrames.append(frame)
                }
                
                if iteration == 0 {
                    previousFrames = currentFrames
                } else {
                    // Frames should be identical across iterations
                    XCTAssertEqual(currentFrames.count, previousFrames.count, "Frame count should be consistent")
                    for frameIndex in 0..<currentFrames.count {
                        XCTAssertEqual(currentFrames[frameIndex], previousFrames[frameIndex],
                                     "Frame \(frameIndex) should be identical for config \(config)")
                    }
                }
            }
        }
    }
    
    func testFrameServiceTimeBasedConsistency() {
        // Test that frames for specific times are always identical
        let specificTimes = [
            MockClock.createJSTTime(year: 2025, month: 1, day: 1, hour: 0, minute: 0, second: 0),
            MockClock.createJSTTime(year: 2025, month: 6, day: 15, hour: 12, minute: 30, second: 0),
            MockClock.createJSTTime(year: 2025, month: 12, day: 31, hour: 23, minute: 59, second: 0),
        ]
        
        for testTime in specificTimes {
            var referenceFrame: [JJYSymbol]?
            
            for _ in 0..<5 {
                let clock = MockClock(date: testTime)
                let frameService = FrameService(clock: clock)
                
                let frame = frameService.buildFrame(
                    enableCallsign: true,
                    enableServiceStatusBits: true,
                    leapSecondPlan: nil,
                    leapSecondPending: false,
                    leapSecondInserted: true,
                    serviceStatusBits: (true, false, true, false, true, false)
                )
                
                if referenceFrame == nil {
                    referenceFrame = frame
                } else {
                    XCTAssertEqual(frame, referenceFrame!, "Frame should be identical for time \(testTime)")
                }
            }
        }
    }
    
    // MARK: - TransmissionScheduler Deterministic Tests
    
    func testSchedulerDeterministicScheduling() {
        let testDate = MockClock.createJSTTime(year: 2025, month: 1, day: 15, hour: 14, minute: 30, second: 0)
        
        var referenceResults: [(symbol: JJYSymbol, secondIndex: Int)] = []
        
        for iteration in 0..<3 {
            let clock = MockClock(date: testDate)
            let frameService = FrameService(clock: clock)
            let scheduler = TransmissionScheduler(clock: clock, frameService: frameService)
            let delegate = DeterministicMockSchedulerDelegate()
            
            scheduler.delegate = delegate
            scheduler.updateConfiguration(
                enableCallsign: true,
                enableServiceStatusBits: true,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (true, false, true, false, true, false)
            )
            
            // Start scheduling and advance time
            scheduler.startScheduling()
            
            for _ in 0..<10 {
                clock.advanceTime(by: 1.0)
                // Allow scheduling to process
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
            
            scheduler.stopScheduling()
            
            let currentResults = delegate.scheduledSymbols.map { (symbol: $0.symbol, secondIndex: $0.secondIndex) }
            
            if iteration == 0 {
                referenceResults = currentResults
            } else {
                XCTAssertEqual(currentResults.count, referenceResults.count, "Scheduled symbol count should be consistent")
                for i in 0..<min(currentResults.count, referenceResults.count) {
                    XCTAssertEqual(currentResults[i].symbol, referenceResults[i].symbol, "Symbol should be consistent at position \(i)")
                    XCTAssertEqual(currentResults[i].secondIndex, referenceResults[i].secondIndex, "Second index should be consistent at position \(i)")
                }
            }
        }
    }
    
    // MARK: - MorseCodeGenerator Deterministic Tests
    
    func testMorseGeneratorDeterministicOutput() {
        let morse = MorseCodeGenerator()
        let testTimes = Array(stride(from: 0.0, to: 9.0, by: 0.1))
        let ditDurations = [0.05, 0.1, 0.15, 0.2]
        
        for dit in ditDurations {
            var referenceResults: [Bool] = []
            
            for iteration in 0..<3 {
                var currentResults: [Bool] = []
                
                for time in testTimes {
                    currentResults.append(morse.isOnAt(timeInWindow: time, dit: dit))
                }
                
                if iteration == 0 {
                    referenceResults = currentResults
                } else {
                    XCTAssertEqual(currentResults, referenceResults, "Morse pattern should be deterministic for dit \(dit)")
                }
            }
        }
    }
    
    // MARK: - AudioBufferFactory Deterministic Tests
    
    func testBufferFactoryDeterministicGeneration() {
        let morse = MorseCodeGenerator()
        
        let symbols: [JJYSymbol] = [.mark, .bit0, .bit1, .morse]
        let frequencies = [13333.0, 15000.0, 20000.0, 40000.0, 60000.0]
        
        // Create audio format for buffer generation
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 96000,
            channels: 2
        )!
        
        for frequency in frequencies {
            for symbol in symbols {
                var referenceBuffer: AVAudioPCMBuffer?
                
                for iteration in 0..<3 {
                    var phase: Double = 0.0
                    
                    let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
                        symbol: symbol,
                        secondIndex: 0,
                        format: format,
                        carrierFrequency: frequency,
                        outputGain: 1.0,
                        lowAmplitudeScale: 0.1,
                        phase: &phase,
                        morse: morse,
                        waveform: .sine
                    )
                    
                    if iteration == 0 {
                        referenceBuffer = buffer
                    } else {
                        // Compare buffer properties
                        if let curLen = buffer?.frameLength, let refLen = referenceBuffer?.frameLength {
                            XCTAssertEqual(curLen, refLen,
                                         "Buffer frame length should be consistent for \(symbol) at \(frequency)Hz")
                        } else {
                            XCTFail("Missing buffer(s) for frame length comparison")
                        }
                        if let curCh = buffer?.format.channelCount, let refCh = referenceBuffer?.format.channelCount {
                            XCTAssertEqual(curCh, refCh,
                                         "Buffer channel count should be consistent for \(symbol) at \(frequency)Hz")
                        } else {
                            XCTFail("Missing buffer(s) for channel count comparison")
                        }
                        if let curSR = buffer?.format.sampleRate, let refSR = referenceBuffer?.format.sampleRate {
                            XCTAssertEqual(curSR, refSR, accuracy: 0.1,
                                         "Buffer sample rate should be consistent for \(symbol) at \(frequency)Hz")
                        } else {
                            XCTFail("Missing buffer(s) for sample rate comparison")
                        }
                        
                        // Compare first few samples to verify content consistency
                        if let currentBuffer = buffer, let refBuffer = referenceBuffer,
                           let currentData = currentBuffer.floatChannelData,
                           let refData = refBuffer.floatChannelData {
                            
                            let samplesToCompare = min(100, Int(currentBuffer.frameLength))
                            for channel in 0..<Int(currentBuffer.format.channelCount) {
                                for sample in 0..<samplesToCompare {
                                    let cur = Double(currentData[channel][sample])
                                    let ref = Double(refData[channel][sample])
                                    XCTAssertEqual(cur, ref, accuracy: 1e-4,
                                                 "Sample \(sample) in channel \(channel) should be consistent for \(symbol) at \(frequency)Hz")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Integration Deterministic Tests
    
    func testFullSystemDeterministicBehavior() {
        let testDate = MockClock.createJSTTime(year: 2025, month: 6, day: 21, hour: 12, minute: 0, second: 0)
        
        var referenceStates: [(date: Date, frameCount: Int, configCallCount: Int)] = []
        
        for iteration in 0..<3 {
            let clock = MockClock(date: testDate)
            let frameService = FrameService(clock: clock)
            let scheduler = TransmissionScheduler(clock: clock, frameService: frameService)
            let delegate = DeterministicMockSchedulerDelegate()
            
            scheduler.delegate = delegate
            
            // Perform sequence of operations
            let operations = [
                { scheduler.updateConfiguration(enableCallsign: false, enableServiceStatusBits: false,
                                               leapSecondPlan: nil, leapSecondPending: false, leapSecondInserted: true,
                                               serviceStatusBits: (false, false, false, false, false, false)) },
                { clock.advanceTime(by: 30.0) },
                { scheduler.startScheduling() },
                { clock.advanceTime(by: 60.0) },
                { scheduler.updateConfiguration(enableCallsign: true, enableServiceStatusBits: true,
                                               leapSecondPlan: nil, leapSecondPending: false, leapSecondInserted: true,
                                               serviceStatusBits: (true, false, true, false, true, false)) },
                { clock.advanceTime(by: 30.0) },
                { scheduler.stopScheduling() }
            ]
            
            for operation in operations {
                operation()
                // Allow processing
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
            
            let currentState = (
                date: clock.currentDate(),
                frameCount: delegate.frameRebuildCallCount,
                configCallCount: delegate.frameRebuildCallCount
            )
            
            if iteration == 0 {
                referenceStates.append(currentState)
            } else {
                XCTAssertEqual(currentState.date, referenceStates[0].date, "Final clock state should be consistent")
                XCTAssertEqual(currentState.frameCount, referenceStates[0].frameCount, "Frame rebuild count should be consistent")
            }
        }
    }
    
    // MARK: - Edge Case Deterministic Tests
    
    func testEdgeCaseDeterministicBehavior() {
        // Test leap second boundary
        let leapSecondTime = MockClock.createJSTTime(year: 2015, month: 12, day: 31, hour: 23, minute: 59, second: 59)
        
        for _ in 0..<3 {
            let clock = MockClock(date: leapSecondTime)
            let frameService = FrameService(clock: clock)
            
            // Advance through leap second
            clock.advanceTime(by: 2.0) // Cross the leap second boundary
            
            let frame = frameService.buildFrame(
                enableCallsign: false,
                enableServiceStatusBits: false,
                leapSecondPlan: (yearUTC: 2015, monthUTC: 12, kind: .insert),
                leapSecondPending: true,
                leapSecondInserted: false,
                serviceStatusBits: (false, false, false, false, false, false)
            )
            
            // Frame should still be valid
            XCTAssertEqual(frame.count, 60, "Frame should remain valid during leap second")
        }
        
        // Test minute boundary rollover
        let minuteBoundary = MockClock.createJSTTime(year: 2025, month: 3, day: 15, hour: 9, minute: 59, second: 58)
        
        for _ in 0..<3 {
            let clock = MockClock(date: minuteBoundary)
            let frameService = FrameService(clock: clock)
            
            // Cross minute boundary
            clock.advanceTime(by: 3.0)
            
            let frame = frameService.buildFrame(
                enableCallsign: true,
                enableServiceStatusBits: true,
                leapSecondPlan: nil,
                leapSecondPending: false,
                leapSecondInserted: true,
                serviceStatusBits: (true, true, true, true, true, true)
            )
            
            XCTAssertEqual(frame.count, 60, "Frame should remain valid across minute boundary")
        }
    }
}

// MARK: - Helper Mock Delegate

class DeterministicMockSchedulerDelegate: TransmissionSchedulerDelegate {
    var frameRebuildCallCount = 0
    var frameRebuildTimes: [Date] = []
    var secondSchedulingCallCount = 0
    var scheduledSymbols: [(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime?)] = []
    
    func schedulerDidRequestFrameRebuild(for baseTime: Date) {
        frameRebuildCallCount += 1
        frameRebuildTimes.append(baseTime)
    }
    
    func schedulerDidRequestSecondScheduling(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime) {
        secondSchedulingCallCount += 1
        scheduledSymbols.append((symbol: symbol, secondIndex: secondIndex, when: when))
    }
}
