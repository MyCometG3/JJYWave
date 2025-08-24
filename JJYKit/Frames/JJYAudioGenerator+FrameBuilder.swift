import Foundation

// フレーム構築（JJY仕様に基づく BCD 配置、パリティ、コールサイン、うるう秒調整）
struct JJYFrameBuilder {
    typealias LeapKind = JJYAudioGenerator.LeapKind

    struct Options {
        let enableCallsign: Bool
        let enableServiceStatusBits: Bool
        let leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: LeapKind)?
        let leapSecondPending: Bool
        let leapSecondInserted: Bool
        let serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool)
    }
    
    func build(for baseTime: Date, calendar: Calendar, options: Options) -> [JJYSymbol] {
        var symbols: [JJYSymbol] = Array(repeating: .bit0, count: 60)
        // マーカー配置（M, P1–P5）: 0,9,19,29,39,49
        JJYIndex.markers.forEach { symbols[$0] = .mark }
        
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .weekday]
        let c = calendar.dateComponents(comps, from: baseTime)
        guard let yearFull = c.year, let hour = c.hour, let minute = c.minute, let weekdayApple = c.weekday, let month = c.month, let day = c.day else { return symbols }
        // 曜日: 日=0, 月=1, …, 土=6（NICT割当）。Appleのweekday(日=1)を変換。
        let jjyWeekday = (weekdayApple == 1) ? 0 : (weekdayApple - 1)
        let doy = dayOfYearJST(year: yearFull, month: month, day: day, calendar: calendar)
        
        // 分（BCD）: 1–3=十の位(4,2,1), 5–8=一の位(8,4,2,1)
        let minT = minute / 10
        let minO = minute % 10
        set(&symbols, 1,  (minT & 0b100) != 0)
        set(&symbols, 2,  (minT & 0b010) != 0)
        set(&symbols, 3,  (minT & 0b001) != 0)
        set(&symbols, 5,  (minO & 0b1000) != 0)
        set(&symbols, 6,  (minO & 0b0100) != 0)
        set(&symbols, 7,  (minO & 0b0010) != 0)
        set(&symbols, 8,  (minO & 0b0001) != 0)
        
        // 時（BCD）: 12–13=十の位(2,1), 15–18=一の位(8,4,2,1)
        let hourT = hour / 10
        let hourO = hour % 10
        set(&symbols, 12, (hourT & 0b10) != 0)
        set(&symbols, 13, (hourT & 0b01) != 0)
        set(&symbols, 15, (hourO & 0b1000) != 0)
        set(&symbols, 16, (hourO & 0b0100) != 0)
        set(&symbols, 17, (hourO & 0b0010) != 0)
        set(&symbols, 18, (hourO & 0b0001) != 0)
        
        // 通算日（BCD）: 22–23=百の位(2,1), 25–28=十の位(8,4,2,1), 30–33=一の位(8,4,2,1)
        let doyH = doy / 100
        let doyT = (doy % 100) / 10
        let doyO = doy % 10
        set(&symbols, 22, (doyH & 0b10) != 0)
        set(&symbols, 23, (doyH & 0b01) != 0)
        set(&symbols, 25, (doyT & 0b1000) != 0)
        set(&symbols, 26, (doyT & 0b0100) != 0)
        set(&symbols, 27, (doyT & 0b0010) != 0)
        set(&symbols, 28, (doyT & 0b0001) != 0)
        set(&symbols, 30, (doyO & 0b1000) != 0)
        set(&symbols, 31, (doyO & 0b0100) != 0)
        set(&symbols, 32, (doyO & 0b0010) != 0)
        set(&symbols, 33, (doyO & 0b0001) != 0)
        
        // パリティ（偶数）: 36=時、37=分（1の数が奇数なら1を立てる）
        // 予約ビット(4,14秒)は対象外。時=[12,13,15,16,17,18]、分=[1,2,3,5,6,7,8]
        let hourIdx = [12,13,15,16,17,18]
        var hourOnes = 0
        for i in hourIdx { if i < symbols.count, symbols[i] == .bit1 { hourOnes += 1 } }
        set(&symbols, 36, (hourOnes % 2) == 1)
        let minuteIdx = [1,2,3,5,6,7,8]
        var minuteOnes = 0
        for i in minuteIdx { if i < symbols.count, symbols[i] == .bit1 { minuteOnes += 1 } }
        set(&symbols, 37, (minuteOnes % 2) == 1)
        
        // SU1(:38), SU2(:40) 予備ビット（日本では未使用）。:39 はマーカー
        symbols[38] = .bit0
        symbols[40] = .bit0
        
        // 年（通常）／コールサイン
        let callsignMinute = options.enableCallsign && (minute == 15 || minute == 45)
        if !callsignMinute {
            let y2 = yearFull % 100
            let yT = y2 / 10
            let yO = y2 % 10
            set(&symbols, 41, (yT & 0b1000) != 0)
            set(&symbols, 42, (yT & 0b0100) != 0)
            set(&symbols, 43, (yT & 0b0010) != 0)
            set(&symbols, 44, (yT & 0b0001) != 0)
            set(&symbols, 45, (yO & 0b1000) != 0)
            set(&symbols, 46, (yO & 0b0100) != 0)
            set(&symbols, 47, (yO & 0b0010) != 0)
            set(&symbols, 48, (yO & 0b0001) != 0)
        } else {
            for s in JJYIndex.callsignStart...JJYIndex.callsignEnd { symbols[s] = .morse }
        }
        
        // 曜日 or ST と うるう秒情報
        var lsWarn = false
        var lsInsert = false
        var lsDelete = false
        if let plan = options.leapSecondPlan {
            let auto = computeLeapFlagsFor(baseTimeJST: baseTime, planYearUTC: plan.yearUTC, monthUTC: plan.monthUTC, kind: plan.kind, calendar: calendar)
            lsWarn = auto.warn
            lsInsert = auto.kindInsert
            lsDelete = auto.kindDelete
        } else {
            lsWarn = options.leapSecondPending
            lsInsert = options.leapSecondInserted && options.leapSecondPending
            lsDelete = !options.leapSecondInserted && options.leapSecondPending
        }
        if !(options.enableServiceStatusBits && callsignMinute) {
            set(&symbols, 50, (jjyWeekday & 0b100) != 0)
            set(&symbols, 51, (jjyWeekday & 0b010) != 0)
            set(&symbols, 52, (jjyWeekday & 0b001) != 0)
            if lsWarn {
                set(&symbols, 53, true)
                set(&symbols, 54, lsInsert)
            }
        } else {
            set(&symbols, 50, options.serviceStatusBits.st1)
            set(&symbols, 51, options.serviceStatusBits.st2)
            set(&symbols, 52, options.serviceStatusBits.st3)
            set(&symbols, 53, options.serviceStatusBits.st4)
            set(&symbols, 54, options.serviceStatusBits.st5)
            set(&symbols, 55, options.serviceStatusBits.st6)
        }
        
        // P0（ポジションマーカー）の配置
        // 通常: :59 をマーカー。
        // 正のうるう秒: :59 は 0、:60 をマーカー。
        // 負のうるう秒: :58 をマーカーとし、:59 は削除（59秒フレーム）。
        if lsInsert {
            symbols[59] = .bit0
            symbols.append(.mark) // 61秒フレーム（:60 マーカー）
        } else if lsDelete {
            if 58 < symbols.count { symbols[58] = .mark }
            if symbols.count == 60 {
                symbols.remove(at: 59) // 59秒フレーム
            }
        } else {
            symbols[59] = .mark
        }
        return symbols
    }

    // --- Helpers ---
    private func computeLeapFlagsFor(baseTimeJST: Date, planYearUTC: Int, monthUTC: Int? = nil, kind: LeapKind? = nil, calendar: Calendar? = nil) -> (warn: Bool, kindInsert: Bool, kindDelete: Bool) {
        // Optionalカレンダーを安全に処理。未指定ならJSTグレゴリオ暦を使用。
        let jstCal: Calendar = {
            if let cal = calendar {
                return cal
            } else {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
                return cal
            }
        }()
        // 警告期間: UTC指定の月の「JSTで毎月2日09:00」から翌月1日09:00直前まで
        let startComp = DateComponents(year: planYearUTC, month: monthUTC ?? 1, day: 2, hour: 9, minute: 0, second: 0)
        guard let warnStart = jstCal.date(from: startComp) else { return (false,false,false) }
        var endYear = planYearUTC
        var endMonth = (monthUTC ?? 1) + 1
        if endMonth == 13 { endMonth = 1; endYear += 1 }
        guard let warnEnd = jstCal.date(from: DateComponents(year: endYear, month: endMonth, day: 1, hour: 9, minute: 0, second: 0)) else {
            return (false,false,false)
        }
        let inWarn = (baseTimeJST >= warnStart && baseTimeJST < warnEnd)
        // 実施判定: 翌月1日08:59台（JST）に+1/-1の実施
        guard let execMinuteStart = jstCal.date(from: DateComponents(year: endYear, month: endMonth, day: 1, hour: 8, minute: 59, second: 0)) else {
            return (inWarn,false,false)
        }
        let isExecMinute = (baseTimeJST >= execMinuteStart && baseTimeJST < execMinuteStart.addingTimeInterval(60))
        let insert = (kind == .insert) && isExecMinute
        let delete = (kind == .delete) && isExecMinute
        return (inWarn, insert, delete)
    }
    private func set(_ symbols: inout [JJYSymbol], _ second: Int, _ isOne: Bool) {
        symbols[second] = isOne ? .bit1 : .bit0
    }
    private func dayOfYearJST(year: Int, month: Int, day: Int, calendar: Calendar) -> Int {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return 1 }
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }
}
