import Darwin
import Foundation

struct LocalSnapshotBundle: Sendable {
    var codex: ProviderSnapshot
    var claude: ProviderSnapshot
    var kimi: ProviderSnapshot
}

enum LocalCollectors {
    private static var fm: FileManager { FileManager.default }
    private static var home: URL { fm.homeDirectoryForCurrentUser }

    static func collect(language: AppLanguage) -> LocalSnapshotBundle {
        let processText = processList()
        return LocalSnapshotBundle(
            codex: collectCodex(processText: processText, language: language),
            claude: collectClaude(processText: processText, language: language),
            kimi: collectKimi(processText: processText, language: language)
        )
    }

    static func claudeCollectorInstalled() -> Bool {
        let settingsURL = home.appending(path: ".claude/settings.json")
        guard
            let data = try? Data(contentsOf: settingsURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let statusLine = object["statusLine"] as? [String: Any],
            let command = statusLine["command"] as? String
        else {
            return false
        }
        guard command.contains("QuotaBarCapture") else { return false }
        guard let hooks = object["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { value in
            guard let entries = value as? [[String: Any]] else { return false }
            return entries.contains { entry in
                guard let commands = entry["hooks"] as? [[String: Any]] else { return false }
                return commands.contains {
                    ($0["command"] as? String)?.contains("QuotaBarCapture") == true
                }
            }
        }
    }

    static func claudeCollectorNeedsRepair() -> Bool {
        guard claudeCollectorInstalled() else { return true }
        let settingsURL = home.appending(path: ".claude/settings.json")
        guard
            let data = try? Data(contentsOf: settingsURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let statusLine = object["statusLine"] as? [String: Any],
            let command = statusLine["command"] as? String,
            let currentHelper = ClaudeCollectorInstaller.helperURL()?.path
        else {
            return true
        }
        let configuredPath = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        return URL(fileURLWithPath: configuredPath).standardizedFileURL.path
            != URL(fileURLWithPath: currentHelper).standardizedFileURL.path
    }

    private static func collectCodex(
        processText: String,
        language: AppLanguage
    ) -> ProviderSnapshot {
        let root = home.appending(path: ".codex/sessions")
        guard let latest = latestFile(in: root, named: nil, suffix: ".jsonl") else {
            return ProviderSnapshot(
                id: .codex,
                activity: processText.localizedCaseInsensitiveContains("/codex ") ? .idle : .offline,
                limits: [],
                detail: language.text("尚未发现 Codex 本地会话", "No local Codex session found"),
                source: language.text("本地会话", "Local sessions"),
                lastUpdated: nil,
                setupAvailable: false,
                isInstalled: fm.fileExists(atPath: home.appending(path: ".codex").path)
            )
        }

        let modified = modificationDate(latest)
        let lines = tailLines(of: latest, maxBytes: 4_000_000)
        var limits: [LimitWindow] = []
        var plan = ""
        var eventActivity: ActivityState?

        for line in lines.reversed() {
            guard
                let data = line.data(using: .utf8),
                let rootObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            if let payload = rootObject["payload"] as? [String: Any] {
                if limits.isEmpty,
                   rootObject["type"] as? String == "event_msg",
                   payload["type"] as? String == "token_count",
                   let rateLimits = payload["rate_limits"] as? [String: Any] {
                    plan = (rateLimits["plan_type"] as? String)?.capitalized ?? ""
                    if let primary = rateLimits["primary"] as? [String: Any] {
                        limits.append(makePercentWindow(primary, fallbackID: "primary"))
                    }
                    if let secondary = rateLimits["secondary"] as? [String: Any] {
                        limits.append(makePercentWindow(secondary, fallbackID: "secondary"))
                    }
                }
                if eventActivity == nil {
                    eventActivity = codexActivity(rootType: rootObject["type"] as? String, payload: payload)
                }
            }
            if !limits.isEmpty, eventActivity != nil { break }
        }

        let liveManagedTasks = liveCodexManagedTaskCount()
        let recentlyChanged = modified.map { Date().timeIntervalSince($0) < 90 } ?? false
        let activity: ActivityState
        if eventActivity == .waitingApproval {
            activity = .waitingApproval
        } else if eventActivity == .idle, liveManagedTasks == 0 {
            activity = .idle
        } else if liveManagedTasks > 0 || recentlyChanged {
            activity = eventActivity == .thinking ? .thinking : .working
        } else {
            activity = .idle
        }
        let folder = latest.deletingLastPathComponent().lastPathComponent
        let detail = liveManagedTasks > 0
            ? language.text(
                "\(liveManagedTasks) 个任务正在执行",
                "\(liveManagedTasks) task\(liveManagedTasks == 1 ? "" : "s") running"
            )
            : (
                plan.isEmpty
                    ? language.text("最近会话 · \(folder)", "Latest session · \(folder)")
                    : language.text(
                        "\(plan) · 最近会话 \(folder)",
                        "\(plan) · latest session \(folder)"
                    )
            )

        return ProviderSnapshot(
            id: .codex,
            activity: activity,
            limits: limits,
            detail: detail,
            source: language.text(
                "Codex 本地 rate-limit 快照",
                "Local Codex rate-limit snapshot"
            ),
            lastUpdated: modified,
            setupAvailable: false,
            isInstalled: true
        )
    }

    private static func collectClaude(
        processText: String,
        language: AppLanguage
    ) -> ProviderSnapshot {
        let cache = home.appending(path: ".quotabar/claude-status.json")
        let isRunning = containsStandaloneProcess("claude", in: processText)
        let installed = fm.fileExists(atPath: home.appending(path: ".claude").path)
        let collectorInstalled = claudeCollectorInstalled()
        let collectorNeedsRepair = claudeCollectorNeedsRepair()

        guard
            let data = try? Data(contentsOf: cache),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            let detail: String
            if claudeCommandLinkIsBroken() {
                detail = language.text(
                    "Claude 命令链接失效，请修复后重启 Claude Code",
                    "Claude command link is broken; repair it and restart Claude Code"
                )
            } else if collectorInstalled && !collectorNeedsRepair {
                detail = language.text(
                    "等待 Claude 正常响应后写入额度与重置时间",
                    "Waiting for a normal Claude response to capture quota and reset times"
                )
            } else if installed {
                detail = language.text(
                    "配置或修复零额度 status-line 采集",
                    "Configure or repair zero-token status-line capture"
                )
            } else {
                detail = language.text("未发现 Claude Code", "Claude Code not found")
            }
            return ProviderSnapshot(
                id: .claude,
                activity: isRunning ? claudeActivity() : (installed ? .idle : .offline),
                limits: [],
                detail: detail,
                source: language.text("Claude 官方 status line", "Official Claude status line"),
                lastUpdated: nil,
                setupAvailable: installed,
                isInstalled: installed
            )
        }

        var limits: [LimitWindow] = []
        if let rateLimits = object["rate_limits"] as? [String: Any] {
            if let fiveHour = rateLimits["five_hour"] as? [String: Any] {
                limits.append(makeClaudeWindow(fiveHour, id: "five-hour", label: "5 小时"))
            }
            if let sevenDay = rateLimits["seven_day"] as? [String: Any] {
                limits.append(makeClaudeWindow(sevenDay, id: "seven-day", label: "7 天"))
            }
        }

        let capturedAt = number(object["captured_at"]).map { Date(timeIntervalSince1970: $0) }
        let modelObject = object["model"] as? [String: Any]
        let model = (modelObject?["display_name"] as? String)
            ?? (modelObject?["id"] as? String)
            ?? "Claude"
        let cwd = (object["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }
        let version = object["version"] as? String
        let detail: String
        if limits.isEmpty {
            detail = language.text(
                "尚未收到额度字段 · 仅 Pro/Max 首次响应后提供",
                "No quota fields yet · available to Pro/Max after the first response"
            )
        } else {
            detail = [model, version, cwd].compactMap { $0 }.joined(separator: " · ")
        }

        return ProviderSnapshot(
            id: .claude,
            activity: isRunning ? claudeActivity() : .idle,
            limits: limits,
            detail: detail,
            source: language.text("Claude 官方 status line", "Official Claude status line"),
            lastUpdated: capturedAt ?? modificationDate(cache),
            setupAvailable: false,
            isInstalled: true
        )
    }

    private static func collectKimi(
        processText: String,
        language: AppLanguage
    ) -> ProviderSnapshot {
        let root = home.appending(path: ".kimi-code/sessions")
        let installed = fm.fileExists(atPath: home.appending(path: ".kimi-code/bin/kimi").path)
        let isRunning = containsStandaloneProcess("kimi", in: processText)
        let latestWire = latestFile(in: root, named: "wire.jsonl", suffix: nil)
        var detail = installed
            ? language.text("等待额度同步", "Waiting for quota sync")
            : language.text("未发现 Kimi Code", "Kimi Code not found")
        var modified: Date?
        var activity: ActivityState = isRunning ? .idle : (installed ? .idle : .offline)

        if let latestWire {
            modified = modificationDate(latestWire)
            let lines = tailLines(of: latestWire, maxBytes: 1_500_000)
            activity = kimiActivity(lines: lines, isRunning: isRunning, modified: modified)
            for line in lines.reversed() {
                guard
                    let data = line.data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    continue
                }
                if let usage = object["usage"] as? [String: Any] {
                    let input = number(usage["inputOther"]) ?? 0
                    let cache = number(usage["inputCacheRead"]) ?? 0
                    let output = number(usage["output"]) ?? 0
                    let total = Int(input + cache + output)
                    let model = (object["model"] as? String) ?? "Kimi"
                    detail = language.text(
                        "\(model.replacingOccurrences(of: "kimi-code/", with: "")) · 最近一轮 \(compactNumber(total)) tokens",
                        "\(model.replacingOccurrences(of: "kimi-code/", with: "")) · last turn \(compactNumber(total)) tokens"
                    )
                    break
                }
            }
        }

        return ProviderSnapshot(
            id: .kimi,
            activity: activity,
            limits: [],
            detail: detail,
            source: language.text(
                "Kimi 官方 /usages + 本地会话",
                "Official Kimi /usages + local sessions"
            ),
            lastUpdated: modified,
            setupAvailable: false,
            isInstalled: installed
        )
    }

    private static func makePercentWindow(
        _ object: [String: Any],
        fallbackID: String
    ) -> LimitWindow {
        let minutes = Int(number(object["window_minutes"]) ?? 0)
        let used = number(object["used_percent"]) ?? 0
        let reset = number(object["resets_at"]).map { Date(timeIntervalSince1970: $0) }
        return LimitWindow(
            id: "\(fallbackID)-\(minutes)",
            label: windowLabel(minutes: minutes),
            remainingPercent: 100 - used,
            resetAt: reset
        )
    }

    private static func makeClaudeWindow(
        _ object: [String: Any],
        id: String,
        label: String
    ) -> LimitWindow {
        let used = number(object["used_percentage"]) ?? 0
        let reset = flexibleDate(object["resets_at"])
        return LimitWindow(
            id: id,
            label: label,
            remainingPercent: 100 - used,
            resetAt: reset
        )
    }

    static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func flexibleDate(_ value: Any?) -> Date? {
        if let epoch = number(value), epoch > 0 {
            let seconds = epoch > 10_000_000_000 ? epoch / 1_000 : epoch
            return Date(timeIntervalSince1970: seconds)
        }
        guard let string = value as? String else { return nil }
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    static func windowLabel(minutes: Int) -> String {
        switch minutes {
        case 300: "5 小时"
        case 1_440: "1 天"
        case 10_080: "7 天"
        case let value where value > 0 && value % 1_440 == 0: "\(value / 1_440) 天"
        case let value where value > 0 && value % 60 == 0: "\(value / 60) 小时"
        case let value where value > 0: "\(value) 分钟"
        default: "额度"
        }
    }

    static func compactNumber(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            String(format: "%.1fK", Double(value) / 1_000)
        default:
            "\(value)"
        }
    }

    private static func processList() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,etime=,args="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // Drain stdout before waiting so a long process list cannot fill the
            // pipe buffer and deadlock the background refresh.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func containsStandaloneProcess(_ name: String, in list: String) -> Bool {
        list.split(separator: "\n").contains { line in
            let lower = line.lowercased()
            guard !lower.contains("quotabar") else { return false }
            return lower.contains("/\(name) ")
                || lower.hasSuffix("/\(name)")
                || lower.contains(" \(name) ")
        }
    }

    private static func codexActivity(
        rootType: String?,
        payload: [String: Any]
    ) -> ActivityState? {
        let payloadType = (payload["type"] as? String ?? "").lowercased()
        let name = (payload["name"] as? String ?? "").lowercased()
        if name.contains("request_user_input")
            || name.contains("ask_user")
            || payloadType.contains("approval_request")
        {
            return .waitingApproval
        }
        if rootType == "response_item", payloadType == "reasoning" {
            return .thinking
        }
        switch payloadType {
        case "task_complete":
            return .idle
        case "agent_reasoning":
            return .thinking
        case "task_started", "agent_message", "mcp_tool_call_begin", "web_search_begin":
            return .working
        default:
            if rootType == "response_item",
               payloadType == "function_call" || payloadType == "custom_tool_call" {
                return .working
            }
            return nil
        }
    }

    private static func claudeActivity() -> ActivityState {
        let url = home.appending(path: ".quotabar/claude-activity.json")
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let captured = number(object["captured_at"]),
            Date().timeIntervalSince1970 - captured < 900,
            let raw = object["state"] as? String,
            let state = ActivityState(rawValue: raw)
        else {
            return .idle
        }
        return state
    }

    private static func claudeCommandLinkIsBroken() -> Bool {
        let command = home.appending(path: ".local/bin/claude")
        guard
            let attributes = try? fm.attributesOfItem(atPath: command.path),
            attributes[.type] as? FileAttributeType == .typeSymbolicLink
        else {
            return false
        }
        return !fm.fileExists(atPath: command.path)
    }

    private static func kimiActivity(
        lines: [String],
        isRunning: Bool,
        modified: Date?
    ) -> ActivityState {
        guard isRunning else { return .idle }
        for line in lines.reversed() {
            guard
                let data = line.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }
            let type = object["type"] as? String ?? ""
            let event = object["event"] as? [String: Any]
            let eventType = event?["type"] as? String ?? ""
            let eventName = event?["name"] as? String ?? ""
            if eventType == "tool.call",
               eventName == "AskUserQuestion" || eventName == "ExitPlanMode" {
                return .waitingApproval
            }
            if type == "llm.request" || eventType == "step.begin" {
                return .working
            }
            if eventType == "step.end"
                || type == "turn.steer"
                || type == "context.append_message" {
                break
            }
        }
        let recentlyChanged = modified.map { Date().timeIntervalSince($0) < 60 } ?? false
        return recentlyChanged ? .working : .idle
    }

    private static func liveCodexManagedTaskCount() -> Int {
        let url = home.appending(path: ".codex/process_manager/chat_processes.json")
        guard
            let data = try? Data(contentsOf: url),
            let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return 0
        }
        return items.reduce(into: 0) { count, item in
            guard let pidValue = number(item["osPid"]) else { return }
            if Darwin.kill(pid_t(pidValue), 0) == 0 {
                count += 1
            }
        }
    }

    private static func latestFile(
        in root: URL,
        named: String?,
        suffix: String?
    ) -> URL? {
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var result: (url: URL, date: Date)?
        for case let url as URL in enumerator {
            if let named, url.lastPathComponent != named { continue }
            if let suffix, !url.lastPathComponent.hasSuffix(suffix) { continue }
            guard
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                values.isRegularFile == true,
                let date = values.contentModificationDate
            else {
                continue
            }
            if result == nil || date > result!.date {
                result = (url, date)
            }
        }
        return result?.url
    }

    private static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func tailLines(of url: URL, maxBytes: UInt64) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let length = (try? handle.seekToEnd()) ?? 0
        let offset = length > maxBytes ? length - maxBytes : 0
        try? handle.seek(toOffset: offset)
        let data = (try? handle.readToEnd()) ?? Data()
        guard var text = String(data: data, encoding: .utf8) else { return [] }
        if offset > 0, let firstNewline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNewline)...])
        }
        return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
}
