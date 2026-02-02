import Foundation

enum LaunchdSchedule {
    case interval(seconds: Int)
    case calendar(hour: Int?, minute: Int?, weekday: Int?)

    var description: String {
        switch self {
        case .interval(let seconds):
            let minutes = seconds / 60
            if minutes < 1 { return "every \(seconds)s" }
            if minutes < 60 { return "every \(minutes) min" }
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder == 0 {
                return hours == 1 ? "every hour" : "every \(hours) hours"
            }
            return "every \(hours)h \(remainder)m"
        case .calendar(let hour, let minute, let weekday):
            let timeStr: String
            if let h = hour, let m = minute {
                timeStr = String(format: "%d:%02d", h, m)
            } else if let h = hour {
                timeStr = "\(h):00"
            } else {
                timeStr = "scheduled"
            }
            if let w = weekday {
                let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                let day = (0...6).contains(w) ? days[w] : "day \(w)"
                return "\(day) at \(timeStr)"
            }
            return "daily at \(timeStr)"
        }
    }
}

struct ProcessHealth: Identifiable {
    var id: String { config.launchdLabel }
    let config: ProcessConfig
    var launchdLoaded: Bool = false
    var lastExitStatusZero: Bool = true
    var processRunning: Bool? = nil  // nil if processName not configured
    var logAge: TimeInterval? = nil  // nil if logFilePath not configured
    var schedule: LaunchdSchedule? = nil

    var isHealthy: Bool {
        guard launchdLoaded, lastExitStatusZero else { return false }
        if let running = processRunning, !running { return false }
        if let path = config.logFilePath, !path.isEmpty,
           let age = logAge {
            let maxAge = TimeInterval(config.maxAgeMinutes * 60)
            if age > maxAge { return false }
        }
        return true
    }

    var lastRunDescription: String {
        guard let age = logAge else { return "No log configured" }
        let minutes = Int(age / 60)
        if minutes < 1 { return "Last run: just now" }
        if minutes == 1 { return "Last run: 1 minute ago" }
        if minutes < 60 { return "Last run: \(minutes) minutes ago" }
        let hours = minutes / 60
        if hours == 1 { return "Last run: 1 hour ago" }
        return "Last run: \(hours) hours ago"
    }

    var statusDescription: String {
        if !launchdLoaded { return "Not loaded" }
        if !lastExitStatusZero { return "Non-zero exit status" }
        if let running = processRunning, !running { return "Process not running" }
        if let path = config.logFilePath, !path.isEmpty,
           let age = logAge {
            let maxAge = TimeInterval(config.maxAgeMinutes * 60)
            if age > maxAge { return "Log stale" }
        }
        return "Healthy"
    }
}
