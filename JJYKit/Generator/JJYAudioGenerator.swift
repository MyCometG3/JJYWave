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
    
    // MARK: - Thread Safety
    private let concurrencyQueue = DispatchQueue(label: "com.MyCometG3.JJYWave.AudioGenerator", qos: .userInitiated)
    
    // MARK: - Properties
    private let audioEngineManager: AudioEngineProtocol
    private let frameService = FrameService()
    private let scheduler: TransmissionScheduler
    private var _isGenerating = false
    private let logger = Logger(subsystem: "com.MyCometG3.JJYWave", category: "JJY")
    
    weak var delegate: JJYAudioGeneratorDelegate?
    
    // MARK: - Bands
    enum CarrierBand { case jjy40, jjy60 }
    private var _band: CarrierBand = .jjy40
    
    // MARK: - Waveform
    enum Waveform { case sine, square }
    private var _waveform: Waveform = .sine
    
    // MARK: - Audio Configuration (Public Parameters)
    private var _sampleRate: Double = 96000
    private var _testFrequency: Double = 13333
    private var _actualFrequency: Double = 40000
    private var _carrierFrequency: Double = 13333
    private var _channelCount: AVAudioChannelCount = 2
    
    // 設定オブジェクト（将来の主API）。現行publicプロパティと双方向同期。
    private var _configuration: Configuration = Configuration(
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
    private var _isTestModeEnabled: Bool = true
    
    // MARK: - Options: Callsign / ST / Leap Second
    private var _enableCallsign: Bool = true
    private var _enableServiceStatusBits: Bool = true
    // 手動テスト用（計画が未設定のときのみ使用）
    private var _leapSecondPending: Bool = false
    private var _leapSecondInserted: Bool = true // true=+1秒挿入, false=−1秒削除
    private var _serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool) = (false,false,false,false,false,false)
    
    // 運用計画（自動スケジュール）: 指定のUTC月末で+1/−1秒
    enum LeapKind { case insert, delete }
    private var _leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: LeapKind)? = nil
    
    // MARK: - JJY Symbol & State
    enum JJYSymbol {
        case bit0, bit1, mark
        case morse
    }
    // JJY長波 40/60kHz の変調度: 通常フレームは10–100%（呼出符号部を除く）。
    // ここでは「振幅10%」を採用（以前は sqrt(0.1) で電力10%相当になっていたためJJY仕様に合わせ修正）。
    private let lowAmplitudeScale: Double = 0.1
    private let outputGain: Double = 0.3
    // State that was previously managed directly
    private var _phase: Double = 0.0

    // MARK: - Thread-Safe Public Properties
    
    var band: CarrierBand {
        return concurrencyQueue.sync { _band }
    }
    
    public var waveform: Waveform {
        get { concurrencyQueue.sync { _waveform } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._updateWaveform(newValue) 
            }
        }
    }
    
    public var sampleRate: Double {
        get { concurrencyQueue.sync { _sampleRate } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._updateSampleRate(newValue) 
            }
        }
    }
    
    public var testFrequency: Double {
        get { concurrencyQueue.sync { _testFrequency } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._updateTestFrequency(newValue) 
            }
        }
    }
    
    public var actualFrequency: Double {
        get { concurrencyQueue.sync { _actualFrequency } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._updateActualFrequency(newValue) 
            }
        }
    }
    
    public var channelCount: AVAudioChannelCount {
        get { concurrencyQueue.sync { _channelCount } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._updateChannelCount(newValue) 
            }
        }
    }
    
    var configuration: Configuration {
        return concurrencyQueue.sync { _configuration }
    }
    
    var isTestModeEnabled: Bool {
        get { concurrencyQueue.sync { _isTestModeEnabled } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._updateIsTestModeEnabled(newValue) 
            }
        }
    }
    
    public var enableCallsign: Bool {
        get { concurrencyQueue.sync { _enableCallsign } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._enableCallsign = newValue 
            }
        }
    }
    
    public var enableServiceStatusBits: Bool {
        get { concurrencyQueue.sync { _enableServiceStatusBits } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._enableServiceStatusBits = newValue 
            }
        }
    }
    
    public var leapSecondPending: Bool {
        get { concurrencyQueue.sync { _leapSecondPending } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._leapSecondPending = newValue 
            }
        }
    }
    
    public var leapSecondInserted: Bool {
        get { concurrencyQueue.sync { _leapSecondInserted } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._leapSecondInserted = newValue 
            }
        }
    }
    
    public var serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool) {
        get { concurrencyQueue.sync { _serviceStatusBits } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._serviceStatusBits = newValue 
            }
        }
    }
    
    public var leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: LeapKind)? {
        get { concurrencyQueue.sync { _leapSecondPlan } }
        set { 
            concurrencyQueue.sync { [weak self] in 
                self?._leapSecondPlan = newValue 
            }
        }
    }

    // MARK: - Initialization
    init(audioEngine: AudioEngineProtocol = AudioEngine()) {
        self.audioEngineManager = audioEngine
        // Initialize scheduler with frame service
        scheduler = TransmissionScheduler(frameService: frameService)
        scheduler.delegate = self
        
        concurrencyQueue.sync {
            setupAudioEngine()
            // 初期構成をpublicプロパティへ同期
            syncFromConfiguration()
            // 初期キャリア周波数を現行状態から再計算
            _carrierFrequency = _isTestModeEnabled ? _testFrequency : _actualFrequency
            // 初期波形をモードに合わせて強制
            _updateWaveform(_isTestModeEnabled ? .square : .sine)
        }
    }
    
    deinit {
        concurrencyQueue.async { [weak self] in
            self?.stopGeneration()
        }
    }
    
    // MARK: - Thread-Safe Property Update Methods
    
    private func _updateWaveform(_ newWaveform: Waveform) {
        _waveform = newWaveform
        _configuration.waveform = newWaveform
    }
    
    private func _updateSampleRate(_ newSampleRate: Double) {
        if _isGenerating {
            logger.error("Cannot change sampleRate while generating")
            return
        }
        _sampleRate = newSampleRate
        _configuration.sampleRate = newSampleRate
        // まずHW SRの引き上げを試行
        _ = audioEngineManager.trySetHardwareSampleRate(_sampleRate)
        setupAudioEngine()
        logger.info("Sample rate updated to: \(self._sampleRate, format: .fixed(precision: 0)) Hz")
    }
    
    private func _updateTestFrequency(_ newFrequency: Double) {
        _testFrequency = newFrequency
        _configuration.testFrequency = newFrequency
        if _isTestModeEnabled {
            _carrierFrequency = _testFrequency
        }
        logger.info("Test frequency updated to: \(self._testFrequency, format: .fixed(precision: 0)) Hz")
    }
    
    private func _updateActualFrequency(_ newFrequency: Double) {
        _actualFrequency = newFrequency
        _configuration.actualFrequency = newFrequency
        if !_isTestModeEnabled {
            _carrierFrequency = _actualFrequency
        }
        logger.info("Actual frequency updated to: \(self._actualFrequency, format: .fixed(precision: 0)) Hz")
    }
    
    private func _updateChannelCount(_ newChannelCount: AVAudioChannelCount) {
        if _isGenerating {
            logger.error("Cannot change channelCount while generating")
            return
        }
        _channelCount = newChannelCount
        _configuration.channelCount = UInt32(newChannelCount)
        setupAudioEngine()
    }
    
    private func _updateIsTestModeEnabled(_ newValue: Bool) {
        _isTestModeEnabled = newValue
        _carrierFrequency = _isTestModeEnabled ? _testFrequency : _actualFrequency
        // テストモード=矩形、JJYモード=正弦 に強制
        _updateWaveform(_isTestModeEnabled ? .square : .sine)
    }
    
    // MARK: - Public Methods
    func startGeneration() {
        concurrencyQueue.async { [weak self] in
            self?._startGeneration()
        }
    }
    
    func stopGeneration() {
        concurrencyQueue.async { [weak self] in
            self?._stopGeneration()
        }
    }
    
    var isActive: Bool {
        return concurrencyQueue.sync { _isGenerating }
    }
    
    // MARK: - Private Implementation Methods
    private func _startGeneration() {
        guard !_isGenerating else { return }
        
        do {
            try audioEngineManager.startEngine()
            audioEngineManager.startPlayer()
            _isGenerating = true
            
            // Ensure delegate callback is on main queue
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.audioGeneratorDidStart()
            }
            
            // Update scheduler configuration and start
            scheduler.updateConfiguration(
                enableCallsign: _enableCallsign,
                enableServiceStatusBits: _enableServiceStatusBits,
                leapSecondPlan: _leapSecondPlan,
                leapSecondPending: _leapSecondPending,
                leapSecondInserted: _leapSecondInserted,
                serviceStatusBits: _serviceStatusBits
            )
            scheduler.startScheduling()
            
        } catch {
            let message = "Failed to start audio engine: \(String(describing: error))"
            logger.error("\(message)")
            // Ensure delegate callback is on main queue
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.audioGeneratorDidEncounterError(message)
            }
        }
    }
    
    private func _stopGeneration() {
        guard _isGenerating else { return }
        
        audioEngineManager.stopEngine()
        scheduler.stopScheduling()
        
        // 状態リセット（次回開始時のクリーンスタート用）
        _phase = 0.0
        
        _isGenerating = false
        
        // Ensure delegate callback is on main queue
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.audioGeneratorDidStop()
        }
    }
    
    // MARK: - Band API
    /// 40kHz/60kHz を切替。停止中のみ。60kHz時は必要に応じてサンプルレートを 192kHz に自動変更。
    @discardableResult
    func updateBand(_ newBand: CarrierBand) -> Bool {
        return concurrencyQueue.sync {
            return _updateBand(newBand)
        }
    }
    
    private func _updateBand(_ newBand: CarrierBand) -> Bool {
        if _isGenerating {
            logger.error("Cannot change band while generating")
            return false
        }
        
        _band = newBand
        switch newBand {
        case .jjy40:
            _actualFrequency = 40000
            if _sampleRate < 80000 { _sampleRate = 96000 }
        case .jjy60:
            _actualFrequency = 60000
            if _sampleRate < 120000 { _sampleRate = 192000 }
        }
        _carrierFrequency = _isTestModeEnabled ? _testFrequency : _actualFrequency
        // まずHW SRの引き上げを試行
        _ = audioEngineManager.trySetHardwareSampleRate(_sampleRate)
        // エンジン再セットアップ
        setupAudioEngine()
        return true
    }
    
    /// 波形の更新（設定と本体の両方を同期）
    public func updateWaveform(_ newWaveform: Waveform) {
        concurrencyQueue.sync { [weak self] in
            self?._updateWaveform(newWaveform)
        }
    }
    
    // MARK: - Configuration API
    /// 新しい設定を適用する。
    /// - 制約: フォーマット影響項目（sampleRate, channelCount）は停止中のみ変更可。
    /// - 戻り値: 全項目が適用できた場合に true。適用不可項目があれば false を返し、それ以外は適用される。
    @discardableResult
    func applyConfiguration(_ newConfig: Configuration) -> Bool {
        return concurrencyQueue.sync {
            return _applyConfiguration(newConfig)
        }
    }
    
    private func _applyConfiguration(_ newConfig: Configuration) -> Bool {
        // フォーマット影響項目の検査
        let formatChanged = (newConfig.sampleRate != _sampleRate) || (AVAudioChannelCount(newConfig.channelCount) != _channelCount)
        if formatChanged && _isGenerating {
            logger.error("Cannot change sampleRate/channelCount while generating")
            return false
        }
        // 非フォーマット項目は即時反映
        _isTestModeEnabled = newConfig.isTestModeEnabled
        _testFrequency = newConfig.testFrequency
        _actualFrequency = newConfig.actualFrequency
        _enableCallsign = newConfig.enableCallsign
        _enableServiceStatusBits = newConfig.enableServiceStatusBits
        _leapSecondPending = newConfig.leapSecondPending
        _leapSecondInserted = newConfig.leapSecondInserted
        _serviceStatusBits = newConfig.serviceStatusBits
        _leapSecondPlan = newConfig.leapSecondPlan
        // モードに応じて波形を強制
        _updateWaveform(_isTestModeEnabled ? .square : .sine)
        // 搬送周波数の再計算
        _carrierFrequency = _isTestModeEnabled ? _testFrequency : _actualFrequency
        // フォーマット変更の適用（停止中のみ）
        if formatChanged && !_isGenerating {
            _sampleRate = newConfig.sampleRate
            _channelCount = AVAudioChannelCount(newConfig.channelCount)
            setupAudioEngine()
        }
        // 最後に保持（派生の waveform は上書き）
        _configuration = newConfig
        _configuration.waveform = _waveform
        return true
    }
    
    /// 現在のpublicプロパティからconfigurationへ同期（初期化時に使用）。
    private func syncFromConfiguration() {
        let current = Configuration(
            sampleRate: _sampleRate,
            channelCount: UInt32(_channelCount),
            isTestModeEnabled: _isTestModeEnabled,
            testFrequency: _testFrequency,
            actualFrequency: _actualFrequency,
            enableCallsign: _enableCallsign,
            enableServiceStatusBits: _enableServiceStatusBits,
            leapSecondPending: _leapSecondPending,
            leapSecondInserted: _leapSecondInserted,
            serviceStatusBits: _serviceStatusBits,
            leapSecondPlan: _leapSecondPlan,
            waveform: _waveform
        )
        _configuration = current
    }
    
    // MARK: - Public Configuration Methods（従来API: 互換のため残置）
    public func updateSampleRate(_ newSampleRate: Double) {
        concurrencyQueue.sync { [weak self] in
            self?._updateSampleRate(newSampleRate)
        }
    }
    
    public func updateTestFrequency(_ newFrequency: Double) {
        concurrencyQueue.sync { [weak self] in
            self?._updateTestFrequency(newFrequency)
        }
    }
    
    public func updateActualFrequency(_ newFrequency: Double) {
        concurrencyQueue.sync { [weak self] in
            self?._updateActualFrequency(newFrequency)
        }
    }
    
    public func getCurrentConfiguration() -> (sampleRate: Double, testFreq: Double, actualFreq: Double, isTestMode: Bool) {
        return concurrencyQueue.sync {
            return (sampleRate: _sampleRate,
                    testFreq: _testFrequency,
                    actualFreq: _actualFrequency,
                    isTestMode: _isTestModeEnabled)
        }
    }
    
    // MARK: - Private Methods - Audio Setup
    private func setupAudioEngine() {
        audioEngineManager.setupAudioEngine(sampleRate: _sampleRate, channelCount: _channelCount)
    }
    
    // MARK: - Buffer generation per second（ディスパッチャ）
    private func scheduleSecond(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime?) {
        concurrencyQueue.async { [weak self] in
            self?._scheduleSecond(symbol: symbol, secondIndex: secondIndex, when: when)
        }
    }
    
    private func _scheduleSecond(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime?) {
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
                                                               carrierFrequency: _carrierFrequency,
                                                               outputGain: outputGain,
                                                               lowAmplitudeScale: lowAmplitudeScale,
                                                               phase: &_phase,
                                                               morse: morse,
                                                               waveform: _waveform) else {
            logger.error("Failed to create PCM buffer")
            return
        }
        
        audioEngineManager.scheduleBuffer(buffer, at: when) {}
    }
}

// MARK: - TransmissionSchedulerDelegate
extension JJYAudioGenerator: TransmissionSchedulerDelegate {
    func schedulerDidRequestFrameRebuild(for baseTime: Date) {
        // Frame rebuild is handled by the scheduler itself
        // This delegate method is for future extensibility if needed
    }
    
    func schedulerDidRequestSecondScheduling(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime) {
        scheduleSecond(symbol: symbol, secondIndex: secondIndex, when: when)
    }
}
