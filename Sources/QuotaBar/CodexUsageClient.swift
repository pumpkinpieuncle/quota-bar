import Foundation

actor CodexUsageClient {
    struct UsageResult: Sendable {
        let limits: [LimitWindow]
        let fetchedAt: Date
        let plan: String
    }

    enum UsageError: LocalizedError {
        case executableMissing
        case launchFailed
        case timedOut
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .executableMissing:
                "The official Codex executable could not be found."
            case .launchFailed:
                "The Codex account reader could not be started."
            case .timedOut:
                "The Codex account reader timed out."
            case .invalidResponse:
                "Codex returned an unreadable account-usage response."
            case .server(let message):
                "Codex account reader error: \(message)"
            }
        }
    }

    private var lastRemoteFetch: Date?
    private var lastResult: UsageResult?
    private var lastResponse: Data?

    func fetchIfNeeded(
        force: Bool,
        language: AppLanguage
    ) async throws -> UsageResult {
        if
            !force,
            let lastRemoteFetch,
            let lastResult,
            Date().timeIntervalSince(lastRemoteFetch) < 300
        {
            if let lastResponse {
                return try Self.parseResponse(
                    lastResponse,
                    fetchedAt: lastResult.fetchedAt,
                    language: language
                )
            }
            return lastResult
        }

        let response = try await Task.detached(priority: .utility) {
            try Self.readAccountRateLimits()
        }.value
        let result = try Self.parseResponse(
            response,
            fetchedAt: Date(),
            language: language
        )
        lastRemoteFetch = result.fetchedAt
        lastResult = result
        lastResponse = response
        return result
    }

    static func parseResponse(
        _ data: Data,
        fetchedAt: Date = Date(),
        language: AppLanguage = .chinese
    ) throws -> UsageResult {
        guard
            let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw UsageError.invalidResponse
        }
        if let error = envelope["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "unknown error"
            throw UsageError.server(message)
        }
        guard let result = envelope["result"] as? [String: Any] else {
            throw UsageError.invalidResponse
        }

        let rateLimits: [String: Any]? = {
            if
                let byID = result["rateLimitsByLimitId"] as? [String: Any],
                let codex = byID["codex"] as? [String: Any]
            {
                return codex
            }
            return result["rateLimits"] as? [String: Any]
        }()
        guard let rateLimits else { throw UsageError.invalidResponse }

        var limits: [LimitWindow] = []
        for (id, key) in [("primary", "primary"), ("secondary", "secondary")] {
            guard let window = rateLimits[key] as? [String: Any] else { continue }
            let used = LocalCollectors.number(window["usedPercent"]) ?? 0
            let minutes = Int(LocalCollectors.number(window["windowDurationMins"]) ?? 0)
            let resetAt = LocalCollectors.number(window["resetsAt"]).flatMap {
                $0 > 0 ? Date(timeIntervalSince1970: $0) : nil
            }
            limits.append(
                LimitWindow(
                    id: "account-\(id)-\(minutes)",
                    label: windowLabel(minutes: minutes, language: language),
                    remainingPercent: 100 - used,
                    resetAt: resetAt
                )
            )
        }
        guard !limits.isEmpty else { throw UsageError.invalidResponse }

        let plan = (rateLimits["planType"] as? String ?? "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return UsageResult(limits: limits, fetchedAt: fetchedAt, plan: plan)
    }

    private nonisolated static func windowLabel(
        minutes: Int,
        language: AppLanguage
    ) -> String {
        guard language == .english else {
            return LocalCollectors.windowLabel(minutes: minutes)
        }
        return switch minutes {
        case 300: "5 hours"
        case 1_440: "1 day"
        case 10_080: "7 days"
        case let value where value > 0 && value % 1_440 == 0:
            "\(value / 1_440) days"
        case let value where value > 0 && value % 60 == 0:
            "\(value / 60) hours"
        case let value where value > 0:
            "\(value) minutes"
        default:
            "Quota"
        }
    }

    private nonisolated static func readAccountRateLimits() throws -> Data {
        guard let executable = codexExecutable() else {
            throw UsageError.executableMissing
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw UsageError.launchFailed
        }

        let timeout = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + 8,
            execute: timeout
        )
        defer {
            timeout.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
        }

        try send(
            [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "quota-bar",
                        "title": "Quota Bar",
                        "version": "1.2.4"
                    ],
                    "capabilities": ["experimentalApi": true]
                ]
            ],
            to: input.fileHandleForWriting
        )

        var buffer = Data()
        var responseData: Data?
        var sentReadRequest = false
        while process.isRunning, responseData == nil {
            let chunk = output.fileHandleForReading.availableData
            guard !chunk.isEmpty else { break }
            buffer.append(chunk)
            for line in takeLines(from: &buffer) {
                guard
                    let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                    let responseID = LocalCollectors.number(object["id"])
                else {
                    continue
                }
                if responseID == 1, !sentReadRequest {
                    try send(["method": "initialized"], to: input.fileHandleForWriting)
                    try send(
                        [
                            "id": 2,
                            "method": "account/rateLimits/read",
                            "params": NSNull()
                        ],
                        to: input.fileHandleForWriting
                    )
                    sentReadRequest = true
                } else if responseID == 2 {
                    responseData = line
                    break
                }
            }
        }

        if let responseData {
            return responseData
        }
        for line in takeLines(from: &buffer, includeTrailing: true) {
            guard
                let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                LocalCollectors.number(object["id"]) == 2
            else {
                continue
            }
            return line
        }
        if !process.isRunning {
            throw UsageError.timedOut
        }
        throw UsageError.invalidResponse
    }

    private nonisolated static func send(
        _ object: [String: Any],
        to handle: FileHandle
    ) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private nonisolated static func takeLines(
        from buffer: inout Data,
        includeTrailing: Bool = false
    ) -> [Data] {
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            if !line.isEmpty {
                lines.append(Data(line))
            }
            buffer.removeSubrange(...newline)
        }
        if includeTrailing, !buffer.isEmpty {
            lines.append(buffer)
            buffer.removeAll()
        }
        return lines
    }

    private nonisolated static func codexExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.lazy
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
