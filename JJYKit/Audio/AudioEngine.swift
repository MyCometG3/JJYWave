import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio
import OSLog

// MARK: - AudioEngine
/// Manages AVAudioEngine, AVAudioPlayerNode, and hardware sample rate logic
class AudioEngine {
    private let concurrencyQueue = DispatchQueue(label: "com.MyCometG3.JJYWave.AudioEngine", qos: .userInitiated)
    private var audioEngine: AVAudioEngine!
    private var playerNode: AVAudioPlayerNode!
    private let logger = Logger(subsystem: "com.MyCometG3.JJYWave", category: "AudioEngine")
    
    // MARK: - Properties
    var isEngineRunning: Bool {
        return concurrencyQueue.sync {
            return audioEngine?.isRunning ?? false
        }
    }
    
    var isPlayerPlaying: Bool {
        return concurrencyQueue.sync {
            return playerNode?.isPlaying ?? false
        }
    }
    
    // MARK: - Initialization
    init() {
        // setupAudioEngine will be called when needed
    }
    
    // MARK: - Public Methods
    func setupAudioEngine(sampleRate: Double, channelCount: AVAudioChannelCount) {
        concurrencyQueue.sync {
            _setupAudioEngine(sampleRate: sampleRate, channelCount: channelCount)
        }
    }
    
    private func _setupAudioEngine(sampleRate: Double, channelCount: AVAudioChannelCount) {
        // 可能ならハードウェアSRを希望SRへ（停止中のみ呼ばれる設計）
        _ = trySetHardwareSampleRate(sampleRate)
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount) else {
            logger.error("Failed to create audio format")
            return
        }
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        logger.info("Audio engine setup with sample rate: \(sampleRate, format: .fixed(precision: 0)) Hz, channels: \(channelCount)")
    }
    
    @discardableResult
    func startEngine() -> Bool {
        do {
            return try concurrencyQueue.sync {
                guard let audioEngine = audioEngine else {
                    return false
                }
                
                try audioEngine.start()
                
                logger.info("Audio engine started successfully")
                // ログ: プレーヤー接続SR（希望のSR）とハードウェアSRを両方表示
                let playerSR = self.playerNode.outputFormat(forBus: 0).sampleRate
                let hwSR = self.audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
                logger.info("Player sample rate (desired): \(playerSR, format: .fixed(precision: 0))")
                logger.info("Hardware sample rate: \(hwSR, format: .fixed(precision: 0))")
                logger.info("Channel count: \(self.audioEngine.outputNode.outputFormat(forBus: 0).channelCount)")
                return true
            }
        } catch {
            logger.error("Failed to start audio engine: \(error)")
            return false
        }
    }
    
    func stopEngine() {
        concurrencyQueue.async { [weak self] in
            self?.audioEngine?.stop()
            self?.playerNode?.stop()
        }
    }
    
    func startPlayer() {
        concurrencyQueue.async { [weak self] in
            if !(self?.playerNode?.isPlaying ?? false) {
                self?.playerNode?.play()
            }
        }
    }
    
    func stopPlayer() {
        concurrencyQueue.async { [weak self] in
            self?.playerNode?.stop()
        }
    }
    
    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, completionHandler: AVAudioNodeCompletionHandler? = nil) {
        concurrencyQueue.async { [weak self] in
            if let when = when {
                self?.playerNode?.scheduleBuffer(buffer, at: when, options: [], completionHandler: completionHandler)
            } else {
                self?.playerNode?.scheduleBuffer(buffer, completionHandler: completionHandler)
            }
        }
    }
    
    func getPlayerFormat() -> AVAudioFormat? {
        return concurrencyQueue.sync {
            return playerNode?.outputFormat(forBus: 0)
        }
    }
    
    func getOutputChannelCount() -> AVAudioChannelCount {
        return concurrencyQueue.sync {
            return audioEngine?.outputNode.outputFormat(forBus: 0).channelCount ?? 0
        }
    }
    
    // MARK: - Hardware Sample Rate Management
    func getHardwareSampleRate() -> Double {
        var defaultOutputID = AudioDeviceID(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &defaultOutputID)
        if status != noErr || defaultOutputID == 0 { return 0.0 }
        
        // 現在のSRを取得
        var currentSR = 0.0
        dataSize = UInt32(MemoryLayout<Double>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyData(defaultOutputID, &addr, 0, nil, &dataSize, &currentSR)
        if status != noErr { return 0.0 }
        
        return currentSR
    }
    
    @discardableResult
    func trySetHardwareSampleRate(_ desired: Double) -> Bool {
        var defaultOutputID = AudioDeviceID(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &defaultOutputID)
        if status != noErr || defaultOutputID == 0 { return false }
        // 現在のSRを取得
        var currentSR = 0.0
        dataSize = UInt32(MemoryLayout<Double>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyData(defaultOutputID, &addr, 0, nil, &dataSize, &currentSR)
        if status != noErr { return false }
        if abs(currentSR - desired) < 1.0 { return true } // ほぼ一致
        // サポート範囲を確認
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyDataSize(defaultOutputID, &addr, 0, nil, &dataSize)
        if status != noErr { return false }
        let count = Int(dataSize) / MemoryLayout<AudioValueRange>.size
        var ranges = Array(repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: count)
        status = AudioObjectGetPropertyData(defaultOutputID, &addr, 0, nil, &dataSize, &ranges)
        if status != noErr { return false }
        // 希望値が利用可能か（範囲内判定）
        var supported = false
        for r in ranges {
            if desired >= r.mMinimum - 1 && desired <= r.mMaximum + 1 { supported = true; break }
        }
        if !supported { return false }
        // 設定を試行（エンジン停止中推奨）
        var newSR = desired
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectSetPropertyData(defaultOutputID, &addr, 0, nil, UInt32(MemoryLayout.size(ofValue: newSR)), &newSR)
        if status == noErr {
            self.logger.info("Hardware sample rate set to: \(newSR, format: .fixed(precision: 0)))")
            return true
        } else {
            return false
        }
    }
}

// MARK: - AudioEngineError
enum AudioEngineError: Error {
    case engineNotSetup
    case startFailed(String)
}