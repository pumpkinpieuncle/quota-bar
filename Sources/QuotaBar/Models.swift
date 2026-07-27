import Foundation

enum ProviderID: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude
    case kimi
    case deepseek
    case grok
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .kimi: "Kimi"
        case .deepseek: "DeepSeek"
        case .grok: "Grok"
        case .gemini: "Gemini"
        }
    }

    /// SF Symbol fallback used wherever a vector brand mark cannot be drawn
    /// (menus, tooltips, accessibility descriptions).
    var symbol: String {
        switch self {
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .claude: "sparkles"
        case .kimi: "moon.stars.fill"
        case .deepseek: "water.waves"
        case .grok: "xmark.seal"
        case .gemini: "sparkle"
        }
    }

    /// Accent colour as a hex string so the panel, the compact bar and the HUD
    /// payload all describe a provider with the same tint.
    var accentHex: String {
        switch self {
        case .codex: "#5FD4AB"
        case .claude: "#F09C63"
        case .kimi: "#8CA8FF"
        case .deepseek: "#59C2F5"
        case .grok: "#C7D2E8"
        case .gemini: "#8AB4F8"
        }
    }

    /// Providers that are only shown once the user opts in, either because they
    /// need a credential or because they are usually not installed.
    static let optInByDefault: Set<ProviderID> = [.deepseek, .grok, .gemini]
}

enum ActivityState: String, Sendable {
    case waitingApproval
    case working
    case thinking
    case idle
    case offline
    case needsAttention
    case connected

    func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.waitingApproval, .chinese): "等你审批"
        case (.working, .chinese): "当牛马中"
        case (.thinking, .chinese): "思考中"
        case (.idle, .chinese): "摸鱼中"
        case (.offline, .chinese): "未运行"
        case (.needsAttention, .chinese): "需处理"
        case (.connected, .chinese): "已连接"
        case (.waitingApproval, .english): "Awaiting approval"
        case (.working, .english): "Working"
        case (.thinking, .english): "Thinking"
        case (.idle, .english): "Idle"
        case (.offline, .english): "Not running"
        case (.needsAttention, .english): "Needs attention"
        case (.connected, .english): "Connected"
        }
    }

    var isActive: Bool {
        self == .waitingApproval || self == .working || self == .thinking
    }
}

struct AccountBalance: Equatable, Sendable {
    let currency: String
    let total: Decimal
    let granted: Decimal
    let toppedUp: Decimal

    var symbol: String {
        switch currency.uppercased() {
        case "CNY": "¥"
        case "USD": "$"
        case "EUR": "€"
        default: "\(currency.uppercased()) "
        }
    }

    var compactText: String {
        "\(symbol)\(NSDecimalNumber(decimal: total).stringValue)"
    }
}

struct LimitWindow: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let remainingPercent: Double
    let resetAt: Date?
    /// Length of the window in minutes when the source reports it. Providers
    /// hand back windows in whatever order they like, so this is what decides
    /// which one is the 5-hour and which one is the weekly quota.
    var windowMinutes: Int?

    init(
        id: String,
        label: String,
        remainingPercent: Double,
        resetAt: Date?,
        windowMinutes: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.remainingPercent = remainingPercent
        self.resetAt = resetAt
        self.windowMinutes = windowMinutes
    }

    var clampedRemaining: Double {
        min(max(remainingPercent, 0), 100)
    }

    /// Window length used for sorting and for 5-hour/weekly matching, falling
    /// back to reading the label when a provider does not report a duration.
    var effectiveMinutes: Int {
        windowMinutes ?? Self.minutes(fromLabel: label)
    }

    /// Human phrasing for the reset moment, shared by the panel card and the
    /// HUD payload so a phone and the Mac never disagree.
    func resetText(language: AppLanguage) -> String? {
        guard let resetAt else { return nil }
        let interval = resetAt.timeIntervalSinceNow
        guard interval > 0 else {
            return language.text("额度窗口正在重置", "Quota window is resetting")
        }
        if interval < 3_600 {
            let minutes = max(1, Int(interval / 60))
            return language.text("\(minutes) 分钟后重置", "Resets in \(minutes) min")
        }
        if interval < 86_400 {
            let hours = Int(interval / 3_600)
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
            return language.text(
                minutes > 0 ? "\(hours) 小时 \(minutes) 分后重置" : "\(hours) 小时后重置",
                minutes > 0 ? "Resets in \(hours)h \(minutes)m" : "Resets in \(hours)h"
            )
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .chinese ? "zh_CN" : "en_US")
        formatter.dateFormat = language == .chinese ? "M月d日 HH:mm" : "MMM d, HH:mm"
        return language.text(
            "\(formatter.string(from: resetAt)) 重置",
            "Resets \(formatter.string(from: resetAt))"
        )
    }

    static func minutes(fromLabel label: String) -> Int {
        let lower = label.lowercased()
        if lower.contains("week") || lower.contains("周") { return 10_080 }
        let value = lower
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
            .first
        guard let value, value > 0 else { return .max }
        if lower.contains("天") || lower.contains("day") { return value * 1_440 }
        if lower.contains("小时") || lower.contains("hour") || lower.contains("h") {
            return value * 60
        }
        if lower.contains("分") || lower.contains("min") { return value }
        return .max
    }
}

enum QuotaWindowPreference: String, CaseIterable, Identifiable, Sendable {
    case fiveHour
    case weekly

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .fiveHour: language.text("5 小时", "5 hours")
        case .weekly: language.text("周额度", "Weekly")
        }
    }

    func compactLabel(language: AppLanguage) -> String {
        switch self {
        case .fiveHour: language.text("5时", "5h")
        case .weekly: language.text("周", "7d")
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case full
    case scrolling

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .automatic: language.text("自动", "Auto")
        case .full: language.text("完整", "Full")
        case .scrolling: language.text("滚动", "Scroll")
        }
    }
}

enum PanelLayoutMode: String, CaseIterable, Identifiable, Sendable {
    case standard
    case compact

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .standard: language.text("标准", "Standard")
        case .compact: language.text("单行", "One line")
        }
    }

    /// Width a single provider gets in the default layout. The panel is freely
    /// resizable afterwards; this only decides the size it opens at.
    private var preferredProviderWidth: Double {
        switch self {
        case .standard: 196
        case .compact: 128
        }
    }

    /// Width taken by everything that is not a provider: the panel's own
    /// padding, plus the traffic lights and buttons in the one-line bar. Kept
    /// exact so the default panel has no dead space beside the last card.
    private var chromeWidth: Double {
        switch self {
        case .standard: 28
        case .compact: 174
        }
    }

    var defaultHeight: Double {
        switch self {
        case .standard: 286
        case .compact: 68
        }
    }

    func defaultWidth(visibleProviderCount: Int) -> Double {
        let count = Double(max(visibleProviderCount, 1))
        return (preferredProviderWidth * count) + (10 * (count - 1)) + chromeWidth
    }

    func defaultSize(visibleProviderCount: Int) -> CGSize {
        CGSize(
            width: defaultWidth(visibleProviderCount: visibleProviderCount),
            height: defaultHeight
        )
    }

    var minSize: CGSize {
        switch self {
        case .standard: CGSize(width: 330, height: 212)
        case .compact: CGSize(width: 240, height: 44)
        }
    }

    var maxSize: CGSize {
        switch self {
        case .standard: CGSize(width: 2_400, height: 900)
        case .compact: CGSize(width: 2_400, height: 200)
        }
    }

    func clamp(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minSize.width), maxSize.width),
            height: min(max(size.height, minSize.height), maxSize.height)
        )
    }

    var cornerRadius: Double {
        switch self {
        case .standard: 24
        case .compact: 18
        }
    }
}

/// Pure geometry for the floating panel, kept out of the app delegate so the
/// "collapsing must not move the panel" rule can be tested directly.
enum PanelGeometry {
    /// Frame for a resize that pins the top edge and whichever side edge the
    /// panel is currently parked against.
    static func resized(
        _ frame: CGRect,
        to size: CGSize,
        onScreen screen: CGRect?
    ) -> CGRect {
        let keepsLeftEdge = screen.map { frame.midX < $0.midX } ?? false
        return CGRect(
            x: keepsLeftEdge ? frame.minX : frame.maxX - size.width,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

enum QuotaWindowSelector {
    /// Shortest window first, so a card always reads "5 hours" above "7 days"
    /// no matter what order the provider returned them in.
    static func ordered(_ limits: [LimitWindow]) -> [LimitWindow] {
        limits.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.effectiveMinutes
                let right = rhs.element.effectiveMinutes
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    static func limit(
        in limits: [LimitWindow],
        preference: QuotaWindowPreference
    ) -> LimitWindow? {
        limits.first { matches($0, preference: preference) }
    }

    /// The window the card shows as its headline number: the one the user asked
    /// for, or the shortest available window when that one is missing.
    static func primary(
        in limits: [LimitWindow],
        preference: QuotaWindowPreference
    ) -> LimitWindow? {
        limit(in: limits, preference: preference) ?? ordered(limits).first
    }

    /// Everything except the headline window, shortest first.
    static func secondary(
        in limits: [LimitWindow],
        preference: QuotaWindowPreference
    ) -> [LimitWindow] {
        guard let primary = primary(in: limits, preference: preference) else { return [] }
        return ordered(limits).filter { $0.id != primary.id }
    }

    private static func matches(
        _ limit: LimitWindow,
        preference: QuotaWindowPreference
    ) -> Bool {
        switch preference {
        case .fiveHour:
            // Anything up to a day counts as the short rolling window.
            limit.effectiveMinutes <= 1_440
        case .weekly:
            limit.effectiveMinutes > 1_440 && limit.effectiveMinutes != .max
        }
    }
}

struct ProviderSnapshot: Identifiable, Equatable, Sendable {
    let id: ProviderID
    var activity: ActivityState
    var limits: [LimitWindow]
    var detail: String
    var source: String
    var lastUpdated: Date?
    var setupAvailable: Bool
    var isInstalled: Bool
    var balances: [AccountBalance] = []

    static func placeholder(_ id: ProviderID) -> ProviderSnapshot {
        ProviderSnapshot(
            id: id,
            activity: .offline,
            limits: [],
            detail: "正在读取本地状态…",
            source: "本地只读",
            lastUpdated: nil,
            setupAvailable: false,
            isInstalled: false
        )
    }
}

enum CollectorError: LocalizedError {
    case existingClaudeStatusLine
    case helperMissing
    case invalidSettings
    case invalidCredential
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .existingClaudeStatusLine:
            "Claude 已配置其他 status line；为避免覆盖，请先查看 README 中的合并方式。"
        case .helperMissing:
            "找不到 Claude 采集 helper，请从打包后的 Quota Bar.app 运行。"
        case .invalidSettings:
            "Claude settings.json 不是有效的 JSON 对象。"
        case .invalidCredential:
            "Kimi 登录信息不可用，请先运行 kimi login。"
        case .http(let status):
            "额度服务返回 HTTP \(status)。"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }

    func text(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}

enum RefreshMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case thirtySeconds
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case sixHours
    case custom
    case manual

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .smart:
            language.text("智能（工作 30 秒 / 空闲 5 分钟）", "Smart (30s active / 5m idle)")
        case .thirtySeconds:
            language.text("每 30 秒", "Every 30 seconds")
        case .oneMinute:
            language.text("每 1 分钟", "Every minute")
        case .fiveMinutes:
            language.text("每 5 分钟", "Every 5 minutes")
        case .fifteenMinutes:
            language.text("每 15 分钟", "Every 15 minutes")
        case .thirtyMinutes:
            language.text("每 30 分钟", "Every 30 minutes")
        case .oneHour:
            language.text("每 1 小时", "Every hour")
        case .sixHours:
            language.text("每 6 小时", "Every 6 hours")
        case .custom:
            language.text("自定义", "Custom")
        case .manual:
            language.text("仅手动", "Manual only")
        }
    }

    func interval(
        hasActiveProvider: Bool,
        customSeconds: Int = 120
    ) -> TimeInterval? {
        switch self {
        case .smart: hasActiveProvider ? 30 : 300
        case .thirtySeconds: 30
        case .oneMinute: 60
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1_800
        case .oneHour: 3_600
        case .sixHours: 21_600
        case .custom: TimeInterval(min(max(customSeconds, 10), 86_400))
        case .manual: nil
        }
    }
}
