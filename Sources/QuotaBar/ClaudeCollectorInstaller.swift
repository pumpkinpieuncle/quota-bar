import Darwin
import Foundation

enum ClaudeCollectorInstaller {
    static func helperURL() -> URL? {
        guard let executable = Bundle.main.executableURL else { return nil }
        if Bundle.main.bundleURL.pathExtension == "app" {
            let helper = Bundle.main.bundleURL
                .appending(path: "Contents/Helpers/QuotaBarCapture")
            return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
        }
        let helper = executable.deletingLastPathComponent().appending(path: "QuotaBarCapture")
        return FileManager.default.isExecutableFile(atPath: helper.path) ? helper : nil
    }

    static func install() throws {
        guard let helper = helperURL() else { throw CollectorError.helperMissing }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let claudeDirectory = home.appending(path: ".claude")
        let settingsURL = claudeDirectory.appending(path: "settings.json")
        try fm.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if fm.fileExists(atPath: settingsURL.path) {
            let data = try Data(contentsOf: settingsURL)
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CollectorError.invalidSettings
            }
            settings = parsed
        }

        if let existing = settings["statusLine"] as? [String: Any] {
            let command = existing["command"] as? String ?? ""
            if !command.contains("QuotaBarCapture") {
                throw CollectorError.existingClaudeStatusLine
            }
        }

        if fm.fileExists(atPath: settingsURL.path) {
            let backupURL = claudeDirectory.appending(path: "settings.json.quotabar-backup")
            if !fm.fileExists(atPath: backupURL.path) {
                try fm.copyItem(at: settingsURL, to: backupURL)
            }
        }

        let quotedPath = "'" + helper.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        // Claude already refreshes status lines after relevant session events.
        // Leaving refreshInterval unset avoids a redundant background timer.
        settings["statusLine"] = [
            "type": "command",
            "command": quotedPath,
            "padding": 0
        ]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let hookCommand = "\(quotedPath) --hook"
        let plainEvents = [
            "PermissionRequest",
            "UserPromptSubmit",
            "PostToolUse",
            "Stop",
            "StopFailure",
            "SessionStart",
            "SessionEnd"
        ]
        for event in plainEvents {
            appendHook(command: hookCommand, event: event, matcher: nil, hooks: &hooks)
        }
        appendHook(
            command: hookCommand,
            event: "Notification",
            matcher: "permission_prompt",
            hooks: &hooks
        )
        appendHook(
            command: hookCommand,
            event: "Notification",
            matcher: "idle_prompt",
            hooks: &hooks
        )
        settings["hooks"] = hooks

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: settingsURL, options: .atomic)
        chmod(settingsURL.path, S_IRUSR | S_IWUSR)
    }

    private static func appendHook(
        command: String,
        event: String,
        matcher: String?,
        hooks: inout [String: Any]
    ) {
        var entries = hooks[event] as? [[String: Any]] ?? []
        let alreadyInstalled = entries.contains { entry in
            let existingMatcher = entry["matcher"] as? String
            guard existingMatcher == matcher,
                  let commands = entry["hooks"] as? [[String: Any]] else { return false }
            return commands.contains { ($0["command"] as? String)?.contains("QuotaBarCapture") == true }
        }
        guard !alreadyInstalled else { return }

        var entry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": command,
                "timeout": 5
            ]]
        ]
        if let matcher {
            entry["matcher"] = matcher
        }
        entries.append(entry)
        hooks[event] = entries
    }
}
