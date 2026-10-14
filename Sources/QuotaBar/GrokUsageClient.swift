import Darwin
import Foundation

actor GrokUsageClient {
    struct UsageResult: Sendable {
        let limits: [LimitWindow]
        let balances: [AccountBalance]
        let plan: String
        let fetchedAt: Date

        init(
            limits: [LimitWindow],
            balances: [AccountBalance] = [],
            plan: String = "",
            fetchedAt: Date
        ) {
            self.limits = limits
            self.balances = balances
            self.plan = plan
            self.fetchedAt = fetchedAt
        }
    }

    private let fm = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let authURL = URL(string: "https://auth.x.ai/oauth2/token")!
    private let billingURL = URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!
    private var lastRemoteFetch: Date?
    private var lastResult: UsageResult?

    private var authFileURL: URL {
        home.appending(path: ".grok/auth.json")
    }

    private var logsFileURL: URL {
        home.appending(path: ".grok/logs/unified.jsonl")
    }

    private var cacheFileURL: URL {
        home.appending(path: ".quotabar/grok-usage.json")
    }

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
            return lastResult
        }

        // 1. Try remote fetch using Grok CLI authentication
        if let remoteResult = await fetchFromRemote(language: language) {
            lastRemoteFetch = Date()
            lastResult = remoteResult
            try? saveCache(remoteResult)
            return remoteResult
        }

        // 2. Fallback to latest local unified.jsonl billing logs
        if let logResult = parseFromLogs(language: language) {
            lastResult = logResult
            return logResult
        }

        // 3. Fallback to disk cache
        if let cached = loadCache(language: language) {
            lastResult = cached
            return cached
        }

        if let lastResult {
            return lastResult
        }

        throw CollectorError.invalidCredential
    }

    private func fetchFromRemote(language: AppLanguage) async -> UsageResult? {
        guard let authData = try? Data(contentsOf: authFileURL),
              var authDict = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let (authKey, firstEntry) = authDict.first(where: { $0.key.contains("auth.x.ai") || $0.key.contains("x.ai") }) ?? authDict.first,
              var entry = firstEntry as? [String: Any]
        else {
            return nil
        }

        var accessToken = entry["key"] as? String ?? ""
        let refreshToken = entry["refresh_token"] as? String ?? ""
        let clientID = entry["oidc_client_id"] as? String ?? "b1a00492-073a-47ea-816f-4c329264a828"
        let expiresAtStr = entry["expires_at"] as? String ?? ""
        let expiresAt = parseISO8601(expiresAtStr)

        // Auto-refresh token if expired or about to expire in 120s
        if let expiresAt, expiresAt.timeIntervalSinceNow < 120, !refreshToken.isEmpty {
            if let refreshed = await refreshCredential(refreshToken: refreshToken, clientID: clientID) {
                if let newAccess = refreshed["access_token"] as? String {
                    accessToken = newAccess
                    entry["key"] = newAccess
                    if let newRefresh = refreshed["refresh_token"] as? String {
                        entry["refresh_token"] = newRefresh
                    }
                    if let expiresIn = refreshed["expires_in"] as? Double {
                        let newExp = Date().addingTimeInterval(expiresIn)
                        let iso = ISO8601DateFormatter()
                        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        entry["expires_at"] = iso.string(from: newExp)
                    }
                    authDict[authKey] = entry
                    if let updatedData = try? JSONSerialization.data(withJSONObject: authDict, options: [.prettyPrinted, .sortedKeys]) {
                        try? updatedData.write(to: authFileURL, options: .atomic)
                    }
                }
            }
        }

        guard !accessToken.isEmpty else { return nil }

        var request = URLRequest(url: billingURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("xai-grok-cli", forHTTPHeaderField: "X-XAI-Token-Auth")
        request.setValue("grok-cli/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse
        else {
            return nil
        }

        if http.statusCode == 401 && !refreshToken.isEmpty {
            if let refreshed = await refreshCredential(refreshToken: refreshToken, clientID: clientID),
               let newAccess = refreshed["access_token"] as? String {
                accessToken = newAccess
                entry["key"] = newAccess
                if let newRefresh = refreshed["refresh_token"] as? String {
                    entry["refresh_token"] = newRefresh
                }
                authDict[authKey] = entry
                if let updatedData = try? JSONSerialization.data(withJSONObject: authDict, options: [.prettyPrinted, .sortedKeys]) {
                    try? updatedData.write(to: authFileURL, options: .atomic)
                }

                var retryReq = URLRequest(url: billingURL)
                retryReq.timeoutInterval = 10
                retryReq.setValue("Bearer \(newAccess)", forHTTPHeaderField: "Authorization")
                retryReq.setValue("application/json", forHTTPHeaderField: "Accept")
                retryReq.setValue("xai-grok-cli", forHTTPHeaderField: "X-XAI-Token-Auth")
                retryReq.setValue("grok-cli/1.0", forHTTPHeaderField: "User-Agent")

                if let (retryData, retryResp) = try? await URLSession.shared.data(for: retryReq),
                   let retryHttp = retryResp as? HTTPURLResponse,
                   (200..<300).contains(retryHttp.statusCode) {
                    return parseBillingJSON(retryData, language: language, entry: entry)
                }
            }
            return nil
        }

        guard (200..<300).contains(http.statusCode) else {
            return nil
        }

        return parseBillingJSON(data, language: language, entry: entry)
    }

    private func refreshCredential(refreshToken: String, clientID: String) async -> [String: Any]? {
        guard !refreshToken.isEmpty else { return nil }
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let form = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = form
            .map { key, value in "\(urlEncode(key))=\(urlEncode(value))" }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    private func parseBillingJSON(_ data: Data, language: AppLanguage, entry: [String: Any]?) -> UsageResult? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = root["config"] as? [String: Any]
        else {
            return nil
        }

        var limits: [LimitWindow] = []
        var balances: [AccountBalance] = []

        let usagePct = LocalCollectors.number(config["creditUsagePercent"]) ?? 0.0
        let remainingPct = max(0.0, min(100.0, 100.0 - usagePct))

        var resetDate: Date? = nil
        var windowMinutes: Int = 10_080
        var windowLabel = language.text("7 天", "7 days")

        if let period = config["currentPeriod"] as? [String: Any] {
            if let endStr = period["end"] as? String {
                resetDate = parseISO8601(endStr)
            }
            if let pType = period["type"] as? String {
                if pType.contains("WEEKLY") {
                    windowMinutes = 10_080
                    windowLabel = language.text("7 天", "7 days")
                } else if pType.contains("MONTHLY") {
                    windowMinutes = 43_200
                    windowLabel = language.text("月额度", "Monthly")
                }
            }
        }

        limits.append(
            LimitWindow(
                id: "weekly",
                label: windowLabel,
                remainingPercent: remainingPct,
                resetAt: resetDate,
                windowMinutes: windowMinutes
            )
        )

        if let prepaid = config["prepaidBalance"] as? [String: Any],
           let val = LocalCollectors.number(prepaid["val"]), val > 0 {
            balances.append(
                AccountBalance(
                    currency: "USD",
                    total: Decimal(val),
                    granted: 0,
                    toppedUp: Decimal(val)
                )
            )
        }

        let plan = detectPlanName(entry: entry)

        return UsageResult(
            limits: limits,
            balances: balances,
            plan: plan,
            fetchedAt: Date()
        )
    }

    private func detectPlanName(entry: [String: Any]?) -> String {
        // 1. Check unified.jsonl for explicit subscriptionTier
        if let logData = try? Data(contentsOf: logsFileURL),
           let logText = String(data: logData, encoding: .utf8) {
            let lines = logText.components(separatedBy: "\n")
            for line in lines.reversed() {
                if line.contains("billing: fetched credits config"),
                   let data = line.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ctx = obj["ctx"] as? [String: Any],
                   let tier = ctx["subscriptionTier"] as? String, !tier.isEmpty {
                    return tier
                }
            }
        }

        return "SuperGrok"
    }

    private func parseFromLogs(language: AppLanguage) -> UsageResult? {
        guard let logData = try? Data(contentsOf: logsFileURL),
              let logText = String(data: logData, encoding: .utf8)
        else {
            return nil
        }

        let lines = logText.components(separatedBy: "\n")
        for line in lines.reversed() {
            guard line.contains("billing: fetched credits config") else { continue }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ctx = obj["ctx"] as? [String: Any],
                  let cfg = ctx["config"] as? [String: Any]
            else {
                continue
            }

            let usagePct = LocalCollectors.number(cfg["creditUsagePercent"]) ?? 0.0
            let remainingPct = max(0.0, min(100.0, 100.0 - usagePct))

            var resetDate: Date? = nil
            if let period = cfg["currentPeriod"] as? [String: Any],
               let endStr = period["end"] as? String {
                resetDate = parseISO8601(endStr)
            }

            let plan = (ctx["subscriptionTier"] as? String) ?? "SuperGrok"
            let windowLabel = language.text("7 天", "7 days")

            let limit = LimitWindow(
                id: "weekly",
                label: windowLabel,
                remainingPercent: remainingPct,
                resetAt: resetDate,
                windowMinutes: 10_080
            )

            let fetchedAt = (obj["ts"] as? String).flatMap(parseISO8601) ?? Date()

            return UsageResult(
                limits: [limit],
                balances: [],
                plan: plan,
                fetchedAt: fetchedAt
            )
        }
        return nil
    }

    private func saveCache(_ result: UsageResult) throws {
        let dir = cacheFileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        var dict: [String: Any] = [
            "plan": result.plan,
            "fetchedAt": result.fetchedAt.timeIntervalSince1970
        ]
        if let primary = result.limits.first {
            dict["remainingPercent"] = primary.remainingPercent
            dict["label"] = primary.label
            dict["windowMinutes"] = primary.effectiveMinutes
            if let reset = primary.resetAt {
                dict["resetAt"] = reset.timeIntervalSince1970
            }
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        try data.write(to: cacheFileURL, options: .atomic)
    }

    private func loadCache(language: AppLanguage) -> UsageResult? {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let remPct = LocalCollectors.number(json["remainingPercent"]),
              let fetchedTime = LocalCollectors.number(json["fetchedAt"])
        else {
            return nil
        }

        let plan = (json["plan"] as? String) ?? "SuperGrok"
        let fetchedAt = Date(timeIntervalSince1970: fetchedTime)
        let resetAt = LocalCollectors.number(json["resetAt"]).map { Date(timeIntervalSince1970: $0) }
        let windowMinutes = (json["windowMinutes"] as? Int) ?? 10_080
        let label = (json["label"] as? String) ?? language.text("7 天", "7 days")

        let limit = LimitWindow(
            id: "weekly",
            label: label,
            remainingPercent: remPct,
            resetAt: resetAt,
            windowMinutes: windowMinutes
        )

        return UsageResult(
            limits: [limit],
            balances: [],
            plan: plan,
            fetchedAt: fetchedAt
        )
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: string) {
            return date
        }

        let formatterBasic = ISO8601DateFormatter()
        formatterBasic.formatOptions = [.withInternetDateTime]
        if let date = formatterBasic.date(from: string) {
            return date
        }

        let customFormatter = DateFormatter()
        customFormatter.locale = Locale(identifier: "en_US_POSIX")
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        return customFormatter.date(from: string)
    }

    private func urlEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}
