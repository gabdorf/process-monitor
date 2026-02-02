import Foundation

struct ProcessConfig: Codable, Identifiable {
    var id: String { launchdLabel }
    let displayName: String
    let launchdLabel: String
    let processName: String?
    let logFilePath: String?
    let maxAgeMinutes: Int
}

struct MonitorConfig: Codable {
    let checkIntervalSeconds: Int
    let processes: [ProcessConfig]

    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/process-monitor")
    static let configPath = configDirectory.appendingPathComponent("config.json")

    static func load() throws -> MonitorConfig {
        let data = try Data(contentsOf: configPath)
        return try JSONDecoder().decode(MonitorConfig.self, from: data)
    }
}
