import Foundation
import OSLog

// MARK: - JJYFrameService
/// Responsible for frame construction, logging, and leap second/service bit logic
class JJYFrameService {
    private let logger = Logger(subsystem: "com.MyCometG3.JJYWave", category: "JJYFrame")
    private let clock: JJYClock
    
    init(clock: JJYClock = SystemClock()) {
        self.clock = clock
    }
    
    // MARK: - Public Methods
    func buildFrame(
        enableCallsign: Bool,
        enableServiceStatusBits: Bool,
        leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: JJYAudioGenerator.LeapKind)?,
        leapSecondPending: Bool,
        leapSecondInserted: Bool,
        serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool)
    ) -> [JJYSymbol] {
        let calendar = jstCalendar()
        let now = clock.currentDate()
        let baseTime = currentMinuteStart(from: now, calendar: calendar)
        
        let frameOptions = JJYFrameBuilder.Options(
            enableCallsign: enableCallsign,
            enableServiceStatusBits: enableServiceStatusBits,
            leapSecondPlan: leapSecondPlan,
            leapSecondPending: leapSecondPending,
            leapSecondInserted: leapSecondInserted,
            serviceStatusBits: serviceStatusBits
        )
        
        let frame = JJYFrameBuilder().build(for: baseTime, calendar: calendar, options: frameOptions)
        logFrame(frame, baseTime: baseTime, calendar: calendar)
        return frame
    }
    
    func buildFrameForTime(
        _ baseTime: Date,
        enableCallsign: Bool,
        enableServiceStatusBits: Bool,
        leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: JJYAudioGenerator.LeapKind)?,
        leapSecondPending: Bool,
        leapSecondInserted: Bool,
        serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool)
    ) -> [JJYSymbol] {
        let calendar = jstCalendar()
        
        let frameOptions = JJYFrameBuilder.Options(
            enableCallsign: enableCallsign,
            enableServiceStatusBits: enableServiceStatusBits,
            leapSecondPlan: leapSecondPlan,
            leapSecondPending: leapSecondPending,
            leapSecondInserted: leapSecondInserted,
            serviceStatusBits: serviceStatusBits
        )
        
        let frame = JJYFrameBuilder().build(for: baseTime, calendar: calendar, options: frameOptions)
        logFrame(frame, baseTime: baseTime, calendar: calendar)
        return frame
    }
    
    // MARK: - Time helpers (JST)
    func jstCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return cal
    }
    
    func nextMinuteStart(from date: Date, calendar: Calendar) -> Date {
        let sec = calendar.component(.second, from: date)
        let floor = calendar.date(byAdding: .second, value: -sec, to: date) ?? date
        return calendar.date(byAdding: .minute, value: 1, to: floor) ?? date
    }
    
    func currentMinuteStart(from date: Date, calendar: Calendar) -> Date {
        let sec = calendar.component(.second, from: date)
        return calendar.date(byAdding: .second, value: -sec, to: date) ?? date
    }
    
    // MARK: - Private Methods
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
}