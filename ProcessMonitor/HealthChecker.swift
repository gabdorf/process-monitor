import Foundation

enum HealthChecker {

    static func shell(_ command: String) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", command]
            task.launch()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            continuation.resume(returning: (output, task.terminationStatus))
        }
    }

    static func checkLaunchctl(label: String) async -> (loaded: Bool, exitStatusZero: Bool) {
        let result = await shell("launchctl list \(label) 2>/dev/null")
        guard result.exitCode == 0 else {
            return (false, false)
        }

        // Parse output for "LastExitStatus" line
        var exitStatusZero = true
        for line in result.output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\"LastExitStatus\"") || trimmed.hasPrefix("LastExitStatus") {
                // Extract the number after '=' or ':'
                let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: "=;"))
                if let numberStr = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let status = Int(numberStr) {
                    exitStatusZero = (status == 0)
                }
            }
        }
        return (true, exitStatusZero)
    }

    static func checkProcess(name: String) async -> Bool {
        let result = await shell("pgrep -x \(name)")
        return result.exitCode == 0
    }

    static func checkLogAge(path: String) -> TimeInterval? {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }
        return Date().timeIntervalSince(modDate)
    }

    static func readSchedule(label: String) -> LaunchdSchedule? {
        let searchPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]

        for dir in searchPaths {
            let plistURL = dir.appendingPathComponent("\(label).plist")
            guard let data = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }

            if let seconds = plist["StartInterval"] as? Int {
                return .interval(seconds: seconds)
            }

            if let cal = plist["StartCalendarInterval"] as? [String: Any] {
                return .calendar(
                    hour: cal["Hour"] as? Int,
                    minute: cal["Minute"] as? Int,
                    weekday: cal["Weekday"] as? Int
                )
            }

            return nil
        }

        return nil
    }

    static func check(config: ProcessConfig) async -> ProcessHealth {
        var health = ProcessHealth(config: config)

        let launchctlResult = await checkLaunchctl(label: config.launchdLabel)
        health.launchdLoaded = launchctlResult.loaded
        health.lastExitStatusZero = launchctlResult.exitStatusZero

        if let processName = config.processName {
            health.processRunning = await checkProcess(name: processName)
        }

        if let logPath = config.logFilePath, !logPath.isEmpty {
            health.logAge = checkLogAge(path: logPath)
        }

        health.schedule = readSchedule(label: config.launchdLabel)

        return health
    }
}
