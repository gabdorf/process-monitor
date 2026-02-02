# ProcessMonitor

A lightweight macOS menu bar app that monitors the health of launchd services and background processes, alerting you when something goes wrong.

## Features

- **Menu bar status indicator** — green checkmark when all processes are healthy, red X when something fails
- **Launchd service monitoring** — checks if services are loaded and have zero exit status
- **Process verification** — confirms processes are actually running via `pgrep`
- **Log staleness detection** — alerts when log files haven't been updated within a configurable window
- **System notifications** — notifies you when a process transitions to an unhealthy state
- **Start at Login** — toggle via the menu to launch automatically on login

## Requirements

- macOS 12.0+
- Xcode 15.0+

## Build

```bash
xcodebuild build -project ProcessMonitor.xcodeproj -scheme ProcessMonitor
```

Or open `ProcessMonitor.xcodeproj` in Xcode and build with Cmd+B.

## Configuration

Create a config file at `~/.config/process-monitor/config.json`:

```json
{
  "checkIntervalSeconds": 60,
  "processes": [
    {
      "displayName": "My Service",
      "launchdLabel": "com.example.myservice",
      "processName": "myservice",
      "logFilePath": "~/Library/Logs/myservice.log",
      "maxAgeMinutes": 5
    }
  ]
}
```

| Field | Required | Description |
|---|---|---|
| `checkIntervalSeconds` | Yes | How often to run health checks (seconds) |
| `displayName` | Yes | Name shown in the menu bar dropdown |
| `launchdLabel` | Yes | Launchd service label to monitor |
| `processName` | No | Process name to verify with `pgrep` |
| `logFilePath` | No | Log file to check for recent activity |
| `maxAgeMinutes` | No | Max minutes since last log write before alerting |

The run schedule (e.g. "every 5 min", "daily at 9:00") is read automatically from the launchd plist file — no need to configure it manually.

## How It Works

A process is considered **healthy** when all configured conditions are met:

1. The launchd service is loaded
2. The last exit status is zero
3. The process is running (if `processName` is set)
4. The log file was recently modified (if `logFilePath` and `maxAgeMinutes` are set)

Health checks run in parallel using Swift concurrency. The app sends a notification only when a process transitions from healthy to unhealthy.
