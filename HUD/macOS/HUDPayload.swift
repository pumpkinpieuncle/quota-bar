import Foundation

/// One quota window as the HUD sees it.
public struct HUDLimit: Codable, Sendable, Equatable {
    public var label: String
    public var remainingPercent: Int
    public var resetAt: Date?
    public var resetText: String?

    public init(
        label: String,
        remainingPercent: Int,
        resetAt: Date? = nil,
        resetText: String? = nil
    ) {
        self.label = label
        self.remainingPercent = remainingPercent
        self.resetAt = resetAt
        self.resetText = resetText
    }
}

/// One service row. `headline` is already formatted (`"62%"`, `"¥110"`, `"—"`)
/// so a display client never has to know about balances versus percentages.
public struct HUDProvider: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var accent: String
    public var state: String
    public var stateLabel: String
    public var isActive: Bool
    public var headline: String
    public var percent: Int?
    public var detail: String
    public var limits: [HUDLimit]
    public var updatedAt: Date?

    public init(
        id: String,
        title: String,
        accent: String,
        state: String,
        stateLabel: String,
        isActive: Bool,
        headline: String,
        percent: Int?,
        detail: String,
        limits: [HUDLimit],
        updatedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.accent = accent
        self.state = state
        self.stateLabel = stateLabel
        self.isActive = isActive
        self.headline = headline
        self.percent = percent
        self.detail = detail
        self.limits = limits
        self.updatedAt = updatedAt
    }
}

/// Everything a phone or an ESP32 needs for one screen refresh.
public struct HUDPayload: Codable, Sendable, Equatable {
    public var app: String
    public var version: String
    public var host: String
    public var generatedAt: Date
    public var language: String
    public var quotaWindow: String
    public var lowQuotaThreshold: Int
    public var providers: [HUDProvider]

    public init(
        app: String = "Quota Bar",
        version: String,
        host: String,
        generatedAt: Date = Date(),
        language: String,
        quotaWindow: String,
        lowQuotaThreshold: Int,
        providers: [HUDProvider]
    ) {
        self.app = app
        self.version = version
        self.host = host
        self.generatedAt = generatedAt
        self.language = language
        self.quotaWindow = quotaWindow
        self.lowQuotaThreshold = lowQuotaThreshold
        self.providers = providers
    }

    public static func empty(version: String, host: String) -> HUDPayload {
        HUDPayload(
            version: version,
            host: host,
            language: "en",
            quotaWindow: "fiveHour",
            lowQuotaThreshold: 0,
            providers: []
        )
    }

    public func jsonData(pretty: Bool = false) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.withoutEscapingSlashes]
        }
        return (try? encoder.encode(self)) ?? Data("{}".utf8)
    }

    /// Line-oriented form for microcontrollers: no JSON parser required.
    ///
    ///     # ts=1785034681 window=5h low=10
    ///     Codex|62|working|Working|5 小时
    public func plainText() -> String {
        var lines = [
            "# ts=\(Int(generatedAt.timeIntervalSince1970))"
                + " window=\(quotaWindow)"
                + " low=\(lowQuotaThreshold)"
                + " count=\(providers.count)"
        ]
        for provider in providers {
            lines.append(
                [
                    provider.title,
                    provider.percent.map(String.init) ?? "",
                    provider.state,
                    provider.headline,
                    provider.limits.first?.resetText ?? ""
                ]
                .map { $0.replacingOccurrences(of: "|", with: "/") }
                .joined(separator: "|")
            )
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
