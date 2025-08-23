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
    private var audioEngine: AVAudioEngine!
    private var playerNode: AVAudioPlayerNode!
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
    private var nextHostTime: UInt64 = 0
    private var hostClockFrequency: Double = 0
    private var ticksPerSecond: UInt64 = 0
    // タイミングと状態の直列化用キュー／DispatchTimer
    private let syncQueue = DispatchQueue(label: "JJYAudioGenerator.sync")
    private var dispatchTimer: DispatchSourceTimer?

    // MARK: - Initialization
    init() {
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
            try audioEngine.start()
            isGenerating = true
            
            logger.info("Audio engine started successfully")
            // ログ: プレイヤー接続SR（希望のSR）とハードウェアSRを両方表示
            let playerSR = self.playerNode.outputFormat(forBus: 0).sampleRate
            let hwSR = self.audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
            logger.info("Player sample rate (desired): \(playerSR, format: .fixed(precision: 0))")
            logger.info("Hardware sample rate: \(hwSR, format: .fixed(precision: 0))")
            logger.info("Channel count: \(self.audioEngine.outputNode.outputFormat(forBus: 0).channelCount)")
            
            delegate?.audioGeneratorDidStart()
            
            startJJYLoop()
            
        } catch {
            let message = "Failed to start audio engine: \(String(describing: error))"
            logger.error("\(message)")
            delegate?.audioGeneratorDidEncounterError(message)
        }
    }
    
    func stopGeneration() {
        guard isGenerating else { return }
        
        audioEngine.stop()
        playerNode.stop()
        // DispatchSourceTimer を停止
        syncQueue.sync {
            dispatchTimer?.cancel()
            dispatchTimer = nil
        }
        // 状態リセット（次回開始時のクリーンスタート用）
        phase = 0.0
        currentSecondIndex = 0
        currentFrame.removeAll(keepingCapacity: false)
        nextHostTime = 0
        hostClockFrequency = 0
        ticksPerSecond = 0
        
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
        var ok = true
        syncQueue.sync {
            if self.isGenerating {
                self.logger.error("Cannot change band while generating")
                ok = false
                return
            }
            self.band = newBand
            switch newBand {
            case .jjy40:
                self.actualFrequency = 40000
                if self.sampleRate < 80000 { self.sampleRate = 96000 }
            case .jjy60:
                self.actualFrequency = 60000
                if self.sampleRate < 120000 { self.sampleRate = 192000 }
            }
            self.carrierFrequency = self.isTestModeEnabled ? self.testFrequency : self.actualFrequency
            // まずHW SRの引き上げを試行
            _ = self.trySetHardwareSampleRate(self.sampleRate)
            // エンジン再セットアップ
            self.setupAudioEngine()
        }
        return ok
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
        var ok = true
        syncQueue.sync {
            // フォーマット影響項目の検査
            let formatChanged = (newConfig.sampleRate != self.sampleRate) || (AVAudioChannelCount(newConfig.channelCount) != self.channelCount)
            if formatChanged && self.isGenerating {
                self.logger.error("Cannot change sampleRate/channelCount while generating")
                ok = false
            }
            // 非フォーマット項目は即時反映
            self.isTestModeEnabled = newConfig.isTestModeEnabled
            self.testFrequency = newConfig.testFrequency
            self.actualFrequency = newConfig.actualFrequency
            self.enableCallsign = newConfig.enableCallsign
            self.enableServiceStatusBits = newConfig.enableServiceStatusBits
            self.leapSecondPending = newConfig.leapSecondPending
            self.leapSecondInserted = newConfig.leapSecondInserted
            self.serviceStatusBits = newConfig.serviceStatusBits
            self.leapSecondPlan = newConfig.leapSecondPlan
            // モードに応じて波形を強制
            self.updateWaveform(self.isTestModeEnabled ? .square : .sine)
            // 搬送周波数の再計算
            self.carrierFrequency = self.isTestModeEnabled ? self.testFrequency : self.actualFrequency
            // フォーマット変更の適用（停止中のみ）
            if formatChanged && !self.isGenerating {
                self.sampleRate = newConfig.sampleRate
                self.channelCount = AVAudioChannelCount(newConfig.channelCount)
                self.setupAudioEngine()
            }
            // 最後に保持（派生の waveform は上書き）
            self.configuration = newConfig
            self.configuration.waveform = self.waveform
        }
        return ok
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
        _ = trySetHardwareSampleRate(sampleRate)
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
        
        logger.info("Audio engine setup with sample rate: \(self.sampleRate, format: .fixed(precision: 0)) Hz, channels: \(self.channelCount)")
    }
    
    // MARK: - JJY main loop (hostTime同期)
    private func startJJYLoop() {
        let cal = jstCalendar()
        let now = Date()
        let currentSecond = cal.component(.second, from: now)
        // フレームは「現在の分」の先頭マーカー時刻を基準に構築する
        let baseTime = currentMinuteStart(from: now, calendar: cal)
        // フレーム構築をビルダーに委譲
        let frameOptions = JJYFrameBuilder.Options(enableCallsign: enableCallsign,
                                                   enableServiceStatusBits: enableServiceStatusBits,
                                                   leapSecondPlan: leapSecondPlan,
                                                   leapSecondPending: leapSecondPending,
                                                   leapSecondInserted: leapSecondInserted,
                                                   serviceStatusBits: serviceStatusBits)
        currentFrame = JJYFrameBuilder().build(for: baseTime, calendar: cal, options: frameOptions)
        // デバッグ: 構築したフレームの要約を出力
        logFrame(currentFrame, baseTime: baseTime, calendar: cal)
        // 初回は次の整数秒境界で (現在秒+1) のシンボルを送る
        currentSecondIndex = (currentSecond + 1) % currentFrame.count
        
        if !playerNode.isPlaying { playerNode.play() }
        
        // ホスト時刻で次の整数秒境界に合わせる
        let nowEpoch = Date().timeIntervalSince1970
        let frac = nowEpoch - floor(nowEpoch)
        let delta = 1.0 - frac
        let hostNow = AudioGetCurrentHostTime()
        hostClockFrequency = AudioGetHostClockFrequency()
        ticksPerSecond = UInt64(hostClockFrequency)
        nextHostTime = hostNow &+ UInt64(delta * hostClockFrequency)
        let firstWhen = AVAudioTime(hostTime: nextHostTime)
        
        scheduleSecond(symbol: currentFrame[currentSecondIndex], secondIndex: currentSecondIndex, when: firstWhen)
        advanceSecondIndex()
        nextHostTime &+= ticksPerSecond
        
        // 以降は DispatchSourceTimer で 1秒毎にホスト時刻でスケジュール
        // 既存タイマーの競合回避のため queue を専用化
        let timer = DispatchSource.makeTimerSource(queue: syncQueue)
        dispatchTimer = timer
        let leeway: DispatchTimeInterval = .milliseconds(5)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1), leeway: leeway)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let hostNowInner = AudioGetCurrentHostTime()
            // 遅延や進み過ぎを検知して再同期（しきい値: 200ms）
            let toleranceTicks = UInt64(0.2 * self.hostClockFrequency)
            let minLeadTicks = UInt64(0.02 * self.hostClockFrequency)
            var didRebuildInResync = false
            if hostNowInner > (self.nextHostTime &+ toleranceTicks) || self.nextHostTime <= (hostNowInner &+ minLeadTicks) {
                // 現在時刻から次の整数秒境界へ再同期
                let nowEpoch2 = Date().timeIntervalSince1970
                let frac2 = nowEpoch2 - floor(nowEpoch2)
                let delta2 = 1.0 - frac2
                self.nextHostTime = hostNowInner &+ UInt64(delta2 * self.hostClockFrequency)
                // 現在秒+1のシンボルに合わせ直す
                let secNow = cal.component(.second, from: Date())
                self.currentSecondIndex = (secNow + 1) % self.currentFrame.count
                // 分境界ならフレーム再構築（次分の先頭マーカー時刻で構築）
                if self.currentSecondIndex == 0 {
                    let baseTime2 = self.nextMinuteStart(from: Date(), calendar: cal)
                    let frameOptions2 = JJYFrameBuilder.Options(enableCallsign: self.enableCallsign,
                                                                enableServiceStatusBits: self.enableServiceStatusBits,
                                                                leapSecondPlan: self.leapSecondPlan,
                                                                leapSecondPending: self.leapSecondPending,
                                                                leapSecondInserted: self.leapSecondInserted,
                                                                serviceStatusBits: self.serviceStatusBits)
                    self.currentFrame = JJYFrameBuilder().build(for: baseTime2, calendar: cal, options: frameOptions2)
                    self.logFrame(self.currentFrame, baseTime: baseTime2, calendar: cal)
                    didRebuildInResync = true
                }
            }
            // 分境界（currentSecondIndex==0）では毎回新しいフレームに切り替える（上で再構築していなければ）
            if self.currentSecondIndex == 0 && !didRebuildInResync {
                let baseTime3 = self.nextMinuteStart(from: Date(), calendar: cal)
                let frameOptions3 = JJYFrameBuilder.Options(enableCallsign: self.enableCallsign,
                                                            enableServiceStatusBits: self.enableServiceStatusBits,
                                                            leapSecondPlan: self.leapSecondPlan,
                                                            leapSecondPending: self.leapSecondPending,
                                                            leapSecondInserted: self.leapSecondInserted,
                                                            serviceStatusBits: self.serviceStatusBits)
                self.currentFrame = JJYFrameBuilder().build(for: baseTime3, calendar: cal, options: frameOptions3)
                self.logFrame(self.currentFrame, baseTime: baseTime3, calendar: cal)
            }
            let when = AVAudioTime(hostTime: self.nextHostTime)
            self.scheduleSecond(symbol: self.currentFrame[self.currentSecondIndex], secondIndex: self.currentSecondIndex, when: when)
            self.advanceSecondIndex()
            self.nextHostTime &+= self.ticksPerSecond
        }
        timer.resume()
    }
    
    private func advanceSecondIndex() {
        currentSecondIndex += 1
        if currentSecondIndex >= currentFrame.count { currentSecondIndex = 0 }
    }
    
    // MARK: - Buffer generation per second（ディスパッチャ）
    private func scheduleSecond(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime?) {
        // プレーヤーノードの出力フォーマット（接続時に指定した希望SR）を使用
        let playerFormat = playerNode.outputFormat(forBus: 0)
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
        
        if let when = when {
            playerNode.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)
        } else {
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
        }
    }
    
    // MARK: - Time helpers (JST)
    private func jstCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return cal
    }
    
    private func nextMinuteStart(from date: Date, calendar: Calendar) -> Date {
        let sec = calendar.component(.second, from: date)
        let floor = calendar.date(byAdding: .second, value: -sec, to: date) ?? date
        return calendar.date(byAdding: .minute, value: 1, to: floor) ?? date
    }
    
    // 現在の分の開始（分床）を返す
    private func currentMinuteStart(from date: Date, calendar: Calendar) -> Date {
        let sec = calendar.component(.second, from: date)
        return calendar.date(byAdding: .second, value: -sec, to: date) ?? date
    }
    
    // デバッグ: フレーム内容を要約して出力
    private func logFrame(_ frame: [JJYSymbol], baseTime: Date, calendar: Calendar) {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let ts = df.string(from: baseTime)
        // 先頭10秒のパターン（:00〜:09）
        let maxIdx = min(9, frame.count - 1)
        var pattern = ""
        if maxIdx >= 0 {
            for i in 0...maxIdx { pattern.append(symbolChar(frame[i])) }
        }
        // 分の値とBCDビット
        let minute = calendar.component(.minute, from: baseTime)
        let minT = minute / 10
        let minO = minute % 10
        let tenBits = [1,2,3].map { bitValue(in: frame, at: $0) }.map(String.init).joined()
        let oneBits = [5,6,7,8].map { bitValue(in: frame, at: $0) }.map(String.init).joined()
        // パリティ（仕様: 偶数）
        let paHour = bitValue(in: frame, at: 36)
        let paMin  = bitValue(in: frame, at: 37)
        let calcPaHour = ([12,13,15,16,17,18].reduce(0) { $0 + bitValue(in: frame, at: $1) }) % 2
        let calcPaMin  = ([1,2,3,5,6,7,8].reduce(0) { $0 + bitValue(in: frame, at: $1) }) % 2
        // うるう秒フラグ
        let ls1 = bitValue(in: frame, at: 53)
        let ls2 = bitValue(in: frame, at: 54)
        logger.debug("JJY frame @M:")
        logger.debug("  Base (JST): \(ts)")
        logger.debug("  :00-:09     \(pattern)")
        logger.debug("  Minute      = \(minute)  BCD T=\(minT) O=\(minO)  bits T(1..3)=\(tenBits) O(5..8)=\(oneBits)")
        logger.debug("  Parity(H)   = sent \(paHour) / calc \(calcPaHour)  Parity(M) = sent \(paMin) / calc \(calcPaMin)")
        logger.debug("  LS1/LS2     = \(ls1)/\(ls2)")
        // フレーム長（59/60/61）
        logger.debug("  Frame secs  = \(frame.count))")
    }
    
    private func symbolChar(_ s: JJYSymbol) -> Character {
        switch s {
        case .mark: return "M"
        case .bit1: return "1"
        case .bit0: return "0"
        case .morse: return "M" // 呼出符号期間は便宜的に M
        }
    }
    
    private func bitValue(in frame: [JJYSymbol], at index: Int) -> Int {
        guard index >= 0 && index < frame.count else { return 0 }
        return (frame[index] == .bit1) ? 1 : 0
    }
    
    // MARK: - Private Helpers (Hardware Sample Rate)
    /// 既定の出力デバイスのサンプルレートを希望値へ変更を試みる（macOS CoreAudio）。
    /// - Returns: 実際に変更できた場合 true（または既に一致）。不可能/非対応なら false。
    private func trySetHardwareSampleRate(_ desired: Double) -> Bool {
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
