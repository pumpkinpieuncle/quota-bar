import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    @State private var showSettings = false
    @State private var showProviderManager = false
    let onHideToMenuBar: () -> Void
    let onResetGeometry: () -> Void

    init(
        model: AppModel,
        onHideToMenuBar: @escaping () -> Void = {},
        onResetGeometry: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onHideToMenuBar = onHideToMenuBar
        self.onResetGeometry = onResetGeometry
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
                VStack(spacing: 10) {
                    header
                    cards
                    footer
                }
                .padding(14)
            }

            if showSettings, preferences.panelLayout == .standard {
                SettingsOverlay(
                    model: model,
                    isPresented: $showSettings,
                    showProviderManager: $showProviderManager,
                    onResetGeometry: onResetGeometry
                )
                    .padding(10)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if showProviderManager, preferences.panelLayout == .standard {
                ProviderManagerOverlay(
                    model: model,
                    isPresented: $showProviderManager
                )
                .padding(10)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        // The panel is user-resizable, so the content always fills whatever
        // frame the window currently has instead of pinning its own size.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        preferences.panelLayout.cornerRadius
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
                .fixedSize()

            if model.hud.isServing {
                Image(systemName: "wifi")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.43, green: 0.92, blue: 0.66).opacity(0.85))
                    .help(preferences.language.text("HUD 已开启", "HUD is on"))
            }

            Spacer(minLength: 4)

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
        // The column count is derived rather than left to `.adaptive`, which
        // would happily lay out more columns than there are services and leave
        // an empty slot on the right. Cards share the full width and wrap onto
        // another row as soon as the panel is narrowed.
        GeometryReader { proxy in
            let columns = Self.cardColumnCount(
                availableWidth: proxy.size.width,
                cardCount: model.visibleSnapshots.count
            )
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: Self.cardSpacing),
                        count: columns
                    ),
                    spacing: Self.cardSpacing
                ) {
                    ForEach(model.visibleSnapshots) { snapshot in
                        ProviderCard(
                            snapshot: snapshot,
                            language: preferences.language,
                            quotaWindow: preferences.quotaWindow,
                            lowQuotaThreshold: preferences.lowQuotaThreshold,
                            installClaudeCollector: model.installClaudeCollector,
                            manageProviders: { showProviderManager = true }
                        )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    static let cardSpacing: Double = 10
    static let minimumCardWidth: Double = 164

    static func cardColumnCount(availableWidth: Double, cardCount: Int) -> Int {
        guard cardCount > 0, availableWidth > 0 else { return 1 }
        let fits = Int(
            (availableWidth + cardSpacing) / (minimumCardWidth + cardSpacing)
        )
        return max(1, min(cardCount, fits))
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
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(preferences.language.text("更新", "Updated") + " ")
                .font(.system(size: 10.5, weight: .medium))
            Text(model.lastRefresh, style: .relative)
                .font(.system(size: 10.5, weight: .medium))
                .fixedSize()
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
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text("展开标准视图", "Expand standard view"))

            Button {
                Task { await model.refresh(forceRemote: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(HeaderButtonStyle())
            .help(preferences.language.text("立即刷新", "Refresh now"))
        }
        // Symmetric insets on every side: the row centres itself in whatever
        // height the bar has been resized to.
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func compactProvider(_ snapshot: ProviderSnapshot) -> some View {
        let quota = MenuBarSummary.value(
            snapshot: snapshot,
            preference: preferences.quotaWindow
        )
            ?? "—"
        let isLow = model.lowQuotaProviders.contains(snapshot.id)
        return HStack(spacing: 5) {
            BrandLogoView(
                provider: snapshot.id,
                size: 12,
                dimmed: snapshot.activity == .offline
            )
            Text(snapshot.id.title)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(quota)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isLow ? Color(red: 1, green: 0.45, blue: 0.42) : .white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Circle()
                .fill(compactActivityColor(snapshot.activity))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isLow ? Color(red: 1, green: 0.35, blue: 0.32).opacity(0.14)
                            : Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(
                            isLow ? Color(red: 1, green: 0.4, blue: 0.36).opacity(0.5)
                                  : Color.white.opacity(0.085),
                            lineWidth: 0.7
                        )
                }
        )
        .help(
            "\(snapshot.id.title) · "
                + snapshot.activity.label(language: preferences.language)
                + " · " + snapshot.detail
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
    let quotaWindow: QuotaWindowPreference
    let lowQuotaThreshold: Int
    let installClaudeCollector: () -> Void
    let manageProviders: () -> Void

    private var accent: Color { snapshot.id.accent }

    private var showsBalance: Bool {
        snapshot.balances.first != nil
            && (snapshot.id == .deepseek || snapshot.limits.isEmpty)
    }

    /// The window the user asked to see, falling back to the shortest one the
    /// provider reported.
    private var primaryLimit: LimitWindow? {
        QuotaWindowSelector.primary(in: snapshot.limits, preference: quotaWindow)
    }

    private var secondaryLimits: [LimitWindow] {
        QuotaWindowSelector.secondary(in: snapshot.limits, preference: quotaWindow)
    }

    private var isLow: Bool {
        guard lowQuotaThreshold > 0, let primaryLimit else { return false }
        return Int(primaryLimit.clampedRemaining.rounded()) <= lowQuotaThreshold
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                BrandLogoView(
                    provider: snapshot.id,
                    size: 14,
                    dimmed: snapshot.activity == .offline
                )
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

            if showsBalance, let balance = snapshot.balances.first {
                balanceBody(balance)
            } else if let primaryLimit {
                quotaBody(primaryLimit)
            } else {
                emptyBody
            }

            Spacer(minLength: 0)

            Text(snapshot.detail)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(snapshot.source)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isLow ? Color(red: 1, green: 0.35, blue: 0.32).opacity(0.09)
                            : Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isLow
                                ? AnyShapeStyle(Color(red: 1, green: 0.42, blue: 0.38).opacity(0.55))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.13),
                                        Color.white.opacity(0.035)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )),
                            lineWidth: 0.75
                        )
                }
        )
    }

    private func balanceBody(_ balance: AccountBalance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(balance.compactText)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
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
    }

    private func quotaBody(_ primary: LimitWindow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(primary.clampedRemaining.rounded()))")
                        .font(.system(size: 29, weight: .semibold, design: .rounded))
                        .foregroundStyle(isLow ? Color(red: 1, green: 0.5, blue: 0.46) : .white)
                    Text("%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 2)
                    Text(
                        "\(localizedLimitLabel(primary.label)) "
                            + language.text("可用", "available")
                    )
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                QuotaProgress(
                    value: primary.clampedRemaining / 100,
                    tint: isLow ? Color(red: 1, green: 0.42, blue: 0.38) : accent
                )

                if let reset = primary.resetText(language: language) {
                    Text(reset)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }

            ForEach(secondaryLimits.prefix(2)) { secondary in
                VStack(spacing: 5) {
                    HStack {
                        Text(localizedLimitLabel(secondary.label))
                        Spacer(minLength: 2)
                        Text(
                            "\(Int(secondary.clampedRemaining.rounded()))% "
                                + language.text("可用", "available")
                        )
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.53))
                    .lineLimit(1)
                    QuotaProgress(value: secondary.clampedRemaining / 100, tint: accent)
                }
            }
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("—")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))
            Text(language.text("暂无精确额度", "No exact quota yet"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            if snapshot.id == .claude && snapshot.setupAvailable {
                Button(
                    language.text("配置 / 修复采集", "Configure / repair capture"),
                    action: installClaudeCollector
                )
                    .buttonStyle(CollectorButtonStyle(tint: accent))
            } else if snapshot.id == .deepseek {
                Button(
                    language.text("管理 DeepSeek", "Manage DeepSeek"),
                    action: manageProviders
                )
                .buttonStyle(CollectorButtonStyle(tint: accent))
            }
        }
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
    @ObservedObject private var hud: HUDBridge
    @Binding var isPresented: Bool
    @Binding var showProviderManager: Bool
    let onResetGeometry: () -> Void
    @State private var copiedHUDURL = false

    init(
        model: AppModel,
        isPresented: Binding<Bool>,
        showProviderManager: Binding<Bool>,
        onResetGeometry: @escaping () -> Void
    ) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
        _hud = ObservedObject(wrappedValue: model.hud)
        _isPresented = isPresented
        _showProviderManager = showProviderManager
        self.onResetGeometry = onResetGeometry
    }

    private var language: AppLanguage { preferences.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            // Two columns on a normally sized panel, one when it is narrow, so
            // the settings still fit without scrolling at the default height.
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 330), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    languageRow
                    refreshRow
                    summaryRow
                    warningRow
                    layoutRow
                    hudRow
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            HStack(spacing: 7) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 0.43, green: 0.92, blue: 0.66))
                Text(language.text(
                    "状态只来自本地，不调用模型 · 顶部栏被遮挡时按 ⌥⌘Q",
                    "Local status never calls a model · Press ⌥⌘Q if the menu bar is hidden"
                ))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.075, green: 0.085, blue: 0.105).opacity(0.97))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                }
        )
        .shadow(color: .black.opacity(0.42), radius: 20, y: 8)
    }

    private var languageRow: some View {
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
            .frame(width: 140)
            .onChange(of: preferences.language) { _, _ in
                model.preferencesChanged(languageChanged: true)
            }
        }
    }

    private var refreshRow: some View {
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
                .frame(width: preferences.refreshMode == .custom ? 108 : 216)
                .onChange(of: preferences.refreshMode) { _, _ in
                    model.preferencesChanged(languageChanged: false)
                }

                if preferences.refreshMode == .custom {
                    TextField("", value: customSecondsBinding, format: .number)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 62)

                    Text(language.text("秒", "sec"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    private var summaryRow: some View {
        settingRow(
            title: language.text("摘要显示", "Summary display"),
            detail: language.text(
                "额度窗口 · 顶部栏显示方式",
                "Quota window · menu bar display"
            )
        ) {
            HStack(spacing: 8) {
                Picker("", selection: $preferences.quotaWindow) {
                    ForEach(QuotaWindowPreference.allCases) { window in
                        Text(window.label(language: language)).tag(window)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 120)

                Picker("", selection: $preferences.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.label(language: language)).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 152)
            }
        }
    }

    private var warningRow: some View {
        settingRow(
            title: language.text("低额度提醒", "Low-quota warning"),
            detail: language.text(
                "低于阈值时卡片和单行都会变红",
                "Cards and the one-line bar turn red below this"
            )
        ) {
            Picker("", selection: $preferences.lowQuotaThreshold) {
                Text(language.text("关闭", "Off")).tag(0)
                ForEach([5, 10, 20, 30], id: \.self) { value in
                    Text("\(value)%").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private var layoutRow: some View {
        settingRow(
            title: language.text("浮窗尺寸", "Panel size"),
            detail: language.text(
                "拖拽浮窗边缘即可调整宽高，靠近屏幕边缘会自动贴边",
                "Drag any edge to resize; the panel snaps to screen edges"
            )
        ) {
            Button(language.text("恢复默认大小与位置", "Reset size & position")) {
                onResetGeometry()
            }
            .buttonStyle(CollectorButtonStyle(tint: Color(red: 0.55, green: 0.66, blue: 1)))
        }
    }

    private var hudRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("HUD 外接屏", "HUD display"))
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(language.text(
                        "在备用手机或 ESP32 上显示额度，只读、不出局域网",
                        "Show quotas on a spare phone or an ESP32 — read-only, LAN only"
                    ))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $preferences.hudEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: preferences.hudEnabled) { _, _ in
                        model.preferencesChanged(languageChanged: false)
                    }
            }

            if preferences.hudEnabled {
                HStack(spacing: 8) {
                    Text(language.text("端口", "Port"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    TextField("", value: hudPortBinding, format: .number.grouping(.never))
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)

                    Toggle(isOn: $preferences.hudAllowsLAN) {
                        Text(language.text("允许局域网访问", "Allow LAN access"))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: preferences.hudAllowsLAN) { _, _ in
                        model.preferencesChanged(languageChanged: false)
                    }

                    Spacer(minLength: 4)

                    Button(language.text("换新令牌", "New token")) {
                        _ = preferences.regenerateHUDToken()
                        model.preferencesChanged(languageChanged: false)
                        copiedHUDURL = false
                    }
                    .buttonStyle(CollectorButtonStyle(tint: .orange))
                }

                HStack(spacing: 8) {
                    Text(hud.hudURL(preferences: preferences)
                        ?? hudStatusPlaceholder)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer(minLength: 4)
                    if let url = hud.hudURL(preferences: preferences) {
                        Button(copiedHUDURL
                            ? language.text("已复制", "Copied")
                            : language.text("复制网址", "Copy URL")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                            copiedHUDURL = true
                        }
                        .buttonStyle(CollectorButtonStyle(
                            tint: Color(red: 0.43, green: 0.92, blue: 0.66)
                        ))
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
    }

    private var hudStatusPlaceholder: String {
        switch hud.state {
        case .failed(let message):
            language.text("HUD 启动失败：\(message)", "HUD failed: \(message)")
        case .starting:
            language.text("正在启动…", "Starting…")
        default:
            language.text("未启动", "Not running")
        }
    }

    private var hudPortBinding: Binding<Int> {
        Binding(
            get: { preferences.hudPort },
            set: { newValue in
                preferences.hudPort = min(max(newValue, 1_024), 65_535)
                model.preferencesChanged(languageChanged: false)
            }
        )
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
        let label = VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
            Text(detail)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        // Side by side while there is room, stacked once the panel narrows.
        return ViewThatFits(in: .horizontal) {
            HStack {
                label
                Spacer(minLength: 8)
                content()
            }
            VStack(alignment: .leading, spacing: 7) {
                label
                content()
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct ProviderManagerOverlay: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isSaving = false

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
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(Array(preferences.providerOrder.enumerated()), id: \.element) {
                            index, provider in
                            providerRow(provider, index: index)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity)

                deepSeekSetup
                    .frame(width: 300)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.075, green: 0.085, blue: 0.105).opacity(0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                }
        )
        .shadow(color: .black.opacity(0.42), radius: 20, y: 8)
    }

    private func providerRow(_ provider: ProviderID, index: Int) -> some View {
        let isHidden = preferences.hiddenProviders.contains(provider)
        let isPaused = preferences.pausedProviders.contains(provider)
        return HStack(spacing: 7) {
            BrandLogoView(provider: provider, size: 13, dimmed: isHidden)
                .frame(width: 20)
            Text(provider.title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isHidden ? 0.35 : 0.82))
            Spacer(minLength: 2)
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

    private var deepSeekSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                BrandLogoView(provider: .deepseek, size: 14)
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
                .buttonStyle(CollectorButtonStyle(tint: ProviderID.deepseek.accent))
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
