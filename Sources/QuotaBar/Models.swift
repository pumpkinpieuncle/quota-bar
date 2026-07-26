import Foundation

enum ProviderID: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude
    case kimi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .kimi: "Kimi"
        }
    }

    var symbol: String {
        switch self {
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .claude: "sparkles"
        case .kimi: "moon.stars.fill"
        }
    }
}

enum ActivityState: String, Sendable {
    case waitingApproval
    case working
    case thinking
    case idle
    case offline
    case needsAttention

    func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.waitingApproval, .chinese): "等你审批"
        case (.working, .chinese): "当牛马中"
        case (.thinking, .chinese): "思考中"
        case (.idle, .chinese): "摸鱼中"
        case (.offline, .chinese): "未运行"
        case (.needsAttention, .chinese): "需处理"
        case (.waitingApproval, .english): "Awaiting approval"
        case (.working, .english): "Working"
        case (.thinking, .english): "Thinking"
        case (.idle, .english): "Idle"
        case (.offline, .english): "Not running"
        case (.needsAttention, .english): "Needs attention"
        }
    }

    var isActive: Bool {
        self == .waitingApproval || self == .working || self == .thinking
    }
}

struct LimitWindow: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let remainingPercent: Double
    let resetAt: Date?

    var clampedRemaining: Double {
        min(max(remainingPercent, 0), 100)
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
        case .custom: TimeInterval(min(max(customSeconds, 10), 3_600))
        case .manual: nil
        }
    }
}
