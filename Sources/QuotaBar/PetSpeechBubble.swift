import SwiftUI

struct PetSpeechContent {
    let greeting: String
    let limits: [LimitWindow]
    let balances: [AccountBalance]
    let detail: String
    let extraLimitCount: Int

    init(snapshot: ProviderSnapshot, preference: QuotaWindowPreference, language: AppLanguage) {
        greeting = Self.greeting(for: snapshot, language: language)
        let primary = QuotaWindowSelector.primary(in: snapshot.limits, preference: preference)
        let ordered = primary.map { [$0] } ?? []
        let all = ordered + QuotaWindowSelector.secondary(in: snapshot.limits, preference: preference)
        limits = Array(all.prefix(3))
        extraLimitCount = max(0, all.count - limits.count)
        balances = snapshot.balances
        detail = snapshot.detail
    }

    private static func greeting(for snapshot: ProviderSnapshot, language: AppLanguage) -> String {
        if snapshot.id == .deepseek {
            switch snapshot.activity {
            case .connected, .idle:
                return language.text("我在呢，白饭我就放心吃了", "I'm here! Now I can enjoy my rice in peace~")
            default:
                break
            }
        }
        return switch snapshot.activity {
        case .working: language.text("我正在认真干活呢！", "I'm working on it!")
        case .thinking: language.text("让我再想一想～", "Let me think for a moment…")
        case .waitingApproval: language.text("这里需要你确认一下哦。", "I need your approval here.")
        case .needsAttention: language.text("遇到点问题，需要你看看。", "Something needs your attention.")
        case .idle: language.text("我先休息一下，有事叫我～", "Taking a little break. I'm here!")
        case .offline: language.text("这台电脑上暂时没有我的任务。", "No local task is running for me.")
        case .connected: language.text("我在呢，额度帮你看好了！", "I'm here. Here's your usage!")
        }
    }
}

struct PetSpeechBubble: View {
    let provider: ProviderID
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    let pointsDown: Bool
    let tailOffset: CGFloat

    init(provider: ProviderID, model: AppModel, pointsDown: Bool = true, tailOffset: CGFloat = 0) {
        self.provider = provider
        self.model = model
        self.pointsDown = pointsDown
        self.tailOffset = tailOffset
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    private var snapshot: ProviderSnapshot {
        model.snapshots.first { $0.id == provider } ?? .placeholder(provider)
    }

    var body: some View {
        let language = preferences.language
        let content = PetSpeechContent(snapshot: snapshot, preference: preferences.quotaWindow, language: language)
        VStack(spacing: 0) {
            if !pointsDown { tail.rotationEffect(.degrees(180)) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    BrandLogoView(provider: provider, size: 16)
                    Text(provider.title).font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer(minLength: 4)
                    Text(snapshot.activity.label(language: language))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(provider.accent)
                }
                Text(content.greeting)
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(content.limits) { limit in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(limit.label).foregroundStyle(.white.opacity(0.72))
                            Spacer()
                            Text(language.text("剩余 \(Int(limit.clampedRemaining.rounded()))%", "\(Int(limit.clampedRemaining.rounded()))% left"))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 11, design: .rounded))
                        GeometryReader { geometry in
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(limit.clampedRemaining <= Double(preferences.lowQuotaThreshold) ? Color.orange : provider.accent)
                                .frame(width: geometry.size.width * limit.clampedRemaining / 100)
                        }
                        .frame(height: 4)
                        if let reset = limit.resetText(language: language) {
                            Text(reset).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
                ForEach(Array(content.balances.enumerated()), id: \.offset) { _, balance in
                    HStack {
                        Text(language.text("可用余额", "Available balance"))
                        Spacer()
                        Text(balance.compactText).fontWeight(.semibold).foregroundStyle(provider.accent)
                    }
                    .font(.system(size: 12, design: .rounded))
                }
                if content.limits.isEmpty && content.balances.isEmpty {
                    Text(language.text("暂时没有可用额度数据", "No usage data available yet"))
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
                if content.extraLimitCount > 0 {
                    Text(language.text("另有 \(content.extraLimitCount) 个额度窗口，可在主面板查看", "\(content.extraLimitCount) more windows in the main panel"))
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                }
                if !content.detail.isEmpty {
                    Text(content.detail)
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                if preferences.pausedProviders.contains(provider) {
                    Text(language.text("额度刷新已暂停", "Quota refresh is paused"))
                        .font(.system(size: 10)).foregroundStyle(.orange)
                }
                if let updated = snapshot.lastUpdated {
                    HStack(spacing: 3) {
                        Text(language.text("更新于", "Updated"))
                        Text(updated, style: .relative)
                    }
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(14)
            .background(Color(red: 0.075, green: 0.085, blue: 0.105), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(provider.accent.opacity(0.35), lineWidth: 1))
            if pointsDown { tail }
        }
        .foregroundStyle(.white)
        .frame(width: 286)
        .padding(1)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var tail: some View {
        PetSpeechTail()
            .fill(Color(red: 0.075, green: 0.085, blue: 0.105))
            .frame(width: 18, height: 10)
            .offset(x: tailOffset)
    }
}

private struct PetSpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
