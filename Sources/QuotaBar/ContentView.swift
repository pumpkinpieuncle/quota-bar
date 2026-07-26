import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    @State private var showSettings = false
    @State private var showProviderManager = false
    let onHideToMenuBar: () -> Void

    init(model: AppModel, onHideToMenuBar: @escaping () -> Void = {}) {
        self.model = model
        self.onHideToMenuBar = onHideToMenuBar
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
            Color(red: 0.045, green: 0.052, blue: 0.066)
                .opacity(0.9)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.07),
                    Color.black.opacity(0.035),
                    Color.black.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if preferences.panelLayout == .compact {
                compactBody
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 12) {
                    header
                    cards
                    footer
                }
                .padding(16)
            }

            if showSettings, preferences.panelLayout == .standard {
                SettingsOverlay(
                    model: model,
                    isPresented: $showSettings,
                    showProviderManager: $showProviderManager
                )
                    .padding(12)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if showProviderManager, preferences.panelLayout == .standard {
                ProviderManagerOverlay(
                    model: model,
                    isPresented: $showProviderManager
                )
                .padding(12)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .frame(
            width: preferences.panelLayout.panelWidth(
                visibleProviderCount: preferences.visibleProviderOrder.count
            ),
            height: preferences.panelLayout.panelHeight
        )
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if let notice = model.notice, preferences.panelLayout == .standard {
                NoticeView(text: notice) {
                    model.dismissNotice()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 44)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: model.notice)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.88),
            value: preferences.panelLayout
        )
    }

    private var panelCornerRadius: Double {
        preferences.panelLayout == .compact ? 20 : 24
    }

    private var header: some View {
        HStack(spacing: 10) {
            TrafficLights(
                onClose: onHideToMenuBar,
                onMinimize: { preferences.panelLayout = .compact },
                onZoom: { preferences.panelLayout = .standard }
            )

            Text("Quota Bar")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text("设置", "Settings"))

            Button {
                preferences.panelLayout = .compact
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text(
                "收成单行；隐藏到顶部栏后可按 ⌥⌘Q 恢复",
                "Collapse to one line; press ⌥⌘Q if the menu bar is hidden"
            ))

            Button {
                Task { await model.refresh(forceRemote: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(model.isRefreshing ? .degrees(360) : .zero)
                    .animation(
                        model.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: model.isRefreshing
                    )
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text("立即刷新", "Refresh now"))
        }
        .contentShape(Rectangle())
    }

    private var cards: some View {
        HStack(spacing: 10) {
            ForEach(model.visibleSnapshots) { snapshot in
                ProviderCard(
                    snapshot: snapshot,
                    language: preferences.language,
                    installClaudeCollector: model.installClaudeCollector,
                    manageProviders: { showProviderManager = true }
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: "lock.shield")
                .font(.system(size: 10, weight: .semibold))
            Text(preferences.language.text(
                "本地状态 · 空闲自动降频",
                "Local state · slows down when idle"
            ))
                .font(.system(size: 10.5, weight: .medium))
            Spacer()
            Text(preferences.language.text("更新", "Updated") + " ")
                .font(.system(size: 10.5, weight: .medium))
            Text(model.lastRefresh, style: .relative)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 2)
    }

    private var compactBody: some View {
        HStack(spacing: 8) {
            TrafficLights(
                onClose: onHideToMenuBar,
                onMinimize: {},
                onZoom: { preferences.panelLayout = .standard }
            )

            ForEach(model.visibleSnapshots) { snapshot in
                compactProvider(snapshot)
            }

            Button {
                preferences.panelLayout = .standard
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text("展开标准视图", "Expand standard view"))

            Button {
                Task { await model.refresh(forceRemote: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text("立即刷新", "Refresh now"))
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactProvider(_ snapshot: ProviderSnapshot) -> some View {
        let quota = MenuBarSummary.value(
            snapshot: snapshot,
            preference: preferences.quotaWindow
        )
            ?? "—"
        return HStack(spacing: 5) {
            Circle()
                .fill(compactActivityColor(snapshot.activity))
                .frame(width: 5, height: 5)
            Text(snapshot.id.title)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(quota)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.085), lineWidth: 0.7)
                }
        )
        .help(
            "\(snapshot.id.title) · "
                + snapshot.activity.label(language: preferences.language)
        )
    }

    private func compactActivityColor(_ activity: ActivityState) -> Color {
        switch activity {
        case .waitingApproval: Color.orange
        case .working: Color(red: 0.43, green: 0.92, blue: 0.66)
        case .thinking: Color(red: 0.48, green: 0.7, blue: 1)
        case .needsAttention: Color.orange
        case .connected: Color(red: 0.43, green: 0.92, blue: 0.66)
        case .idle: Color.white.opacity(0.35)
        case .offline: Color.white.opacity(0.2)
        }
    }
}

private struct TrafficLights: View {
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onZoom: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            TrafficLightButton(
                color: Color(red: 1, green: 0.37, blue: 0.34),
                symbol: "xmark",
                help: "Hide",
                action: onClose
            )
            TrafficLightButton(
                color: Color(red: 1, green: 0.74, blue: 0.23),
                symbol: "minus",
                help: "One line",
                action: onMinimize
            )
            TrafficLightButton(
                color: Color(red: 0.2, green: 0.78, blue: 0.35),
                symbol: "arrow.up.left.and.arrow.down.right",
                help: "Standard",
                action: onZoom
            )
        }
        .frame(width: 48)
    }
}

private struct TrafficLightButton: View {
    let color: Color
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .overlay {
                    if isHovering {
                        Image(systemName: symbol)
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.58))
                    }
                }
                .frame(width: 12, height: 12)
                .overlay {
                    Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

private struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    let language: AppLanguage
    let installClaudeCollector: () -> Void
    let manageProviders: () -> Void

    private var accent: Color {
        switch snapshot.id {
        case .codex: Color(red: 0.37, green: 0.83, blue: 0.67)
        case .claude: Color(red: 0.94, green: 0.61, blue: 0.39)
        case .kimi: Color(red: 0.55, green: 0.66, blue: 1.0)
        case .deepseek: Color(red: 0.35, green: 0.76, blue: 0.96)
        }
    }

    private var activityColor: Color {
        switch snapshot.activity {
        case .waitingApproval: Color(red: 1, green: 0.7, blue: 0.28)
        case .working: Color(red: 0.43, green: 0.92, blue: 0.66)
        case .thinking: Color(red: 0.48, green: 0.7, blue: 1)
        case .idle: Color.white.opacity(0.34)
        case .offline: Color.white.opacity(0.2)
        case .needsAttention: Color(red: 1, green: 0.69, blue: 0.3)
        case .connected: Color(red: 0.43, green: 0.92, blue: 0.66)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: snapshot.id.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 23, height: 23)
                    .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))

                Text(snapshot.id.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)

                Spacer(minLength: 2)

                HStack(spacing: 4) {
                    Circle()
                        .fill(activityColor)
                        .frame(width: 5, height: 5)
                    Text(snapshot.activity.label(language: language))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(0)
            }

            if
                let balance = snapshot.balances.first,
                snapshot.id == .deepseek || snapshot.limits.isEmpty
            {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(balance.compactText)
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Text(language.text("余额", "balance"))
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.42))
                    }

                    HStack {
                        Text(language.text("充值", "Topped up"))
                        Spacer()
                        Text("\(balance.symbol)\(NSDecimalNumber(decimal: balance.toppedUp).stringValue)")
                    }
                    HStack {
                        Text(language.text("赠送", "Granted"))
                        Spacer()
                        Text("\(balance.symbol)\(NSDecimalNumber(decimal: balance.granted).stringValue)")
                    }
                    .padding(.top, 2)
                }
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.53))
            } else if let primary = snapshot.limits.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(primary.clampedRemaining.rounded()))")
                            .font(.system(size: 29, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text(
                            "\(localizedLimitLabel(primary.label)) "
                                + language.text("可用", "available")
                        )
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.42))
                    }

                    QuotaProgress(value: primary.clampedRemaining / 100, tint: accent)

                    if let resetAt = primary.resetAt {
                        Text(resetText(resetAt))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                if let secondary = snapshot.limits.dropFirst().first {
                    VStack(spacing: 5) {
                        HStack {
                            Text(localizedLimitLabel(secondary.label))
                            Spacer()
                            Text(
                                "\(Int(secondary.clampedRemaining.rounded()))% "
                                    + language.text("可用", "available")
                            )
                        }
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.53))
                        QuotaProgress(value: secondary.clampedRemaining / 100, tint: accent)
                    }
                } else {
                    Spacer(minLength: 7)
                }

                if snapshot.id == .kimi, let balance = snapshot.balances.first {
                    HStack(spacing: 6) {
                        Text(
                            language.text("赠送", "Voucher")
                                + " \(balance.symbol)"
                                + NSDecimalNumber(decimal: balance.granted).stringValue
                        )
                        Spacer(minLength: 2)
                        Text(
                            language.text("现金", "Cash")
                                + " \(balance.symbol)"
                                + NSDecimalNumber(decimal: balance.toppedUp).stringValue
                        )
                    }
                    .font(.system(size: 8.8, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.82))
                    .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text("—")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.32))
                    Text(language.text("暂无精确额度", "No exact quota yet"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))

                    if snapshot.id == .claude && snapshot.setupAvailable {
                        Button(
                            language.text(
                                "配置 / 修复采集",
                                "Configure / repair capture"
                            ),
                            action: installClaudeCollector
                        )
                            .buttonStyle(CollectorButtonStyle(tint: accent))
                    } else if snapshot.id == .deepseek {
                        Button(
                            language.text("管理 DeepSeek", "Manage DeepSeek"),
                            action: manageProviders
                        )
                        .buttonStyle(CollectorButtonStyle(tint: accent))
                    } else {
                        Spacer(minLength: 24)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(snapshot.detail)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(snapshot.source)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 174, maxHeight: 174)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.13), Color.white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
        )
    }

    private func resetText(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            return language.text("额度窗口正在重置", "Quota window is resetting")
        }
        if interval < 3_600 {
            let minutes = max(1, Int(interval / 60))
            return language.text(
                "\(minutes) 分钟后重置",
                "Resets in \(minutes) min"
            )
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
            "\(formatter.string(from: date)) 重置",
            "Resets \(formatter.string(from: date))"
        )
    }

    private func localizedLimitLabel(_ label: String) -> String {
        let lower = label.lowercased()
        if lower == "7 天" || lower.contains("week") {
            return language.text("7 天", "7 days")
        }
        if lower == "5 小时" || lower.contains("5h") {
            return language.text("5 小时", "5 hours")
        }
        if language == .english {
            return label
                .replacingOccurrences(of: " 小时", with: " hours")
                .replacingOccurrences(of: " 天", with: " days")
                .replacingOccurrences(of: " 分钟", with: " minutes")
                .replacingOccurrences(of: "额度", with: "Quota")
        }
        return label
    }
}

private struct SettingsOverlay: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    @Binding var isPresented: Bool
    @Binding var showProviderManager: Bool

    init(
        model: AppModel,
        isPresented: Binding<Bool>,
        showProviderManager: Binding<Bool>
    ) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
        _isPresented = isPresented
        _showProviderManager = showProviderManager
    }

    private var language: AppLanguage { preferences.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("设置", "Settings"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Quota Bar \(model.versionText)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }
                Spacer()
                Button {
                    isPresented = false
                    showProviderManager = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(HeaderButtonStyle())
                .help(language.text("模型排序与隐藏", "Model order and visibility"))

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(HeaderButtonStyle())
            }

            settingRow(
                title: language.text("语言", "Language"),
                detail: language.text("界面语言立即切换", "Changes immediately")
            ) {
                Picker("", selection: $preferences.language) {
                    ForEach(AppLanguage.allCases) { item in
                        Text(item.nativeName).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
                .onChange(of: preferences.language) { _, _ in
                    model.preferencesChanged(languageChanged: true)
                }
            }

            settingRow(
                title: language.text("刷新频率", "Refresh interval"),
                detail: refreshDetail
            ) {
                HStack(spacing: 7) {
                    Picker("", selection: $preferences.refreshMode) {
                        ForEach(RefreshMode.allCases) { mode in
                            Text(mode.label(language: language)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: preferences.refreshMode == .custom ? 125 : 265)
                    .onChange(of: preferences.refreshMode) { _, _ in
                        model.preferencesChanged(languageChanged: false)
                    }

                    if preferences.refreshMode == .custom {
                        TextField(
                            "",
                            value: customSecondsBinding,
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)

                        Text(language.text("秒", "sec"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            settingRow(
                title: language.text("摘要显示", "Summary display"),
                detail: language.text(
                    "用于菜单栏和单行模式",
                    "Used by the menu bar and one-line mode"
                )
            ) {
                Picker("", selection: $preferences.quotaWindow) {
                    ForEach(QuotaWindowPreference.allCases) { window in
                        Text(window.label(language: language)).tag(window)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            HStack(spacing: 7) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 0.43, green: 0.92, blue: 0.66))
                Text(language.text(
                    "状态只来自本地，不调用模型 · 顶部栏被遮挡时按 ⌥⌘Q",
                    "Local status never calls a model · Press ⌥⌘Q if the menu bar is hidden"
                ))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.075, green: 0.085, blue: 0.105).opacity(0.97))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                }
        )
        .shadow(color: .black.opacity(0.42), radius: 20, y: 8)
    }

    private var customSecondsBinding: Binding<Int> {
        Binding(
            get: { preferences.customRefreshSeconds },
            set: { newValue in
                preferences.customRefreshSeconds = min(max(newValue, 10), 86_400)
                model.preferencesChanged(languageChanged: false)
            }
        )
    }

    private var refreshDetail: String {
        if preferences.refreshMode == .custom {
            return language.text(
                "可输入 10–86400 秒（最长 24 小时）",
                "Enter 10–86400 seconds (up to 24 hours)"
            )
        }
        return language.text(
            "智能模式在全部空闲时仅每 5 分钟读取一次",
            "Smart mode checks only every 5 minutes while idle"
        )
    }

    private func settingRow<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            content()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct ProviderManagerOverlay: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var kimiAPIKey = ""
    @State private var isSavingKimi = false

    init(model: AppModel, isPresented: Binding<Bool>) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
        _isPresented = isPresented
    }

    private var language: AppLanguage { preferences.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("模型管理", "Model management"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(language.text(
                        "调整排序、隐藏服务，或暂停单个额度刷新",
                        "Reorder, hide, or pause quota refresh per service"
                    ))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(HeaderButtonStyle())
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    ForEach(Array(preferences.providerOrder.enumerated()), id: \.element) {
                        index, provider in
                        providerRow(provider, index: index)
                    }
                }
                .frame(width: 230)

                kimiSetup
                    .frame(width: 250)
                deepSeekSetup
                    .frame(width: 250)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.075, green: 0.085, blue: 0.105).opacity(0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                }
        )
        .shadow(color: .black.opacity(0.42), radius: 20, y: 8)
    }

    private func providerRow(_ provider: ProviderID, index: Int) -> some View {
        let isHidden = preferences.hiddenProviders.contains(provider)
        let isPaused = preferences.pausedProviders.contains(provider)
        return HStack(spacing: 7) {
            Image(systemName: provider.symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20)
                .foregroundStyle(.white.opacity(isHidden ? 0.28 : 0.72))
            Text(provider.title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isHidden ? 0.35 : 0.82))
            Spacer()
            Button {
                let willHide = !isHidden
                preferences.setProvider(provider, hidden: willHide)
                if !willHide {
                    Task { await model.refresh(forceRemote: false) }
                }
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(ManagerButtonStyle())
            .help(language.text(
                isHidden ? "显示" : "隐藏",
                isHidden ? "Show" : "Hide"
            ))

            Button {
                preferences.setProvider(provider, paused: !isPaused)
                Task { await model.refresh(forceRemote: isPaused) }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(ManagerButtonStyle())
            .help(language.text(
                isPaused ? "恢复额度刷新" : "暂停额度刷新",
                isPaused ? "Resume quota refresh" : "Pause quota refresh"
            ))

            Button {
                preferences.moveProvider(provider, offset: -1)
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(ManagerButtonStyle())
            .disabled(index == 0)

            Button {
                preferences.moveProvider(provider, offset: 1)
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(ManagerButtonStyle())
            .disabled(index == preferences.providerOrder.count - 1)
        }
        .padding(.horizontal, 8)
        .frame(height: 31)
        .background(
            Color.white.opacity(isHidden ? 0.025 : 0.05),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private var kimiSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: ProviderID.kimi.symbol)
                    .foregroundStyle(Color(red: 0.55, green: 0.66, blue: 1))
                Text(language.text("Kimi 赠送额度", "Kimi voucher"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Spacer()
                Text(model.kimiAPIKeyConfigured
                    ? language.text("已配置", "Configured")
                    : language.text("可选", "Optional"))
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(
                        model.kimiAPIKeyConfigured
                            ? Color.green.opacity(0.75)
                            : Color.white.opacity(0.35)
                    )
            }

            SecureField(
                model.kimiAPIKeyConfigured
                    ? language.text("输入新 Key 可替换", "Enter a new key to replace")
                    : "sk-…",
                text: $kimiAPIKey
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 7) {
                Button {
                    let key = kimiAPIKey
                    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }
                    isSavingKimi = true
                    Task {
                        await model.saveKimiAPIKey(key)
                        kimiAPIKey = ""
                        isSavingKimi = false
                    }
                } label: {
                    Text(isSavingKimi
                        ? language.text("验证中…", "Checking…")
                        : language.text("保存并验证", "Save & verify"))
                }
                .buttonStyle(CollectorButtonStyle(
                    tint: Color(red: 0.55, green: 0.66, blue: 1)
                ))
                .disabled(isSavingKimi || kimiAPIKey.isEmpty)

                if model.kimiAPIKeyConfigured {
                    Button {
                        Task { await model.removeKimiAPIKey() }
                    } label: {
                        Text(language.text("移除", "Remove"))
                    }
                    .buttonStyle(CollectorButtonStyle(tint: .orange))
                }
            }

            Text(language.text(
                "赠送/现金余额来自 Kimi 开放平台；与 Kimi Code 登录分开，仅请求余额接口。",
                "Voucher/cash balance uses a separate Kimi Open Platform key and only calls its balance endpoint."
            ))
            .font(.system(size: 8.8, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(
            Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var deepSeekSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: ProviderID.deepseek.symbol)
                    .foregroundStyle(Color(red: 0.35, green: 0.76, blue: 0.96))
                Text("DeepSeek")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Spacer()
                Text(model.deepSeekKeyConfigured
                    ? language.text("已配置", "Configured")
                    : language.text("未配置", "Not configured"))
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(
                        model.deepSeekKeyConfigured
                            ? Color.green.opacity(0.75)
                            : Color.white.opacity(0.35)
                    )
            }

            SecureField(
                model.deepSeekKeyConfigured
                    ? language.text("输入新 Key 可替换", "Enter a new key to replace")
                    : "sk-…",
                text: $apiKey
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 7) {
                Button {
                    let key = apiKey
                    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }
                    isSaving = true
                    Task {
                        await model.saveDeepSeekAPIKey(key)
                        apiKey = ""
                        isSaving = false
                    }
                } label: {
                    Text(isSaving
                        ? language.text("验证中…", "Checking…")
                        : language.text("保存并验证", "Save & verify"))
                }
                .buttonStyle(CollectorButtonStyle(
                    tint: Color(red: 0.35, green: 0.76, blue: 0.96)
                ))
                .disabled(isSaving || apiKey.isEmpty)

                if model.deepSeekKeyConfigured {
                    Button {
                        Task { await model.removeDeepSeekAPIKey() }
                    } label: {
                        Text(language.text("移除", "Remove"))
                    }
                    .buttonStyle(CollectorButtonStyle(tint: .orange))
                }
            }

            Text(language.text(
                "需使用开放平台生成的 API Key（不是网页登录信息）；仅存于钥匙串，只请求 /user/balance。",
                "Use a developer-platform API key, not web sign-in details. Stored in Keychain; only /user/balance is requested."
            ))
            .font(.system(size: 8.8, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(
            Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

private struct QuotaProgress: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.075))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(3, proxy.size.width * min(max(value, 0), 1)))
                    .shadow(color: tint.opacity(0.25), radius: 4)
            }
        }
        .frame(height: 5)
    }
}

private struct ManagerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.4 : 0.64))
            .background(
                Color.white.opacity(configuration.isPressed ? 0.09 : 0.045),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct HeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.48 : 0.76))
            .background(
                Color.white.opacity(configuration.isPressed ? 0.1 : 0.065),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
    }
}

private struct CollectorButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(tint.opacity(configuration.isPressed ? 0.62 : 0.95))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(configuration.isPressed ? 0.08 : 0.13), in: Capsule())
    }
}

private struct NoticeView: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color(red: 0.57, green: 0.72, blue: 1))
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(2)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.7)
        }
    }
}
