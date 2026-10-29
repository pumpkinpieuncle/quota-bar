import Foundation

/// Reads the Claude.ai subscription quota (5-hour and weekly windows) from the
/// same usage endpoint Claude Code's `/usage` uses. It borrows the sign-in that
/// Claude Code keeps in the macOS Keychain and never refreshes it: rotating the
/// refresh token here could sign Claude Code out. Running `claude` once in a
/// terminal keeps the sign-in fresh.
actor ClaudeUsageClient {
    struct UsageResult: Sendable {
        let limits: [LimitWindow]
        let plan: String
        let fetchedAt: Date
    }

    enum ClientError: Error {
        /// No Claude Code sign-in, or one that was never completed.
        case loggedOut
        /// The saved access token is past its expiry.
        case expired
        /// The server rejected the token (401/403).
        case rejected
        case http(Int)
    }

    private struct Credential {
        let accessToken: String
        let expiresAt: Date?
        let subscriptionType: String?
    }

    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var lastRemoteFetch: Date?
    private var lastResult: UsageResult?

    func fetchIfNeeded(force: Bool) async throws -> UsageResult {
        if
            !force,
            let lastRemoteFetch,
            let lastResult,
            Date().timeIntervalSince(lastRemoteFetch) < 300
        {
            return lastResult
        }

        guard let credential = loadCredential() else { throw ClientError.loggedOut }
        if let expiresAt = credential.expiresAt, expiresAt < Date() {
            throw ClientError.expired
        }

        var request = URLRequest(url: usageURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaBar/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw ClientError.rejected }
        guard (200..<300).contains(status) else { throw ClientError.http(status) }

        let result = UsageResult(
            limits: Self.parseUsage(data),
            plan: credential.subscriptionType.map { $0.capitalized } ?? "",
            fetchedAt: Date()
        )
        lastRemoteFetch = result.fetchedAt
        lastResult = result
        return result
    }

    static func parseUsage(_ data: Data) -> [LimitWindow] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var limits: [LimitWindow] = []
        if let fiveHour = object["five_hour"] as? [String: Any] {
            limits.append(window(fiveHour, id: "five-hour", label: "5 小时", minutes: 300))
        }
        if let sevenDay = object["seven_day"] as? [String: Any] {
            limits.append(window(sevenDay, id: "seven-day", label: "7 天", minutes: 10_080))
        }
        return limits
    }

    private static func window(
        _ object: [String: Any],
        id: String,
        label: String,
        minutes: Int
    ) -> LimitWindow {
        let used = LocalCollectors.number(object["utilization"]) ?? 0
        let reset = (object["resets_at"] as? String).flatMap(parseISO8601)
        return LimitWindow(
            id: id,
            label: label,
            remainingPercent: 100 - used,
            resetAt: reset,
            windowMinutes: minutes
        )
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func loadCredential() -> Credential? {
        // Claude Code stores its sign-in in the Keychain on macOS and falls back
        // to ~/.claude/.credentials.json elsewhere. Reading through
        // /usr/bin/security matches how Claude Code itself accesses the item,
        // so it does not raise a Keychain prompt for Quota Bar.
        let data = keychainCredentialData()
            ?? (try? Data(contentsOf: FileManager.default.homeDirectoryForCurrentUser
                .appending(path: ".claude/.credentials.json")))
        guard
            let data,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = object["claudeAiOauth"] as? [String: Any],
            let accessToken = oauth["accessToken"] as? String,
            !accessToken.isEmpty
        else {
            return nil
        }
        // An expiresAt of 0 is what Claude Code leaves behind after signing out.
        let expiresAtMillis = LocalCollectors.number(oauth["expiresAt"])
        if expiresAtMillis == 0 { return nil }
        return Credential(
            accessToken: accessToken,
            expiresAt: expiresAtMillis.map { Date(timeIntervalSince1970: $0 / 1_000) },
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }

    private func keychainCredentialData() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let trimmed = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Data(trimmed.utf8)
    }
}
