import Foundation
import AudioToolbox

// MARK: - JJYClock Protocol
/// Abstract interface for time access to enable testability
protocol JJYClock {
    func currentDate() -> Date
    func currentHostTime() -> UInt64
    func hostClockFrequency() -> Double
}

// MARK: - SystemClock Implementation
/// Real system clock implementation
struct SystemClock: JJYClock {
    func currentDate() -> Date {
        return Date()
    }
    
    func currentHostTime() -> UInt64 {
        return AudioGetCurrentHostTime()
    }
    
    func hostClockFrequency() -> Double {
        return AudioGetHostClockFrequency()
    }
}