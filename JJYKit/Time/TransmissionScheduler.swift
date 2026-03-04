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
    // Track last minute base time used for rebuild requests so we can detect minute rollover
    private var lastRequestedBaseTime: Date? = nil
    
    // Timer
    private let syncQueue = DispatchQueue(label: "TransmissionScheduler.sync")
    private let syncQueueKey = DispatchSpecificKey<Void>()
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
        syncQueue.setSpecific(key: syncQueueKey, value: ())
        if let notificationName = clock.advancementNotificationName {
            let observerObject = clock as AnyObject
            NotificationCenter.default.addObserver(self, selector: #selector(mockClockAdvanced(_:)), name: notificationName, object: observerObject)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func mockClockAdvanced(_ note: Notification) {
        if DispatchQueue.getSpecific(key: syncQueueKey) != nil {
            handleTimerEvent()
            return
        }

        // If the notification originated from a Clock (e.g., test MockClock), process synchronously
        // so that tests which advance the mock clock observe immediate scheduler reactions.
        if let _ = note.object as? Clock {
            syncQueue.sync { [weak self] in
                guard let self = self else { return }
                self.handleTimerEvent()
            }
        } else {
            // Ensure processing happens on the scheduler sync queue to keep state consistent
            syncQueue.async { [weak self] in
                guard let self = self else { return }
                self.handleTimerEvent()
            }
        }
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
        // Serialize start/stop actions to avoid race conditions when called concurrently
        // Make initialization synchronous so callers (and tests) observe consistent state immediately
        syncQueue.sync { [weak self] in
            guard let self = self else { return }
            let cal = self.frameService.jstCalendar()
            let now = self.clock.currentDate()
            let currentSecond = cal.component(.second, from: now)
            let currentMinuteStart = self.frameService.currentMinuteStart(from: now, calendar: cal)
            
            // Build initial frame
            self.currentFrame = self.frameService.buildFrame(
                enableCallsign: self.enableCallsign,
                enableServiceStatusBits: self.enableServiceStatusBits,
                leapSecondPlan: self.leapSecondPlan,
                leapSecondPending: self.leapSecondPending,
                leapSecondInserted: self.leapSecondInserted,
                serviceStatusBits: self.serviceStatusBits
            )

            // Request initial frame rebuild for the current minute
            self.delegate?.schedulerDidRequestFrameRebuild(for: currentMinuteStart)
            // Remember the last requested base time so we can detect minute rollovers
            self.lastRequestedBaseTime = currentMinuteStart

            // 初回は次の整数秒境界で再生されるシンボルに合わせる
            self.currentSecondIndex = (currentSecond + 1) % self.currentFrame.count
            
            // ホスト時刻で次の整数秒境界に合わせる
            let nowEpoch = self.clock.currentDate().timeIntervalSince1970
            let frac = nowEpoch - floor(nowEpoch)
            let delta = 1.0 - frac
            let hostNow = self.clock.currentHostTime()
            self.hostClockFrequency = self.clock.hostClockFrequency()
            self.ticksPerSecond = UInt64(self.hostClockFrequency)
            self.nextHostTime = hostNow &+ UInt64(delta * self.hostClockFrequency)
            _ = AVAudioTime(hostTime: self.nextHostTime)
            
            // Schedule only the next second so we stay close to real time
            let when = AVAudioTime(hostTime: self.nextHostTime)
            self.delegate?.schedulerDidRequestSecondScheduling(
                symbol: self.currentFrame[self.currentSecondIndex],
                secondIndex: self.currentSecondIndex,
                when: when
            )
            self.advanceSecondIndex()
            self.nextHostTime &+= self.ticksPerSecond

            // Log initial scheduling state for debugging
            logger.debug("startScheduling: baseTime=\(currentMinuteStart, privacy: .public) lastRequestedBaseTime=\(String(describing: self.lastRequestedBaseTime), privacy: .public) frameCount=\(self.currentFrame.count, privacy: .public) currentSecondIndex=\(self.currentSecondIndex, privacy: .public) nextHostTime=\(self.nextHostTime, privacy: .public) hostClockFrequency=\(self.hostClockFrequency, privacy: .public)")

            // Start periodic timer to continue scheduling beyond the initial frame
            self.startTimer()
        }
    }
    
    func stopScheduling() {
        if DispatchQueue.getSpecific(key: syncQueueKey) != nil {
            _stopScheduling()
            return
        }

        // Make stopScheduling synchronous to ensure tests observing immediate stop see consistent state
        syncQueue.sync { [weak self] in
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
        let interval: DispatchTimeInterval = clock.advancementNotificationName != nil ? .milliseconds(100) : .seconds(1)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
        timer.setEventHandler { [weak self] in
            self?.handleTimerEvent()
        }
        timer.resume()
    }
    
    private func handleTimerEvent() {
        let cal = frameService.jstCalendar()
        let hostNowInner = clock.currentHostTime()
        let currentDate = clock.currentDate()
        let currentBase = frameService.currentMinuteStart(from: currentDate, calendar: cal)

        logger.debug("handleTimerEvent: hostNow=\(hostNowInner, privacy: .public) nextHostTime=\(self.nextHostTime, privacy: .public) lastRequestedBaseTime=\(String(describing: self.lastRequestedBaseTime), privacy: .public) currentFrameCount=\(self.currentFrame.count, privacy: .public) currentSecondIndex=\(self.currentSecondIndex, privacy: .public) currentBase=\(currentBase, privacy: .public)")
        // If the current frame hasn't been initialized yet, skip processing to avoid divide-by-zero and invalid scheduling
        if self.currentFrame.isEmpty {
            logger.debug("handleTimerEvent: currentFrame empty; skipping processing until a frame is available")
            return
        }
        
        // Detect minute-rollover based on the clock even if we previously scheduled far into the future.
        // This ensures tests that advance the mock clock trigger a rebuild immediately.
        var didRebuildInResync = false
        if let lastBase = lastRequestedBaseTime {
            if currentBase > lastBase {
                let newFrame = frameService.buildFrameForTime(
                    currentBase,
                    enableCallsign: enableCallsign,
                    enableServiceStatusBits: enableServiceStatusBits,
                    leapSecondPlan: leapSecondPlan,
                    leapSecondPending: leapSecondPending,
                    leapSecondInserted: leapSecondInserted,
                    serviceStatusBits: serviceStatusBits
                )
                currentFrame = newFrame
                delegate?.schedulerDidRequestFrameRebuild(for: currentBase)
                lastRequestedBaseTime = currentBase
                logger.debug("minute-rollover rebuild for base=\(currentBase, privacy: .public) frameCount=\(self.currentFrame.count, privacy: .public) hostNow=\(hostNowInner, privacy: .public)")
                // mark that we rebuilt due to minute rollover so we don't rebuild again below
                didRebuildInResync = true
                // If clock jumped far ahead, re-sync nextHostTime and currentSecondIndex
                let toleranceTicks_local = UInt64(0.2 * hostClockFrequency)
                let minLeadTicks_local = UInt64(0.02 * hostClockFrequency)
                if hostNowInner > (nextHostTime &+ toleranceTicks_local) || nextHostTime <= (hostNowInner &+ minLeadTicks_local) {
                    let nowEpoch2 = currentDate.timeIntervalSince1970
                    let frac2 = nowEpoch2 - floor(nowEpoch2)
                    let delta2 = 1.0 - frac2
                    nextHostTime = hostNowInner &+ UInt64(delta2 * hostClockFrequency)
                    let upcomingDate = currentDate.addingTimeInterval(delta2)
                    let secUpcoming = cal.component(.second, from: upcomingDate)
                    currentSecondIndex = secUpcoming % currentFrame.count
                }
            }
        } else {
            lastRequestedBaseTime = currentBase
        }
        
        // 遅延や進み過ぎを検知して再同期（しきい値: 200ms）
        let toleranceTicks = UInt64(0.2 * hostClockFrequency)
        let minLeadTicks = UInt64(0.02 * hostClockFrequency)
        
        if hostNowInner > (nextHostTime &+ toleranceTicks) || nextHostTime <= (hostNowInner &+ minLeadTicks) {
            // 現在時刻から次の整数秒境界へ再同期
            let nowEpoch2 = currentDate.timeIntervalSince1970
            let frac2 = nowEpoch2 - floor(nowEpoch2)
            let delta2 = 1.0 - frac2
            nextHostTime = hostNowInner &+ UInt64(delta2 * hostClockFrequency)
            let upcomingDate = currentDate.addingTimeInterval(delta2)
            // 次に再生される整数秒境界に合わせ直す
            let secUpcoming = cal.component(.second, from: upcomingDate)
            currentSecondIndex = secUpcoming % currentFrame.count
            // 常にフレーム再構築要求を出す（ドリフト検出時の再同期トリガ）
            let baseTime2 = frameService.currentMinuteStart(from: upcomingDate, calendar: cal)
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
            // remember that we requested rebuild for this minute
            lastRequestedBaseTime = baseTime2
            logger.debug("resync rebuild for base=\(baseTime2, privacy: .public) hostNow=\(hostNowInner, privacy: .public) currentSecondIndex=\(self.currentSecondIndex, privacy: .public) frameCount=\(self.currentFrame.count, privacy: .public)")
            didRebuildInResync = true
        }
        
        // 分境界（currentSecondIndex==0）では毎回新しいフレームに切り替える（上で再構築していなければ）
        if currentSecondIndex == 0 && !didRebuildInResync {
            let baseTime3 = frameService.currentMinuteStart(from: currentDate, calendar: cal)
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
            lastRequestedBaseTime = baseTime3
            logger.debug("boundary rebuild for base=\(baseTime3, privacy: .public) frameCount=\(self.currentFrame.count, privacy: .public)")
        }

        let maxLeadSeconds = clock.advancementNotificationName != nil ? 60.0 : 1.0
        let maxLeadTicks = UInt64(maxLeadSeconds * hostClockFrequency)
        let maxHostTime = hostNowInner &+ maxLeadTicks
        if nextHostTime > maxHostTime {
            logger.debug("skipping scheduling because nextHostTime is too far ahead: hostNow=\(hostNowInner, privacy: .public) nextHostTime=\(self.nextHostTime, privacy: .public) maxLeadTicks=\(maxLeadTicks, privacy: .public)")
            return
        }

        while nextHostTime <= maxHostTime {
            let when = AVAudioTime(hostTime: nextHostTime)
            logger.debug("scheduling second index=\(self.currentSecondIndex, privacy: .public) when=\(self.nextHostTime, privacy: .public) symbol=\(String(describing: self.currentFrame[self.currentSecondIndex]), privacy: .public)")
            delegate?.schedulerDidRequestSecondScheduling(
                symbol: currentFrame[currentSecondIndex], 
                secondIndex: currentSecondIndex, 
                when: when
            )
            advanceSecondIndex()
            nextHostTime &+= ticksPerSecond
        }
    }
    
    private func advanceSecondIndex() {
        currentSecondIndex += 1
        if currentSecondIndex >= currentFrame.count { currentSecondIndex = 0 }
    }
}
