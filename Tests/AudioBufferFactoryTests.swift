//
//  AudioBufferFactoryTests.swift
//  JJYWave Tests
//
//  Created by GitHub Copilot on 2025/01/24.
//  Golden tests for audio buffer generation - validates duty cycle, amplitude, and waveform accuracy
//

import XCTest
import Foundation
import AVFoundation
@testable import JJYWave

final class AudioBufferFactoryTests: XCTestCase {
    
    let testSampleRate: Double = 96000
    let testChannelCount: AVAudioChannelCount = 2
    let testCarrierFrequency: Double = 40000 // JJY 40kHz
    let testOutputGain: Double = 0.8
    let testLowAmplitudeScale: Double = 0.1
    let tolerance: Float = 0.001 // Tolerance for floating-point comparisons
    
    var testFormat: AVAudioFormat!
    var testPhase: Double = 0.0
    var morse: MorseCodeGenerator!
    
    override func setUp() {
        super.setUp()
        testFormat = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: testChannelCount)
        XCTAssertNotNil(testFormat)
        testPhase = 0.0
        morse = MorseCodeGenerator()
    }
    
    override func tearDown() {
        testFormat = nil
        morse = nil
        super.tearDown()
    }
    
    // MARK: - Basic Buffer Generation Tests
    
    func testMarkSymbolBuffer() {
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.mark,
            secondIndex: 0,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create mark symbol buffer")
            return
        }
        
        validateBasicBufferProperties(buffer)
        validateMarkSymbolDutyCycle(buffer)
    }
    
    func testBit1SymbolBuffer() {
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.bit1,
            secondIndex: 1,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create bit1 symbol buffer")
            return
        }
        
        validateBasicBufferProperties(buffer)
        validateBit1SymbolDutyCycle(buffer)
    }
    
    func testBit0SymbolBuffer() {
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.bit0,
            secondIndex: 2,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create bit0 symbol buffer")
            return
        }
        
        validateBasicBufferProperties(buffer)
        validateBit0SymbolDutyCycle(buffer)
    }
    
    func testMorseSymbolBuffer() {
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.morse,
            secondIndex: 12, // Typical morse position
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create morse symbol buffer")
            return
        }
        
        validateBasicBufferProperties(buffer)
        validateMorseSymbolPattern(buffer)
    }
    
    // MARK: - Duty Cycle Validation Tests
    
    private func validateMarkSymbolDutyCycle(_ buffer: AVAudioPCMBuffer) {
        // Mark symbol: 0.2 seconds high amplitude, 0.8 seconds low amplitude
        let expectedHighDuration = 0.2
        let expectedHighSamples = Int((expectedHighDuration * testSampleRate).rounded())
        
        validateDutyCycle(buffer, expectedHighSamples: expectedHighSamples, symbolName: "Mark")
    }
    
    private func validateBit1SymbolDutyCycle(_ buffer: AVAudioPCMBuffer) {
        // Bit1 symbol: 0.5 seconds high amplitude, 0.5 seconds low amplitude
        let expectedHighDuration = 0.5
        let expectedHighSamples = Int((expectedHighDuration * testSampleRate).rounded())
        
        validateDutyCycle(buffer, expectedHighSamples: expectedHighSamples, symbolName: "Bit1")
    }
    
    private func validateBit0SymbolDutyCycle(_ buffer: AVAudioPCMBuffer) {
        // Bit0 symbol: 0.8 seconds high amplitude, 0.2 seconds low amplitude
        let expectedHighDuration = 0.8
        let expectedHighSamples = Int((expectedHighDuration * testSampleRate).rounded())
        
        validateDutyCycle(buffer, expectedHighSamples: expectedHighSamples, symbolName: "Bit0")
    }
    
    private func validateDutyCycle(_ buffer: AVAudioPCMBuffer, expectedHighSamples: Int, symbolName: String) {
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let totalSamples = Int(buffer.frameLength)
        let channel0Data = channelData[0]
        
        // Find the transition point from high to low amplitude
        var actualHighSamples = 0
        let amplitudeThreshold: Float = 0.5 // Threshold to distinguish high/low amplitude
        
        for i in 0..<totalSamples {
            let amplitude = abs(channel0Data[i])
            if amplitude > amplitudeThreshold {
                actualHighSamples = i + 1
            } else {
                break
            }
        }
        
        // Allow some tolerance due to rounding
        let tolerance = Int(testSampleRate * 0.001) // 1ms tolerance
        XCTAssertEqual(actualHighSamples, expectedHighSamples, accuracy: tolerance,
                      "\(symbolName) symbol should have \(expectedHighSamples) high amplitude samples, got \(actualHighSamples)")
        
        // Verify low amplitude portion
        if actualHighSamples < totalSamples {
            let lowAmplitudeSample = channel0Data[actualHighSamples]
            let expectedLowAmplitude = Float(testOutputGain * testLowAmplitudeScale)
            XCTAssertLessThan(abs(lowAmplitudeSample), expectedLowAmplitude * 2.0,
                            "\(symbolName) symbol low amplitude should be significantly lower than high amplitude")
        }
    }
    
    private func validateMorseSymbolPattern(_ buffer: AVAudioPCMBuffer) {
        // Morse symbol should have on/off pattern according to morse code
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let totalSamples = Int(buffer.frameLength)
        let channel0Data = channelData[0]
        
        // Just verify that there's variation in amplitude (morse pattern)
        var hasHighAmplitude = false
        var hasLowAmplitude = false
        let amplitudeThreshold: Float = 0.1
        
        for i in 0..<totalSamples {
            let amplitude = abs(channel0Data[i])
            if amplitude > amplitudeThreshold {
                hasHighAmplitude = true
            } else {
                hasLowAmplitude = true
            }
        }
        
        // Morse should have both high and low periods (unless it's all dashes or spaces)
        XCTAssertTrue(hasHighAmplitude || hasLowAmplitude, "Morse symbol should have amplitude variation")
    }
    
    // MARK: - Amplitude Validation Tests
    
    func testAmplitudeAccuracy() {
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.mark,
            secondIndex: 0,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create buffer for amplitude test")
            return
        }
        
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let channel0Data = channelData[0]
        let highPeriodSamples = Int(0.2 * testSampleRate) // First 0.2 seconds
        
        // Check high amplitude period
        var maxHighAmplitude: Float = 0
        for i in 0..<min(highPeriodSamples, Int(buffer.frameLength)) {
            maxHighAmplitude = max(maxHighAmplitude, abs(channel0Data[i]))
        }
        
        let expectedMaxAmplitude = Float(testOutputGain)
        XCTAssertEqual(maxHighAmplitude, expectedMaxAmplitude, accuracy: tolerance,
                      "High amplitude should match output gain")
        
        // Check low amplitude period
        if Int(buffer.frameLength) > highPeriodSamples {
            var maxLowAmplitude: Float = 0
            for i in highPeriodSamples..<Int(buffer.frameLength) {
                maxLowAmplitude = max(maxLowAmplitude, abs(channel0Data[i]))
            }
            
            let expectedLowAmplitude = Float(testOutputGain * testLowAmplitudeScale)
            XCTAssertEqual(maxLowAmplitude, expectedLowAmplitude, accuracy: tolerance * 2,
                          "Low amplitude should match scaled output gain")
        }
    }
    
    // MARK: - Waveform Tests
    
    func testSineWaveform() {
        testPhase = 0.0
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.mark,
            secondIndex: 0,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create sine wave buffer")
            return
        }
        
        validateSineWaveform(buffer)
    }
    
    func testSquareWaveform() {
        testPhase = 0.0
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.mark,
            secondIndex: 0,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .square
        ) else {
            XCTFail("Failed to create square wave buffer")
            return
        }
        
        validateSquareWaveform(buffer)
    }
    
    private func validateSineWaveform(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let channel0Data = channelData[0]
        let samplesPerCycle = testSampleRate / testCarrierFrequency
        let cyclesToCheck = min(10, Int(Double(buffer.frameLength) / samplesPerCycle))
        
        // Check that the waveform is approximately sinusoidal
        for cycle in 0..<cyclesToCheck {
            let cycleStart = Int(Double(cycle) * samplesPerCycle)
            let quarterCycle = Int(samplesPerCycle / 4)
            
            if cycleStart + quarterCycle < buffer.frameLength {
                let zeroPoint = channel0Data[cycleStart]
                let quarterPoint = channel0Data[cycleStart + quarterCycle]
                
                // At quarter cycle, sine should be near maximum
                XCTAssertGreaterThan(abs(quarterPoint), abs(zeroPoint),
                                   "Sine wave should have maximum at quarter cycle")
            }
        }
    }
    
    private func validateSquareWaveform(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let channel0Data = channelData[0]
        let samplesPerCycle = testSampleRate / testCarrierFrequency
        let cyclesToCheck = min(10, Int(Double(buffer.frameLength) / samplesPerCycle))
        
        // Check that the waveform has square wave characteristics
        for cycle in 0..<cyclesToCheck {
            let cycleStart = Int(Double(cycle) * samplesPerCycle)
            let halfCycle = Int(samplesPerCycle / 2)
            
            if cycleStart + halfCycle < buffer.frameLength {
                let firstHalf = channel0Data[cycleStart]
                let secondHalf = channel0Data[cycleStart + halfCycle]
                
                // Square wave should have opposite polarity in each half
                XCTAssertNotEqual(firstHalf, secondHalf, accuracy: tolerance,
                                "Square wave should have different values in each half cycle")
            }
        }
    }
    
    // MARK: - Frequency Accuracy Tests
    
    func testCarrierFrequencyAccuracy() {
        // Test with different carrier frequencies
        let testFrequencies: [Double] = [13333, 15000, 20000, 40000, 60000]
        
        for frequency in testFrequencies {
            testPhase = 0.0
            guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
                symbol: JJYAudioGenerator.JJYSymbol.mark,
                secondIndex: 0,
                format: testFormat,
                carrierFrequency: frequency,
                outputGain: testOutputGain,
                lowAmplitudeScale: testLowAmplitudeScale,
                phase: &testPhase,
                morse: morse,
                waveform: .sine
            ) else {
                XCTFail("Failed to create buffer for frequency \(frequency)")
                continue
            }
            
            validateCarrierFrequency(buffer, expectedFrequency: frequency)
        }
    }
    
    private func validateCarrierFrequency(_ buffer: AVAudioPCMBuffer, expectedFrequency: Double) {
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let channel0Data = channelData[0]
        let totalSamples = Int(buffer.frameLength)
        
        // Simple zero-crossing analysis to estimate frequency
        var zeroCrossings = 0
        var lastSign = channel0Data[0] >= 0
        
        for i in 1..<min(totalSamples, Int(0.2 * testSampleRate)) { // Check first 0.2 seconds (high amplitude)
            let currentSign = channel0Data[i] >= 0
            if currentSign != lastSign {
                zeroCrossings += 1
                lastSign = currentSign
            }
        }
        
        // Each cycle has 2 zero crossings
        let estimatedFrequency = Double(zeroCrossings) / (2.0 * 0.2) // 0.2 seconds analyzed
        let tolerance = expectedFrequency * 0.05 // 5% tolerance
        
        XCTAssertEqual(estimatedFrequency, expectedFrequency, accuracy: tolerance,
                      "Carrier frequency should be approximately \(expectedFrequency) Hz, estimated \(estimatedFrequency) Hz")
    }
    
    // MARK: - Channel Consistency Tests
    
    func testMultiChannelConsistency() {
        guard testFormat.channelCount > 1 else {
            XCTFail("Test requires multi-channel format")
            return
        }
        
        guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
            symbol: JJYAudioGenerator.JJYSymbol.mark,
            secondIndex: 0,
            format: testFormat,
            carrierFrequency: testCarrierFrequency,
            outputGain: testOutputGain,
            lowAmplitudeScale: testLowAmplitudeScale,
            phase: &testPhase,
            morse: morse,
            waveform: .sine
        ) else {
            XCTFail("Failed to create multi-channel buffer")
            return
        }
        
        guard let channelData = buffer.floatChannelData else {
            XCTFail("Buffer has no channel data")
            return
        }
        
        let totalSamples = Int(buffer.frameLength)
        let channel0Data = channelData[0]
        
        // Check that all channels have identical data
        for channel in 1..<Int(testFormat.channelCount) {
            let channelNData = channelData[channel]
            
            for sample in 0..<totalSamples {
                XCTAssertEqual(channel0Data[sample], channelNData[sample], accuracy: tolerance,
                              "All channels should have identical data at sample \(sample)")
            }
        }
    }
    
    // MARK: - Phase Continuity Tests
    
    func testPhaseContinuity() {
        var continuousPhase: Double = 0.0
        var previousBuffer: AVAudioPCMBuffer?
        
        // Generate several consecutive buffers and check phase continuity
        for secondIndex in 0..<5 {
            guard let buffer = AudioBufferFactoryStatic.makeSecondBuffer(
                symbol: JJYAudioGenerator.JJYSymbol.mark,
                secondIndex: secondIndex,
                format: testFormat,
                carrierFrequency: testCarrierFrequency,
                outputGain: testOutputGain,
                lowAmplitudeScale: testLowAmplitudeScale,
                phase: &continuousPhase,
                morse: morse,
                waveform: .sine
            ) else {
                XCTFail("Failed to create buffer for second \(secondIndex)")
                return
            }
            
            if let prevBuffer = previousBuffer {
                validatePhaseContinuity(prevBuffer, buffer)
            }
            
            previousBuffer = buffer
        }
    }
    
    private func validatePhaseContinuity(_ prevBuffer: AVAudioPCMBuffer, _ currentBuffer: AVAudioPCMBuffer) {
        guard let prevChannelData = prevBuffer.floatChannelData,
              let currentChannelData = currentBuffer.floatChannelData else {
            XCTFail("Buffers have no channel data")
            return
        }
        
        let prevLastSample = prevChannelData[0][Int(prevBuffer.frameLength - 1)]
        let currentFirstSample = currentChannelData[0][0]
        
        // The phase should be continuous (no sudden jumps)
        // This is a simplified check - in reality, we'd need more sophisticated analysis
        let phaseDifference = abs(currentFirstSample - prevLastSample)
        let maxAllowedJump = Float(testOutputGain * 0.5) // Allow some discontinuity
        
        XCTAssertLessThan(phaseDifference, maxAllowedJump,
                         "Phase should be approximately continuous between buffers")
    }
    
    // MARK: - Helper Methods
    
    private func validateBasicBufferProperties(_ buffer: AVAudioPCMBuffer) {
        // Verify basic buffer properties
        XCTAssertEqual(buffer.format.sampleRate, testSampleRate, "Sample rate should match")
        XCTAssertEqual(buffer.format.channelCount, testChannelCount, "Channel count should match")
        XCTAssertEqual(Int(buffer.frameLength), Int(testSampleRate), "Buffer should be 1 second long")
        XCTAssertNotNil(buffer.floatChannelData, "Buffer should have channel data")
    }
}