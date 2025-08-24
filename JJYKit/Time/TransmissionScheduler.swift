import Foundation
import AVFoundation
import OSLog

// MARK: - TransmissionSchedulerDelegate
protocol TransmissionSchedulerDelegate: AnyObject {
    func schedulerDidRequestFrameRebuild(for baseTime: Date)
    func schedulerDidRequestSecondScheduling(symbol: JJYSymbol, secondIndex: Int, when: AVAudioTime)
}

// MARK: - TransmissionScheduler
/// Responsible for timer and host time scheduling, drift detection, resync policy
class TransmissionScheduler {
    private let logger = Logger(subsystem: "com.MyCometG3.JJYWave", category: "TransmissionScheduler")
    private let clock: Clock
    private let frameService: FrameService
    
    weak var delegate: TransmissionSchedulerDelegate?
    
    // MARK: - State
    private var nextHostTime: UInt64 = 0
    private var hostClockFrequency: Double = 0
    private var ticksPerSecond: UInt64 = 0
    private var currentSecondIndex: Int = 0
    private var currentFrame: [JJYSymbol] = []
    
    // Timer
    private let syncQueue = DispatchQueue(label: "TransmissionScheduler.sync")
    private var dispatchTimer: DispatchSourceTimer?
    
    // Configuration
    private var enableCallsign: Bool = true
    private var enableServiceStatusBits: Bool = true
    private var leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: JJYAudioGenerator.LeapKind)? = nil
    private var leapSecondPending: Bool = false
    private var leapSecondInserted: Bool = true
    private var serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool) = (false,false,false,false,false,false)
    
    init(clock: Clock = SystemClock(), frameService: FrameService) {
        self.clock = clock
        self.frameService = frameService
    }
    
    // MARK: - Configuration
    func updateConfiguration(
        enableCallsign: Bool,
        enableServiceStatusBits: Bool,
        leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: JJYAudioGenerator.LeapKind)?,
        leapSecondPending: Bool,
        leapSecondInserted: Bool,
        serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool)
    ) {
        syncQueue.async { [weak self] in
            self?.enableCallsign = enableCallsign
            self?.enableServiceStatusBits = enableServiceStatusBits
            self?.leapSecondPlan = leapSecondPlan
            self?.leapSecondPending = leapSecondPending
            self?.leapSecondInserted = leapSecondInserted
            self?.serviceStatusBits = serviceStatusBits
        }
    }
    
    // MARK: - Public Methods
    func startScheduling() {
        let cal = frameService.jstCalendar()
        let now = clock.currentDate()
        let currentSecond = cal.component(.second, from: now)
        
        // Build initial frame
        currentFrame = frameService.buildFrame(
            enableCallsign: enableCallsign,
            enableServiceStatusBits: enableServiceStatusBits,
            leapSecondPlan: leapSecondPlan,
            leapSecondPending: leapSecondPending,
            leapSecondInserted: leapSecondInserted,
            serviceStatusBits: serviceStatusBits
        )
        
        // 初回は次の整数秒境界で (現在秒+1) のシンボルを送る
        currentSecondIndex = (currentSecond + 1) % currentFrame.count
        
        // ホスト時刻で次の整数秒境界に合わせる
        let nowEpoch = clock.currentDate().timeIntervalSince1970
        let frac = nowEpoch - floor(nowEpoch)
        let delta = 1.0 - frac
        let hostNow = clock.currentHostTime()
        hostClockFrequency = clock.hostClockFrequency()
        ticksPerSecond = UInt64(hostClockFrequency)
        nextHostTime = hostNow &+ UInt64(delta * hostClockFrequency)
        let firstWhen = AVAudioTime(hostTime: nextHostTime)
        
        // Schedule first second
        delegate?.schedulerDidRequestSecondScheduling(
            symbol: currentFrame[currentSecondIndex], 
            secondIndex: currentSecondIndex, 
            when: firstWhen
        )
        advanceSecondIndex()
        nextHostTime &+= ticksPerSecond
        
        startTimer()
    }
    
    func stopScheduling() {
        syncQueue.async { [weak self] in
            self?._stopScheduling()
        }
    }
    
    private func _stopScheduling() {
        // Cancel timer atomically
        dispatchTimer?.cancel()
        dispatchTimer = nil
        
        // Reset state
        currentSecondIndex = 0
        currentFrame.removeAll(keepingCapacity: false)
        nextHostTime = 0
        hostClockFrequency = 0
        ticksPerSecond = 0
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: syncQueue)
        dispatchTimer = timer
        let leeway: DispatchTimeInterval = .milliseconds(5)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1), leeway: leeway)
        timer.setEventHandler { [weak self] in
            self?.handleTimerEvent()
        }
        timer.resume()
    }
    
    private func handleTimerEvent() {
        let cal = frameService.jstCalendar()
        let hostNowInner = clock.currentHostTime()
        
        // 遅延や進み過ぎを検知して再同期（しきい値: 200ms）
        let toleranceTicks = UInt64(0.2 * hostClockFrequency)
        let minLeadTicks = UInt64(0.02 * hostClockFrequency)
        var didRebuildInResync = false
        
        if hostNowInner > (nextHostTime &+ toleranceTicks) || nextHostTime <= (hostNowInner &+ minLeadTicks) {
            // 現在時刻から次の整数秒境界へ再同期
            let nowEpoch2 = clock.currentDate().timeIntervalSince1970
            let frac2 = nowEpoch2 - floor(nowEpoch2)
            let delta2 = 1.0 - frac2
            nextHostTime = hostNowInner &+ UInt64(delta2 * hostClockFrequency)
            // 現在秒+1のシンボルに合わせ直す
            let secNow = cal.component(.second, from: clock.currentDate())
            currentSecondIndex = (secNow + 1) % currentFrame.count
            // 分境界ならフレーム再構築（次分の先頭マーカー時刻で構築）
            if currentSecondIndex == 0 {
                let baseTime2 = frameService.nextMinuteStart(from: clock.currentDate(), calendar: cal)
                let newFrame = frameService.buildFrameForTime(
                    baseTime2,
                    enableCallsign: enableCallsign,
                    enableServiceStatusBits: enableServiceStatusBits,
                    leapSecondPlan: leapSecondPlan,
                    leapSecondPending: leapSecondPending,
                    leapSecondInserted: leapSecondInserted,
                    serviceStatusBits: serviceStatusBits
                )
                currentFrame = newFrame
                delegate?.schedulerDidRequestFrameRebuild(for: baseTime2)
                didRebuildInResync = true
            }
        }
        
        // 分境界（currentSecondIndex==0）では毎回新しいフレームに切り替える（上で再構築していなければ）
        if currentSecondIndex == 0 && !didRebuildInResync {
            let baseTime3 = frameService.nextMinuteStart(from: clock.currentDate(), calendar: cal)
            let newFrame = frameService.buildFrameForTime(
                baseTime3,
                enableCallsign: enableCallsign,
                enableServiceStatusBits: enableServiceStatusBits,
                leapSecondPlan: leapSecondPlan,
                leapSecondPending: leapSecondPending,
                leapSecondInserted: leapSecondInserted,
                serviceStatusBits: serviceStatusBits
            )
            currentFrame = newFrame
            delegate?.schedulerDidRequestFrameRebuild(for: baseTime3)
        }
        
        let when = AVAudioTime(hostTime: nextHostTime)
        delegate?.schedulerDidRequestSecondScheduling(
            symbol: currentFrame[currentSecondIndex], 
            secondIndex: currentSecondIndex, 
            when: when
        )
        advanceSecondIndex()
        nextHostTime &+= ticksPerSecond
    }
    
    private func advanceSecondIndex() {
        currentSecondIndex += 1
        if currentSecondIndex >= currentFrame.count { currentSecondIndex = 0 }
    }
}