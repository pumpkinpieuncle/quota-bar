import Foundation
import Security

enum KimiAPICredentialStore {
    private static let service = "local.quotabar.kimi-open-platform"
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
            throw KimiBalanceClient.ClientError.missingCredential
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
                throw KimiBalanceClient.ClientError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw KimiBalanceClient.ClientError.keychain(status)
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
            throw KimiBalanceClient.ClientError.keychain(status)
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

actor KimiBalanceClient {
    struct BalanceResult: Sendable {
        let balance: AccountBalance
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
                "Kimi Open Platform API key is not configured."
            case .invalidCredential:
                "Kimi Open Platform API key is invalid."
            case .invalidResponse:
                "Kimi returned an unreadable balance response."
            case .http(let status):
                "Kimi balance service returned HTTP \(status)."
            case .keychain(let status):
                "macOS Keychain error \(status)."
            }
        }
    }

    private let balanceURL = URL(string: "https://api.moonshot.cn/v1/users/me/balance")!
    private var lastResult: BalanceResult?

    func fetchIfNeeded(force: Bool) async throws -> BalanceResult {
        if
            !force,
            let lastResult,
            Date().timeIntervalSince(lastResult.fetchedAt) < 300
        {
            return lastResult
        }
        guard let key = KimiAPICredentialStore.load() else {
            throw ClientError.missingCredential
        }
        return try await fetch(apiKey: key)
    }

    func validate(apiKey: String) async throws -> BalanceResult {
        let key = KimiAPICredentialStore.normalizedAPIKey(apiKey)
        guard !key.isEmpty else { throw ClientError.missingCredential }
        return try await fetch(apiKey: key)
    }

    private func fetch(apiKey key: String) async throws -> BalanceResult {
        var request = URLRequest(url: balanceURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaBar/1.2.1 macOS", forHTTPHeaderField: "User-Agent")

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
            let payload = object["data"] as? [String: Any],
            let available = decimal(payload["available_balance"]),
            let voucher = decimal(payload["voucher_balance"]),
            let cash = decimal(payload["cash_balance"])
        else {
            throw ClientError.invalidResponse
        }
        return BalanceResult(
            balance: AccountBalance(
                currency: "CNY",
                total: available,
                granted: voucher,
                toppedUp: cash
            ),
            fetchedAt: fetchedAt
        )
    }

    private static func decimal(_ value: Any?) -> Decimal? {
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let text = value as? String {
            return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
}
