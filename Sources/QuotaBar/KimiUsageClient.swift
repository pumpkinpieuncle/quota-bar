import Darwin
import Foundation

actor KimiUsageClient {
    struct UsageResult: Sendable {
        let limits: [LimitWindow]
        let fetchedAt: Date
    }

    private let fm = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let clientID = "17e5f671-d194-4dfb-9706-5516cb48c098"
    private let authURL = URL(string: "https://auth.kimi.com/api/oauth/token")!
    private let usageURL = URL(string: "https://api.kimi.com/coding/v1/usages")!
    private var lastRemoteFetch: Date?
    private var lastResult: UsageResult?

    func fetchIfNeeded(
        force: Bool,
        allowRemote: Bool,
        kimiIsWorking: Bool
    ) async throws -> UsageResult {
        if
            !force,
            let lastRemoteFetch,
            let lastResult,
            Date().timeIntervalSince(lastRemoteFetch) < 300
        {
            return lastResult
        }

        if !force, !allowRemote {
            if let lastResult { return lastResult }
            if let cached = loadCachedUsage() { return cached }
            throw CollectorError.invalidCredential
        }

        let credentialURL = home.appending(path: ".kimi-code/credentials/kimi-code.json")
        guard
            let credentialData = try? Data(contentsOf: credentialURL),
            var credential = try? JSONSerialization.jsonObject(with: credentialData) as? [String: Any]
        else {
            if let cached = loadCachedUsage() { return cached }
            throw CollectorError.invalidCredential
        }

        var accessToken = credential["access_token"] as? String ?? ""
        let expiresAt = LocalCollectors.number(credential["expires_at"]) ?? 0
        if accessToken.isEmpty || expiresAt < Date().timeIntervalSince1970 + 90 {
            guard !kimiIsWorking else {
                if let cached = loadCachedUsage() { return cached }
                throw CollectorError.invalidCredential
            }
            credential = try await refreshCredential(credential, saveTo: credentialURL)
            accessToken = credential["access_token"] as? String ?? ""
        }
        guard !accessToken.isEmpty else { throw CollectorError.invalidCredential }

        var request = URLRequest(url: usageURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyKimiHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw CollectorError.http(status) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CollectorError.invalidCredential
        }

        let result = UsageResult(limits: parseUsage(object), fetchedAt: Date())
        lastRemoteFetch = Date()
        lastResult = result
        try? saveUsageCache(object, at: result.fetchedAt)
        return result
    }

    private func refreshCredential(
        _ old: [String: Any],
        saveTo url: URL
    ) async throws -> [String: Any] {
        guard let refreshToken = old["refresh_token"] as? String, !refreshToken.isEmpty else {
            throw CollectorError.invalidCredential
        }

        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        applyKimiHeaders(to: &request)
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

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw CollectorError.http(status) }
        guard var fresh = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CollectorError.invalidCredential
        }

        let expiresIn = LocalCollectors.number(fresh["expires_in"]) ?? 0
        fresh["expires_at"] = Date().timeIntervalSince1970 + expiresIn
        if fresh["refresh_token"] == nil {
            fresh["refresh_token"] = refreshToken
        }
        if fresh["scope"] == nil { fresh["scope"] = old["scope"] }
        if fresh["token_type"] == nil { fresh["token_type"] = old["token_type"] }

        let encoded = try JSONSerialization.data(
            withJSONObject: fresh,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try encoded.write(to: url, options: .atomic)
        chmod(url.path, S_IRUSR | S_IWUSR)
        return fresh
    }

    private func parseUsage(_ object: [String: Any]) -> [LimitWindow] {
        var rows: [LimitWindow] = []

        if let usage = object["usage"] as? [String: Any],
           let row = usageWindow(usage, fallbackLabel: "7 天", id: "summary") {
            rows.append(row)
        }

        if let limits = object["limits"] as? [[String: Any]] {
            for (index, item) in limits.enumerated() {
                let detail = (item["detail"] as? [String: Any]) ?? item
                let window = item["window"] as? [String: Any]
                let label = usageLabel(item: item, detail: detail, window: window, index: index)
                if let row = usageWindow(detail, fallbackLabel: label, id: "limit-\(index)") {
                    rows.append(row)
                }
            }
        }

        var seen = Set<String>()
        return rows.filter { row in
            let key = "\(row.label)-\(Int(row.clampedRemaining.rounded()))"
            return seen.insert(key).inserted
        }.prefix(2).map { $0 }
    }

    private func usageWindow(
        _ object: [String: Any],
        fallbackLabel: String,
        id: String
    ) -> LimitWindow? {
        guard let limit = LocalCollectors.number(object["limit"]), limit > 0 else { return nil }
        let used: Double
        if let value = LocalCollectors.number(object["used"]) {
            used = value
        } else if let remaining = LocalCollectors.number(object["remaining"]) {
            used = limit - remaining
        } else {
            return nil
        }

        let label = (object["name"] as? String)
            ?? (object["title"] as? String)
            ?? fallbackLabel
        let resetAt = parseReset(object)
        return LimitWindow(
            id: id,
            label: translatedLabel(label),
            remainingPercent: (limit - used) / limit * 100,
            resetAt: resetAt
        )
    }

    private func usageLabel(
        item: [String: Any],
        detail: [String: Any],
        window: [String: Any]?,
        index: Int
    ) -> String {
        for key in ["name", "title", "scope"] {
            if let value = item[key] as? String ?? detail[key] as? String {
                return translatedLabel(value)
            }
        }
        let duration = Int(
            LocalCollectors.number(window?["duration"])
                ?? LocalCollectors.number(item["duration"])
                ?? LocalCollectors.number(detail["duration"])
                ?? 0
        )
        let unit = (
            window?["timeUnit"] as? String
                ?? item["timeUnit"] as? String
                ?? detail["timeUnit"] as? String
                ?? ""
        ).uppercased()
        if unit.contains("MINUTE") { return LocalCollectors.windowLabel(minutes: duration) }
        if unit.contains("HOUR") { return "\(duration) 小时" }
        if unit.contains("DAY") { return "\(duration) 天" }
        return "额度 \(index + 1)"
    }

    private func parseReset(_ object: [String: Any]) -> Date? {
        for key in ["reset_at", "resetAt", "reset_time", "resetTime"] {
            if let value = object[key] {
                if let epoch = LocalCollectors.number(value), epoch > 0 {
                    return Date(timeIntervalSince1970: epoch)
                }
                if let string = value as? String {
                    if let date = ISO8601DateFormatter().date(from: string) {
                        return date
                    }
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: string) { return date }
                }
            }
        }
        for key in ["reset_in", "resetIn", "ttl"] {
            if let seconds = LocalCollectors.number(object[key]), seconds > 0 {
                return Date().addingTimeInterval(seconds)
            }
        }
        return nil
    }

    private func translatedLabel(_ label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("week") { return "7 天" }
        if lower.contains("5h") || lower.contains("5 h") { return "5 小时" }
        if lower.contains("day") { return label.replacingOccurrences(of: "days", with: "天") }
        return label
    }

    private func applyKimiHeaders(to request: inout URLRequest) {
        request.setValue("kimi_cli", forHTTPHeaderField: "X-Msh-Platform")
        request.setValue("QuotaBar/1.2.3", forHTTPHeaderField: "X-Msh-Version")
        if let deviceID = try? String(
            contentsOf: home.appending(path: ".kimi-code/device_id"),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines), !deviceID.isEmpty {
            request.setValue(deviceID, forHTTPHeaderField: "X-Msh-Device-Id")
        }
    }

    private func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(
            CharacterSet(charactersIn: "&=+")
        )) ?? value
    }

    private func cacheURL() -> URL {
        home.appending(path: ".quotabar/kimi-usage.json")
    }

    private func saveUsageCache(_ object: [String: Any], at date: Date) throws {
        var payload = object
        payload["_quotabar_fetched_at"] = date.timeIntervalSince1970
        let directory = cacheURL().deletingLastPathComponent()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: cacheURL(), options: .atomic)
        chmod(cacheURL().path, S_IRUSR | S_IWUSR)
    }

    private func loadCachedUsage() -> UsageResult? {
        guard
            let data = try? Data(contentsOf: cacheURL()),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        let date = LocalCollectors.number(object["_quotabar_fetched_at"])
            .map { Date(timeIntervalSince1970: $0) }
            ?? .distantPast
        let result = UsageResult(limits: parseUsage(object), fetchedAt: date)
        lastResult = result
        return result
    }
}
