import Foundation
import LocalAuthentication
import Security

enum DeepSeekCredentialSource: String, Sendable, CaseIterable {
    case keychain = "Keychain"
    case environment = "Environment"
    case harness = "DeepSeek Harness"
    case config = "Config"
}

struct DeepSeekCredentialInfo: Sendable, Equatable {
    let key: String
    let source: DeepSeekCredentialSource
}

enum DeepSeekCredentialStore {
    private static let service = "local.quotabar.deepseek"
    private static let account = "api-key"

    /// Remembers the first successful lookup for the lifetime of the process.
    private static let memo = CredentialMemo()

    private final class CredentialMemo: @unchecked Sendable {
        private let lock = NSLock()
        /// Outer `nil` means "not looked up yet", inner `nil` means "no key".
        private var value: DeepSeekCredentialInfo??

        func cached() -> DeepSeekCredentialInfo?? {
            lock.withLock { value }
        }

        func store(_ newValue: DeepSeekCredentialInfo?) {
            lock.withLock { value = newValue }
        }

        func clear() {
            lock.withLock { value = nil }
        }
    }

    static func loadCredentialInfo() -> DeepSeekCredentialInfo? {
        if let cached = memo.cached() { return cached }
        let info = resolveCredentialInfo()
        memo.store(info)
        return info
    }

    static func load() -> String? {
        loadCredentialInfo()?.key
    }

    static func hasCredential() -> Bool {
        load() != nil
    }

    private static func resolveCredentialInfo() -> DeepSeekCredentialInfo? {
        // 1. Manually saved in Keychain
        if let key = readFromKeychain(), !key.isEmpty {
            return DeepSeekCredentialInfo(key: key, source: .keychain)
        }
        // 2. Environment variables
        if let envKey = readFromEnvironment(), !envKey.isEmpty {
            return DeepSeekCredentialInfo(key: envKey, source: .environment)
        }
        // 3. DeepSeek Harness desktop / CLI (~/.dsh)
        if let harnessKey = readFromDeepSeekHarness(), !harnessKey.isEmpty {
            return DeepSeekCredentialInfo(key: harnessKey, source: .harness)
        }
        // 4. Local configs (~/.deepseek)
        if let configKey = readFromLocalConfigs(), !configKey.isEmpty {
            return DeepSeekCredentialInfo(key: configKey, source: .config)
        }
        return nil
    }

    private static func readFromEnvironment() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let key = env["DEEPSEEK_API_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalizedAPIKey(key)
        }
        if let key = env["DEEPSEEK_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalizedAPIKey(key)
        }
        return nil
    }

    private static func readFromDeepSeekHarness() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appending(path: ".dsh/.credentials.yaml"),
            home.appending(path: ".dsh/credentials.yaml"),
            home.appending(path: ".dsh/.credentials.yml"),
            home.appending(path: ".dsh/credentials.yml"),
            home.appending(path: ".dsh/.credentials.json"),
            home.appending(path: ".dsh/credentials.json"),
            home.appending(path: ".dsh/profiles/desktop/cordis.patch.yml")
        ]
        for url in candidates {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let key = extractAPIKey(fromYamlOrText: content) {
                return key
            }
        }
        return nil
    }

    private static func readFromLocalConfigs() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appending(path: ".deepseek/credentials.json"),
            home.appending(path: ".deepseek/config.json"),
            home.appending(path: ".config/deepseek/credentials.json"),
            home.appending(path: ".config/deepseek/config.json")
        ]
        for url in candidates {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let key = extractAPIKey(fromYamlOrText: content) {
                return key
            }
        }
        return nil
    }

    static func extractAPIKey(fromYamlOrText content: String) -> String? {
        if content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"),
           let data = content.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let key = extractAPIKey(fromJSONObject: obj) {
                return key
            }
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let separatorIndex = trimmed.firstIndex(of: ":") ?? trimmed.firstIndex(of: "=")
            guard let sep = separatorIndex else { continue }

            let keyPart = trimmed[..<sep].trimmingCharacters(in: .whitespaces)
            let valPart = trimmed[trimmed.index(after: sep)...].trimmingCharacters(in: .whitespaces)

            let lowerKey = keyPart.lowercased()
            if lowerKey == "deepseek_api_key" || lowerKey == "deepseek_key" || lowerKey == "api_key" || lowerKey == "apikey" || lowerKey == "key" {
                let normalized = normalizedAPIKey(valPart)
                if !normalized.isEmpty && normalized != "null" && normalized != "~" {
                    return normalized
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: "sk-[A-Za-z0-9_-]{20,}") {
            let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
            if let match = regex.firstMatch(in: content, range: nsRange),
               let range = Range(match.range, in: content) {
                return normalizedAPIKey(String(content[range]))
            }
        }

        return nil
    }

    private static func extractAPIKey(fromJSONObject dict: [String: Any]) -> String? {
        if let refs = dict["refs"] as? [String: Any] {
            if let key = refs["DEEPSEEK_API_KEY"] as? String ?? refs["api_key"] as? String {
                let norm = normalizedAPIKey(key)
                if !norm.isEmpty { return norm }
            }
        }
        for candidate in ["DEEPSEEK_API_KEY", "deepseek_api_key", "api_key", "apiKey", "key", "token"] {
            if let str = dict[candidate] as? String {
                let norm = normalizedAPIKey(str)
                if !norm.isEmpty { return norm }
            }
        }
        return nil
    }

    private static func readFromKeychain() -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
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
        memo.store(DeepSeekCredentialInfo(key: normalized, source: .keychain))
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
        memo.clear()
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
        request.setValue(AppVersion.userAgent, forHTTPHeaderField: "User-Agent")

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
