import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio
import OSLog

protocol JJYAudioGeneratorDelegate: AnyObject {
    func audioGeneratorDidStart()
    func audioGeneratorDidStop()
    func audioGeneratorDidEncounterError(_ error: String)
}

class JJYAudioGenerator {
    
    // MARK: - Properties
    private let audioEngineManager = AudioEngineManager()
    private let frameService = JJYFrameService()
    private let scheduler: JJYScheduler
    private var isGenerating = false
    private let logger = Logger(subsystem: "com.MyCometG3.JJYWave", category: "JJY")
    
    weak var delegate: JJYAudioGeneratorDelegate?
    
    // MARK: - Bands
    enum CarrierBand { case jjy40, jjy60 }
    private(set) var band: CarrierBand = .jjy40
    
    // MARK: - Waveform
    enum Waveform { case sine, square }
    public var waveform: Waveform = .sine
    
    // MARK: - Audio Configuration (Public Parameters)
    public var sampleRate: Double = 96000
    public var testFrequency: Double = 13333
    public var actualFrequency: Double = 40000
    private var carrierFrequency: Double = 13333
    public var channelCount: AVAudioChannelCount = 2
    
    // 設定オブジェクト（将来の主API）。現行publicプロパティと双方向同期。
    private(set) var configuration: JJYConfiguration = JJYConfiguration(
        sampleRate: 96000,
        channelCount: 2,
        isTestModeEnabled: true,
        testFrequency: 13333,
        actualFrequency: 40000,
        enableCallsign: true,
        enableServiceStatusBits: true,
        leapSecondPending: false,
        leapSecondInserted: true,
        serviceStatusBits: (false,false,false,false,false,false),
        leapSecondPlan: nil,
        waveform: .sine
    )
    
    // MARK: - Frequency Control
    var isTestModeEnabled: Bool = true {
        didSet {
            carrierFrequency = isTestModeEnabled ? testFrequency : actualFrequency
            // テストモード=矩形、JJYモード=正弦 に強制
            updateWaveform(isTestModeEnabled ? .square : .sine)
        }
    }
    
    // MARK: - Options: Callsign / ST / Leap Second
    public var enableCallsign: Bool = true
    public var enableServiceStatusBits: Bool = true
    // 手動テスト用（計画が未設定のときのみ使用）
    public var leapSecondPending: Bool = false
    public var leapSecondInserted: Bool = true // true=+1秒挿入, false=−1秒削除
    public var serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool) = (false,false,false,false,false,false)
    
    // 運用計画（自動スケジュール）: 指定のUTC月末で+1/−1秒
    enum LeapKind { case insert, delete }
    public var leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: LeapKind)? = nil
    
    // MARK: - JJY Symbol & State
    enum JJYSymbol {
        case bit0, bit1, mark
        case morse
    }
    private var currentFrame: [JJYSymbol] = []
    private var currentSecondIndex: Int = 0
    private var phase: Double = 0.0
    // JJY長波 40/60kHz の変調度: 通常フレームは10–100%（呼出符号部を除く）。
    // ここでは「振幅10%」を採用（以前は sqrt(0.1) で電力10%相当になっていたためJJY仕様に合わせ修正）。
    private let lowAmplitudeScale: Double = 0.1
    private let outputGain: Double = 0.3
    // State that was previously managed directly
    private var phase: Double = 0.0

    // MARK: - Initialization
    init() {
        // Initialize scheduler with frame service
        scheduler = JJYScheduler(frameService: frameService)
        scheduler.delegate = self
        
        setupAudioEngine()
        // 初期構成をpublicプロパティへ同期
        syncFromConfiguration()
        // 初期キャリア周波数を現行状態から再計算
        carrierFrequency = isTestModeEnabled ? testFrequency : actualFrequency
        // 初期波形をモードに合わせて強制
        updateWaveform(isTestModeEnabled ? .square : .sine)
    }
    
    deinit {
        stopGeneration()
    }
    
    // MARK: - Public Methods
    func startGeneration() {
        guard !isGenerating else { return }
        
        do {
            try audioEngineManager.startEngine()
            audioEngineManager.startPlayer()
            isGenerating = true
            
            delegate?.audioGeneratorDidStart()
            
            // Update scheduler configuration and start
            scheduler.updateConfiguration(
                enableCallsign: enableCallsign,
                enableServiceStatusBits: enableServiceStatusBits,
                leapSecondPlan: leapSecondPlan,
                leapSecondPending: leapSecondPending,
                leapSecondInserted: leapSecondInserted,
                serviceStatusBits: serviceStatusBits
            )
            scheduler.startScheduling()
            
        } catch {
            let message = "Failed to start audio engine: \(String(describing: error))"
            logger.error("\(message)")
            delegate?.audioGeneratorDidEncounterError(message)
        }
    }
    
    func stopGeneration() {
        guard isGenerating else { return }
        
        audioEngineManager.stopEngine()
        scheduler.stopScheduling()
        
        // 状態リセット（次回開始時のクリーンスタート用）
        phase = 0.0
        
        isGenerating = false
        
        delegate?.audioGeneratorDidStop()
    }
    
    var isActive: Bool {
        return isGenerating
    }
    
    // MARK: - Band API
    /// 40kHz/60kHz を切替。停止中のみ。60kHz時は必要に応じてサンプルレートを 192kHz に自動変更。
    @discardableResult
    func updateBand(_ newBand: CarrierBand) -> Bool {
        if isGenerating {
            logger.error("Cannot change band while generating")
            return false
        }
        
        band = newBand
        switch newBand {
        case .jjy40:
            actualFrequency = 40000
            if sampleRate < 80000 { sampleRate = 96000 }
        case .jjy60:
            actualFrequency = 60000
            if sampleRate < 120000 { sampleRate = 192000 }
        }
        carrierFrequency = isTestModeEnabled ? testFrequency : actualFrequency
        // まずHW SRの引き上げを試行
        _ = audioEngineManager.trySetHardwareSampleRate(sampleRate)
        // エンジン再セットアップ
        setupAudioEngine()
        return true
    }
    
    /// 波形の更新（設定と本体の両方を同期）
    public func updateWaveform(_ newWaveform: Waveform) {
        self.waveform = newWaveform
        self.configuration.waveform = newWaveform
    }
    
    // MARK: - Configuration API
    /// 新しい設定を適用する。
    /// - 制約: フォーマット影響項目（sampleRate, channelCount）は停止中のみ変更可。
    /// - 戻り値: 全項目が適用できた場合に true。適用不可項目があれば false を返し、それ以外は適用される。
    @discardableResult
    func applyConfiguration(_ newConfig: JJYConfiguration) -> Bool {
        // フォーマット影響項目の検査
        let formatChanged = (newConfig.sampleRate != sampleRate) || (AVAudioChannelCount(newConfig.channelCount) != channelCount)
        if formatChanged && isGenerating {
            logger.error("Cannot change sampleRate/channelCount while generating")
            return false
        }
        // 非フォーマット項目は即時反映
        isTestModeEnabled = newConfig.isTestModeEnabled
        testFrequency = newConfig.testFrequency
        actualFrequency = newConfig.actualFrequency
        enableCallsign = newConfig.enableCallsign
        enableServiceStatusBits = newConfig.enableServiceStatusBits
        leapSecondPending = newConfig.leapSecondPending
        leapSecondInserted = newConfig.leapSecondInserted
        serviceStatusBits = newConfig.serviceStatusBits
        leapSecondPlan = newConfig.leapSecondPlan
        // モードに応じて波形を強制
        updateWaveform(isTestModeEnabled ? .square : .sine)
        // 搬送周波数の再計算
        carrierFrequency = isTestModeEnabled ? testFrequency : actualFrequency
        // フォーマット変更の適用（停止中のみ）
        if formatChanged && !isGenerating {
            sampleRate = newConfig.sampleRate
            channelCount = AVAudioChannelCount(newConfig.channelCount)
            setupAudioEngine()
        }
        // 最後に保持（派生の waveform は上書き）
        configuration = newConfig
        configuration.waveform = waveform
        return true
    }
    
    /// 現在のpublicプロパティからconfigurationへ同期（初期化時に使用）。
    private func syncFromConfiguration() {
        let current = JJYConfiguration(
            sampleRate: sampleRate,
            channelCount: UInt32(channelCount),
            isTestModeEnabled: isTestModeEnabled,
            testFrequency: testFrequency,
            actualFrequency: actualFrequency,
            enableCallsign: enableCallsign,
            enableServiceStatusBits: enableServiceStatusBits,
            leapSecondPending: leapSecondPending,
            leapSecondInserted: leapSecondInserted,
            serviceStatusBits: serviceStatusBits,
            leapSecondPlan: leapSecondPlan,
            waveform: waveform
        )
        configuration = current
    }
    
    // MARK: - Public Configuration Methods（従来API: 互換のため残置）
    public func updateSampleRate(_ newSampleRate: Double) {
        if isGenerating {
            logger.error("Cannot change sampleRate while generating")
            return
        }
        sampleRate = newSampleRate
        configuration.sampleRate = newSampleRate
        // まずHW SRの引き上げを試行
        _ = audioEngineManager.trySetHardwareSampleRate(sampleRate)
        setupAudioEngine()
        logger.info("Sample rate updated to: \(self.sampleRate, format: .fixed(precision: 0)) Hz")
    }
    
    public func updateTestFrequency(_ newFrequency: Double) {
        testFrequency = newFrequency
        configuration.testFrequency = newFrequency
        if isTestModeEnabled {
            carrierFrequency = testFrequency
        }
        // 明示的に self を付与（Logger の補間はクロージャ評価）
        logger.info("Test frequency updated to: \(self.testFrequency, format: .fixed(precision: 0)) Hz")
    }
    
    public func updateActualFrequency(_ newFrequency: Double) {
        actualFrequency = newFrequency
        configuration.actualFrequency = newFrequency
        if !isTestModeEnabled {
            carrierFrequency = actualFrequency
        }
        // 明示的に self を付与（Logger の補間はクロージャ評価）
        logger.info("Actual frequency updated to: \(self.actualFrequency, format: .fixed(precision: 0)) Hz")
    }
    
    public func getCurrentConfiguration() -> (sampleRate: Double, testFreq: Double, actualFreq: Double, isTestMode: Bool) {
        return (sampleRate: sampleRate,
                testFreq: testFrequency,
                actualFreq: actualFrequency,
                isTestMode: isTestModeEnabled)
    }
    
    // MARK: - Private Methods - Audio Setup
    private func setupAudioEngine() {
        audioEngineManager.setupAudioEngine(sampleRate: sampleRate, channelCount: channelCount)
    }
    
    // MARK: - Buffer generation per second（ディスパッチャ）
    private func scheduleSecond(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime?) {
        // プレーヤーノードの出力フォーマット（接続時に指定した希望SR）を使用
        guard let playerFormat = audioEngineManager.getPlayerFormat() else {
            logger.error("Player format not available")
            return
        }
        let targetSampleRate = playerFormat.sampleRate
        let targetChannels = playerFormat.channelCount
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: targetSampleRate, channels: targetChannels) else {
            logger.error("Failed to create buffer format")
            return
        }
        
        // バッファ生成をファクトリに委譲
        let morse = MorseCodeGenerator()
        guard let buffer = AudioBufferFactory.makeSecondBuffer(symbol: symbol,
                                                               secondIndex: secondIndex,
                                                               format: format,
                                                               carrierFrequency: carrierFrequency,
                                                               outputGain: outputGain,
                                                               lowAmplitudeScale: lowAmplitudeScale,
                                                               phase: &phase,
                                                               morse: morse,
                                                               waveform: waveform) else {
            logger.error("Failed to create PCM buffer")
            return
        }
        
        audioEngineManager.scheduleBuffer(buffer, at: when)
    }
}

// MARK: - JJYSchedulerDelegate
extension JJYAudioGenerator: JJYSchedulerDelegate {
    func schedulerDidRequestFrameRebuild(for baseTime: Date) {
        // Frame rebuild is handled by the scheduler itself
        // This delegate method is for future extensibility if needed
    }
    
    func schedulerDidRequestSecondScheduling(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime) {
        scheduleSecond(symbol: symbol, secondIndex: secondIndex, when: when)
    }
}
