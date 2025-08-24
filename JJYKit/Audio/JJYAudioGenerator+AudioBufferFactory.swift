import AVFoundation

// シンボル→PCMバッファ生成
struct AudioBufferFactory {
    // dit=9/97 は固定仕様（JJYの呼出符号）。
    private static let morseDit: Double = 9.0 / 97.0

    static func makeSecondBuffer(symbol: JJYSymbol,
                                 secondIndex: Int,
                                 format: AVAudioFormat,
                                 carrierFrequency: Double,
                                 outputGain: Double,
                                 lowAmplitudeScale: Double,
                                 phase: inout Double,
                                 morse: MorseCodeGenerator,
                                 waveform: JJYAudioGenerator.Waveform) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let channelCount = format.channelCount
        let totalSamples = AVAudioFrameCount(sampleRate.rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalSamples) else { return nil }
        buffer.frameLength = totalSamples
        let angularIncrement = 2.0 * Double.pi * carrierFrequency / sampleRate

        func sample(_ phase: Double, amp: Double) -> Float {
            switch waveform {
            case .sine:
                return Float(sin(phase) * amp)
            case .square:
                // 単純な対称矩形波（±1）。
                return Float((sin(phase) >= 0 ? 1.0 : -1.0) * amp)
            }
        }

        // 位相はサンプル毎に一度だけ進め、同一サンプル値を全チャンネルに複製する
        guard let channels = buffer.floatChannelData else { return nil }

        switch symbol {
        case .morse:
            let dit = morseDit
            let secondOffset = max(0, secondIndex - JJYIndex.callsignStart)
            for i in 0..<Int(totalSamples) {
                let t = (Double(i) / sampleRate) + Double(secondOffset)
                let on = morse.isOnAt(timeInWindow: t, dit: dit)
                let amp = (on ? 1.0 : 0.0) * outputGain
                let v = sample(phase, amp: amp)
                for ch in 0..<Int(channelCount) {
                    channels[ch][i] = v
                }
                phase += angularIncrement
                if phase > 2.0 * Double.pi { phase -= 2.0 * Double.pi }
            }
        default:
            // JJY仕様: 秒頭から高振幅区間（M:0.2, 1:0.5, 0:0.8）→残りは低振幅
            let highDuration: Double
            switch symbol {
            case .mark: highDuration = 0.2
            case .bit1: highDuration = 0.5
            case .bit0: highDuration = 0.8
            case .morse: highDuration = 0.0
            }
            let highSamples = Int((highDuration * sampleRate).rounded(.toNearestOrAwayFromZero))
            for i in 0..<Int(totalSamples) {
                let isHigh = i < highSamples
                let amp = (isHigh ? 1.0 : lowAmplitudeScale) * outputGain
                let v = sample(phase, amp: amp)
                for ch in 0..<Int(channelCount) {
                    channels[ch][i] = v
                }
                phase += angularIncrement
                if phase > 2.0 * Double.pi { phase -= 2.0 * Double.pi }
            }
        }
        return buffer
    }
}
