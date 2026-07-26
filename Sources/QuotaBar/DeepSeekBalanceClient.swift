import Foundation
import Security

enum DeepSeekCredentialStore {
    private static let service = "local.quotabar.deepseek"
    private static let account = "api-key"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else {
            return nil
        }
        return key
    }

    static func save(_ key: String) throws {
        let normalized = normalizedAPIKey(key)
        guard !normalized.isEmpty, let data = normalized.data(using: .utf8) else {
            throw DeepSeekBalanceClient.ClientError.missingCredential
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw DeepSeekBalanceClient.ClientError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw DeepSeekBalanceClient.ClientError.keychain(status)
        }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeepSeekBalanceClient.ClientError.keychain(status)
        }
    }

    static func normalizedAPIKey(_ value: String) -> String {
        var key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.lowercased().hasPrefix("bearer ") {
            key = String(key.dropFirst(7))
        }
        key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if
            key.count >= 2,
            let first = key.first,
            let last = key.last,
            (first == "\"" && last == "\"") || (first == "'" && last == "'")
        {
            key.removeFirst()
            key.removeLast()
        }
        return key.components(separatedBy: .whitespacesAndNewlines).joined()
    }
}

actor DeepSeekBalanceClient {
    struct BalanceResult: Sendable {
        let balances: [AccountBalance]
        let isAvailable: Bool
        let fetchedAt: Date
    }

    enum ClientError: LocalizedError {
        case missingCredential
        case invalidCredential
        case invalidResponse
        case http(Int)
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .missingCredential:
                "DeepSeek API Key is not configured."
            case .invalidCredential:
                "DeepSeek API Key is invalid."
            case .invalidResponse:
                "DeepSeek returned an unreadable balance response."
            case .http(let status):
                "DeepSeek balance service returned HTTP \(status)."
            case .keychain(let status):
                "macOS Keychain error \(status)."
            }
        }
    }

    private let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!
    private var lastResult: BalanceResult?

    func fetchIfNeeded(force: Bool) async throws -> BalanceResult {
        if
            !force,
            let lastResult,
            Date().timeIntervalSince(lastResult.fetchedAt) < 300
        {
            return lastResult
        }
        guard let key = DeepSeekCredentialStore.load() else {
            throw ClientError.missingCredential
        }
        return try await fetch(apiKey: key)
    }

    func validate(apiKey: String) async throws -> BalanceResult {
        let key = DeepSeekCredentialStore.normalizedAPIKey(apiKey)
        guard !key.isEmpty else { throw ClientError.missingCredential }
        return try await fetch(apiKey: key)
    }

    private func fetch(apiKey key: String) async throws -> BalanceResult {
        var request = URLRequest(url: balanceURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaBar/1.2.4 macOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw ClientError.invalidCredential }
        guard (200..<300).contains(status) else { throw ClientError.http(status) }

        let result = try Self.parseResponse(data, fetchedAt: Date())
        lastResult = result
        return result
    }

    static func parseResponse(
        _ data: Data,
        fetchedAt: Date = Date()
    ) throws -> BalanceResult {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = object["balance_infos"] as? [[String: Any]]
        else {
            throw ClientError.invalidResponse
        }

        let locale = Locale(identifier: "en_US_POSIX")
        let balances = rows.compactMap { row -> AccountBalance? in
            guard
                let currency = row["currency"] as? String,
                let totalText = row["total_balance"] as? String,
                let total = Decimal(string: totalText, locale: locale)
            else {
                return nil
            }
            let granted = (row["granted_balance"] as? String)
                .flatMap { Decimal(string: $0, locale: locale) } ?? 0
            let toppedUp = (row["topped_up_balance"] as? String)
                .flatMap { Decimal(string: $0, locale: locale) } ?? 0
            return AccountBalance(
                currency: currency,
                total: total,
                granted: granted,
                toppedUp: toppedUp
            )
        }
        guard !balances.isEmpty else { throw ClientError.invalidResponse }

        return BalanceResult(
            balances: balances,
            isAvailable: object["is_available"] as? Bool ?? true,
            fetchedAt: fetchedAt
        )
    }
}
