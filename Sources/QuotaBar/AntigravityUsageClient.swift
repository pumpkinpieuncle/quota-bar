import Foundation

actor AntigravityUsageClient {
    struct UsageResult: Sendable {
        let limits: [LimitWindow]
        let fetchedAt: Date
        let plan: String
        let detail: String?
        var activity: ActivityState?
    }

    enum UsageError: LocalizedError {
        case notRunning
        case portNotFound
        case timedOut
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notRunning:
                "Antigravity is not currently running."
            case .portNotFound:
                "Could not find Antigravity language_server port or CSRF token."
            case .timedOut:
                "Antigravity request timed out."
            case .invalidResponse:
                "Antigravity returned an invalid response."
            case .server(let message):
                "Antigravity server error: \(message)"
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
            Date().timeIntervalSince(lastRemoteFetch) < 30
        {
            return lastResult
        }

        guard let server = Self.findLanguageServer() else {
            // Language server is not running right now. Try to load cached result from disk.
            if let cached = Self.loadDiskCache(language: language) {
                lastResult = cached
                return cached
            }
            throw UsageError.notRunning
        }

        do {
            let data = try await Self.retrieveQuotaSummary(server: server, force: force)
            let plan = (try? await Self.fetchUserTierPlan(server: server)) ?? "Google AI Pro"
            let result = try Self.parseResponse(
                data,
                plan: plan,
                fetchedAt: Date(),
                language: language
            )
            lastRemoteFetch = result.fetchedAt
            lastResult = result
            lastResponse = data
            Self.saveDiskCache(data: data, plan: plan)
            return result
        } catch {
            if let cached = Self.loadDiskCache(language: language) {
                lastResult = cached
                return cached
            }
            throw error
        }
    }

    // MARK: - Server Discovery

    static func findLanguageServer() -> (port: Int, csrfToken: String, pid: pid_t)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,args="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        var targetPid: pid_t?
        var targetCsrf: String?

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("language_server") && trimmed.contains("--csrf_token") {
                let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                guard let pidStr = parts.first, let pid = Int32(pidStr) else { continue }
                targetPid = pid
                if let range = trimmed.range(of: "--csrf_token ") {
                    let rest = trimmed[range.upperBound...]
                    let token = rest.split(separator: " ").first.map(String.init)
                    targetCsrf = token
                }
                break
            }
        }

        guard let pid = targetPid, let csrf = targetCsrf else { return nil }

        let home = FileManager.default.homeDirectoryForCurrentUser

        // 1. Check main.log
        let mainLog = home.appendingPathComponent("Library/Logs/Antigravity/main.log")
        if let logData = try? Data(contentsOf: mainLog), let logStr = String(data: logData, encoding: .utf8) {
            let regex = try? NSRegularExpression(pattern: "https://127\\.0\\.0\\.1:(\\d+)")
            let matches = regex?.matches(in: logStr, range: NSRange(logStr.startIndex..., in: logStr)) ?? []
            if let lastMatch = matches.last, let range = Range(lastMatch.range(at: 1), in: logStr) {
                if let port = Int(logStr[range]) {
                    return (port, csrf, pid)
                }
            }
        }

        // 2. Check language_server.log (last 64KB)
        let lsLog = home.appendingPathComponent("Library/Logs/Antigravity/language_server.log")
        if let logData = try? Data(contentsOf: lsLog) {
            let offset = max(0, logData.count - 65536)
            let slice = logData.subdata(in: offset..<logData.count)
            if let logStr = String(data: slice, encoding: .utf8) {
                let regex = try? NSRegularExpression(pattern: "listening on random port at (\\d+) for HTTPS")
                let matches = regex?.matches(in: logStr, range: NSRange(logStr.startIndex..., in: logStr)) ?? []
                if let lastMatch = matches.last, let range = Range(lastMatch.range(at: 1), in: logStr) {
                    if let port = Int(logStr[range]) {
                        return (port, csrf, pid)
                    }
                }
            }
        }

        // 3. Fallback to lsof
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-Pan", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]
        let lsofPipe = Pipe()
        lsof.standardOutput = lsofPipe
        lsof.standardError = FileHandle.nullDevice
        if (try? lsof.run()) != nil {
            let lsofData = lsofPipe.fileHandleForReading.readDataToEndOfFile()
            lsof.waitUntilExit()
            if let lsofStr = String(data: lsofData, encoding: .utf8) {
                let regex = try? NSRegularExpression(pattern: ":(\\d+)\\s+\\(LISTEN\\)")
                let matches = regex?.matches(in: lsofStr, range: NSRange(lsofStr.startIndex..., in: lsofStr)) ?? []
                for match in matches {
                    if let range = Range(match.range(at: 1), in: lsofStr), let port = Int(lsofStr[range]) {
                        return (port, csrf, pid)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - RPC Calls

    private static func retrieveQuotaSummary(
        server: (port: Int, csrfToken: String, pid: pid_t),
        force: Bool
    ) async throws -> Data {
        let url = URL(string: "https://127.0.0.1:\(server.port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(server.csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")
        request.timeoutInterval = 5
        let body = ["forceRefresh": force]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let session = URLSession(
            configuration: .ephemeral,
            delegate: AntigravityTrustDelegate(),
            delegateQueue: nil
        )

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw UsageError.server("HTTP \(httpResponse.statusCode)")
        }
        return data
    }

    private static func fetchUserTierPlan(
        server: (port: Int, csrfToken: String, pid: pid_t)
    ) async throws -> String? {
        let url = URL(string: "https://127.0.0.1:\(server.port)/exa.language_server_pb.LanguageServerService/GetUserStatus")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(server.csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")
        request.timeoutInterval = 3
        request.httpBody = "{}".data(using: .utf8)

        let session = URLSession(
            configuration: .ephemeral,
            delegate: AntigravityTrustDelegate(),
            delegateQueue: nil
        )

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userTier = json["userTier"] as? [String: Any],
              let name = userTier["name"] as? String, !name.isEmpty
        else {
            return nil
        }
        return name
    }

    // MARK: - Parsing

    static func parseResponse(
        _ data: Data,
        plan: String = "Google AI Pro",
        fetchedAt: Date = Date(),
        language: AppLanguage = .chinese
    ) throws -> UsageResult {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let response = json["response"] as? [String: Any],
            let groups = response["groups"] as? [[String: Any]]
        else {
            throw UsageError.invalidResponse
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainIso = ISO8601DateFormatter()

        func parseDate(_ str: String?) -> Date? {
            guard let str else { return nil }
            return iso.date(from: str) ?? plainIso.date(from: str)
        }

        var limits: [LimitWindow] = []
        var claude3pPct: Int?

        for group in groups {
            let groupName = (group["displayName"] as? String) ?? ""
            let buckets = (group["buckets"] as? [[String: Any]]) ?? []
            let isGemini = groupName.localizedCaseInsensitiveContains("gemini")
            let is3P = groupName.localizedCaseInsensitiveContains("claude") || groupName.localizedCaseInsensitiveContains("gpt")

            for bucket in buckets {
                let bucketId = bucket["bucketId"] as? String ?? ""
                let remainingFraction = (bucket["remainingFraction"] as? NSNumber)?.doubleValue ?? 1.0
                let remainingPercent = max(0, min(100, remainingFraction * 100.0))
                let resetAt = parseDate(bucket["resetTime"] as? String)
                let window = bucket["window"] as? String ?? ""

                if isGemini {
                    if window == "5h" || bucketId.contains("5h") {
                        limits.append(LimitWindow(
                            id: "antigravity-gemini-5h",
                            label: language.text("5 小时", "5 hours"),
                            remainingPercent: remainingPercent,
                            resetAt: resetAt,
                            windowMinutes: 300
                        ))
                    } else if window == "weekly" || bucketId.contains("weekly") {
                        limits.append(LimitWindow(
                            id: "antigravity-gemini-weekly",
                            label: language.text("7 天", "7 days"),
                            remainingPercent: remainingPercent,
                            resetAt: resetAt,
                            windowMinutes: 10_080
                        ))
                    }
                } else if is3P {
                    if claude3pPct == nil {
                        claude3pPct = Int(remainingPercent.rounded())
                    }
                    if window == "5h" || bucketId.contains("5h") {
                        limits.append(LimitWindow(
                            id: "antigravity-3p-5h",
                            label: language.text("Claude/GPT 5时", "Claude/GPT 5h"),
                            remainingPercent: remainingPercent,
                            resetAt: resetAt,
                            windowMinutes: 301
                        ))
                    } else if window == "weekly" || bucketId.contains("weekly") {
                        limits.append(LimitWindow(
                            id: "antigravity-3p-weekly",
                            label: language.text("Claude/GPT 周", "Claude/GPT 7d"),
                            remainingPercent: remainingPercent,
                            resetAt: resetAt,
                            windowMinutes: 10_081
                        ))
                    }
                }
            }
        }

        // Sort so Gemini 5h and Weekly come first:
        limits.sort { lhs, rhs in
            let lhsIsGemini = lhs.id.contains("gemini")
            let rhsIsGemini = rhs.id.contains("gemini")
            if lhsIsGemini != rhsIsGemini { return lhsIsGemini }
            return lhs.effectiveMinutes < rhs.effectiveMinutes
        }

        let detailText: String
        if let claudePct = claude3pPct {
            detailText = language.text("\(plan) · Claude/GPT \(claudePct)%", "\(plan) · Claude/GPT \(claudePct)%")
        } else {
            detailText = plan
        }

        return UsageResult(
            limits: limits,
            fetchedAt: fetchedAt,
            plan: plan,
            detail: detailText,
            activity: nil
        )
    }

    // MARK: - Disk Cache

    private static var cacheFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".gemini/antigravity")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("quotabar_cache.json")
    }

    private static func saveDiskCache(data: Data, plan: String) {
        let envelope: [String: Any] = [
            "fetched_at": Date().timeIntervalSince1970,
            "plan": plan,
            "response": (try? JSONSerialization.jsonObject(with: data)) ?? [:]
        ]
        if let cacheData = try? JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted]) {
            try? cacheData.write(to: cacheFileURL, options: .atomic)
        }
    }

    static func loadDiskCache(language: AppLanguage) -> UsageResult? {
        guard
            let cacheData = try? Data(contentsOf: cacheFileURL),
            let envelope = try? JSONSerialization.jsonObject(with: cacheData) as? [String: Any],
            let responseObj = envelope["response"] as? [String: Any],
            let responseData = try? JSONSerialization.data(withJSONObject: responseObj),
            let timestamp = envelope["fetched_at"] as? Double
        else {
            return nil
        }
        let plan = (envelope["plan"] as? String) ?? "Google AI Pro"
        let fetchedAt = Date(timeIntervalSince1970: timestamp)
        var result = try? parseResponse(responseData, plan: plan, fetchedAt: fetchedAt, language: language)
        if result != nil {
            result?.activity = .offline
        }
        return result
    }
}

final class AntigravityTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.host == "127.0.0.1" || challenge.protectionSpace.host == "localhost",
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
