import Foundation
import AudioToolbox

// MARK: - Clock Protocol
/// Abstract interface for time access to enable testability
protocol Clock {
    func currentDate() -> Date
    func currentHostTime() -> UInt64
    func hostClockFrequency() -> Double
}

// MARK: - SystemClock Implementation
/// Real system clock implementation
struct SystemClock: Clock {
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