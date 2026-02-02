import SwiftUI
import ServiceManagement

@main
struct ProcessMonitorApp: App {
    @StateObject private var engine = MonitorEngine()
    @State private var startAtLogin = SMAppService.mainApp.status == .enabled

    var body: some Scene {
        MenuBarExtra {
            if engine.configLoaded {
                ForEach(engine.processHealths) { health in
                    HStack {
                        Image(systemName: health.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(health.isHealthy ? .green : .red)
                        VStack(alignment: .leading) {
                            HStack {
                                Text(health.config.displayName)
                                if let schedule = health.schedule {
                                    Text("(\(schedule.description))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(health.lastRunDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("No config loaded")
                    .foregroundColor(.secondary)
                Text(MonitorConfig.configPath.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("Check Now") {
                engine.checkNow()
            }
            .keyboardShortcut("r")

            Button("Reload Config") {
                engine.loadConfig()
            }

            Toggle("Start at Login", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        startAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: engine.allHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
        }
    }
}
