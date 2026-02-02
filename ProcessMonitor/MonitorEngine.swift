import Foundation
import Combine

@MainActor
final class MonitorEngine: ObservableObject {
    @Published var processHealths: [ProcessHealth] = []
    @Published var allHealthy: Bool = true
    @Published var configLoaded: Bool = false

    private var config: MonitorConfig?
    private var timer: Timer?
    private var previousHealthMap: [String: Bool] = [:]

    init() {
        NotificationManager.shared.requestPermission()
        loadConfig()
    }

    func loadConfig() {
        timer?.invalidate()
        timer = nil
        previousHealthMap = [:]

        do {
            config = try MonitorConfig.load()
            configLoaded = true
            startTimer()
            Task { await runChecks() }
        } catch {
            configLoaded = false
            processHealths = []
            allHealthy = true
            if !FileManager.default.fileExists(atPath: MonitorConfig.configPath.path) {
                NotificationManager.shared.notifyMissingConfig()
            }
        }
    }

    func checkNow() {
        Task { await runChecks() }
    }

    private func startTimer() {
        let interval = TimeInterval(config?.checkIntervalSeconds ?? 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.runChecks()
            }
        }
    }

    private func runChecks() async {
        guard let config else { return }

        let results = await withTaskGroup(of: ProcessHealth.self) { group in
            for process in config.processes {
                group.addTask {
                    await HealthChecker.check(config: process)
                }
            }
            var collected: [ProcessHealth] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        // Preserve config order
        let orderedResults = config.processes.compactMap { pc in
            results.first(where: { $0.config.launchdLabel == pc.launchdLabel })
        }

        processHealths = orderedResults
        allHealthy = orderedResults.allSatisfy(\.isHealthy)

        // Detect transitions: healthy -> unhealthy
        for health in orderedResults {
            let wasHealthy = previousHealthMap[health.id] ?? true
            if wasHealthy && !health.isHealthy {
                NotificationManager.shared.notifyUnhealthy(
                    processName: health.config.displayName,
                    reason: health.statusDescription
                )
            }
            previousHealthMap[health.id] = health.isHealthy
        }
    }
}
