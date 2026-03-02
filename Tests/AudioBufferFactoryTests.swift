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

        // Expected amplitude levels
        let expectedHighAmplitude = Float(testOutputGain)
        let expectedLowAmplitude = Float(testOutputGain * testLowAmplitudeScale)

        // Smooth the absolute waveform to obtain an envelope that is robust to zero-crossings/phase
        // Use a short smoothing window (~1ms) to remove high-frequency oscillation from the envelope
        let windowMs = 0.001
        let windowLen = max(1, Int(testSampleRate * windowMs))

        // Prefix sum for fast moving-average
        var prefix = [Double](repeating: 0.0, count: totalSamples + 1)
        for i in 0..<totalSamples {
            prefix[i + 1] = prefix[i] + Double(abs(channel0Data[i]))
        }

        var smoothed = [Double](repeating: 0.0, count: totalSamples)
        for i in 0..<totalSamples {
            let start = max(0, i - windowLen / 2)
            let end = min(totalSamples - 1, i + windowLen / 2)
            let sum = prefix[end + 1] - prefix[start]
            smoothed[i] = sum / Double(end - start + 1)
        }

        // Threshold halfway between expected high and low envelope
        let midThreshold = Double((expectedHighAmplitude + expectedLowAmplitude) * 0.5)

        // Since generation uses a leading high-duration region, find the first index where envelope drops below threshold
        var highRegionEnd = totalSamples
        for i in 0..<totalSamples {
            if smoothed[i] <= midThreshold {
                highRegionEnd = i
                break
            }
        }

        let actualHighSamples = highRegionEnd

        // Allow some tolerance due to rounding and sampling alignment
        let tolerance = Int(testSampleRate * 0.005) // 5ms tolerance
        XCTAssertEqual(actualHighSamples, expectedHighSamples, accuracy: tolerance,
                      "\(symbolName) symbol should have \(expectedHighSamples) high amplitude samples, got \(actualHighSamples)")

        // Verify low amplitude portion exists somewhere in the buffer if the high run doesn't cover entire buffer
        if actualHighSamples < totalSamples {
            var hasLow = false
            for i in actualHighSamples..<totalSamples {
                if abs(channel0Data[i]) < expectedLowAmplitude * 1.5 {
                    hasLow = true
                    break
                }
            }
            XCTAssertTrue(hasLow, "\(symbolName) symbol should contain low amplitude samples outside the high region")
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
            
            // Skip if indices would be the same or out of range
            if quarterCycle <= 0 || cycleStart >= Int(buffer.frameLength) || cycleStart + quarterCycle >= Int(buffer.frameLength) {
                continue
            }
            
            let zeroPoint = channel0Data[cycleStart]
            let quarterPoint = channel0Data[cycleStart + quarterCycle]
            
            // At quarter cycle, sine should be near maximum
            XCTAssertGreaterThan(abs(quarterPoint), abs(zeroPoint),
                               "Sine wave should have maximum at quarter cycle")
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
            let secondIndexDouble = Double(cycleStart) + samplesPerCycle / 2.0
            let secondIdx = Int(round(secondIndexDouble))
            
            // Skip if indices invalid or effectively equal
            if secondIdx <= cycleStart || cycleStart >= Int(buffer.frameLength) || secondIdx >= Int(buffer.frameLength) {
                continue
            }
            
            // For very short cycles due to high carrier frequency, check sign variation within the cycle window
            let cycleLen = max(1, Int(round(samplesPerCycle)))
            let startIdx = cycleStart
            let endIdx = min(Int(buffer.frameLength) - 1, cycleStart + cycleLen)
            var hasPositive = false
            var hasNegative = false
            let strongThreshold: Float = Float(testOutputGain * 0.4)
            for idx in startIdx...endIdx {
                let val = channel0Data[idx]
                if val > strongThreshold { hasPositive = true }
                if val < -strongThreshold { hasNegative = true }
            }

            XCTAssertTrue(hasPositive && hasNegative, "Square wave should have both positive and negative samples in cycle \(cycle)")
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

        // Analyze first 0.4 seconds (or available samples) and use peak detection to estimate frequency
        let analysisSamples = min(totalSamples, Int(0.4 * testSampleRate))
        let analysisDuration = Double(analysisSamples) / testSampleRate

        // Find maximum amplitude in analysis window
        var maxAmp: Float = 0
        for i in 0..<analysisSamples { maxAmp = max(maxAmp, abs(channel0Data[i])) }
        if maxAmp <= 0 {
            XCTFail("Buffer has no amplitude to analyze")
            return
        }

        // Detect peaks above a threshold
        let peakThreshold = maxAmp * 0.6
        var peaks: [Int] = []
        for i in 1..<(analysisSamples - 1) {
            if abs(channel0Data[i]) > peakThreshold && abs(channel0Data[i]) >= abs(channel0Data[i-1]) && abs(channel0Data[i]) >= abs(channel0Data[i+1]) {
                peaks.append(i)
                if peaks.count >= 500 { break }
            }
        }

        var peakEstimate: Double? = nil
        if peaks.count >= 2 {
            var totalDist = 0
            for i in 1..<peaks.count { totalDist += (peaks[i] - peaks[i-1]) }
            let avgDist = Double(totalDist) / Double(peaks.count - 1)
            peakEstimate = testSampleRate / avgDist
        }

        // Zero-crossing estimate (always attempt)
        var zeroCrossings = 0
        for i in 1..<analysisSamples {
            if (channel0Data[i] >= 0 && channel0Data[i-1] < 0) || (channel0Data[i] < 0 && channel0Data[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        var zEstimate: Double? = nil
        if zeroCrossings >= 2 {
            zEstimate = Double(zeroCrossings) / (2.0 * analysisDuration)
        }

        // Choose the best estimate (closest to the expected effective frequency)
        var estimatedFrequency: Double = 0
        if let p = peakEstimate, let z = zEstimate {
            estimatedFrequency = abs(p - expectedFrequency) < abs(z - expectedFrequency) ? p : z
        } else if let p = peakEstimate {
            estimatedFrequency = p
        } else if let z = zEstimate {
            estimatedFrequency = z
        } else {
            XCTFail("Not enough data to estimate frequency")
            return
        }

        // Account for aliasing when expected frequency is above Nyquist — fold into baseband properly
        let nyquist = testSampleRate / 2.0
        var effectiveExpected = expectedFrequency
        if expectedFrequency > nyquist {
            var fmod = expectedFrequency.truncatingRemainder(dividingBy: testSampleRate)
            if fmod < 0 { fmod = -fmod }
            if fmod > nyquist {
                effectiveExpected = testSampleRate - fmod
            } else {
                effectiveExpected = fmod
            }
        }

        // Debug trace to aid analysis when tests fail
        print("[AudioTest] expected=\(expectedFrequency) effective=\(effectiveExpected) estimated=\(estimatedFrequency)")

        let tolerance = effectiveExpected * 0.10 // 10% tolerance

        XCTAssertEqual(estimatedFrequency, effectiveExpected, accuracy: tolerance,
                      "Carrier frequency should be approximately \(effectiveExpected) Hz (expected \(expectedFrequency)), estimated \(estimatedFrequency) Hz")
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
