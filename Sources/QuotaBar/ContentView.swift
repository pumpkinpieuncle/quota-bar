import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    @State private var showSettings = false

    init(model: AppModel) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
            LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                header
                cards
                footer
            }
            .padding(16)

            if showSettings {
                SettingsOverlay(model: model, isPresented: $showSettings)
                    .padding(12)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .frame(width: 600, height: 286)
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                NoticeView(text: notice) {
                    model.dismissNotice()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 44)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: model.notice)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Quota Bar")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(preferences.language.text("额度与工作状态", "Quota & work status"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.43, green: 0.92, blue: 0.66))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.green.opacity(0.45), radius: 4)
                Text(preferences.language.text("0 模型调用", "0 model calls"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.065), in: Capsule())

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
            ForEach(model.snapshots) { snapshot in
                ProviderCard(
                    snapshot: snapshot,
                    language: preferences.language,
                    installClaudeCollector: model.installClaudeCollector
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
}

private struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    let language: AppLanguage
    let installClaudeCollector: () -> Void

    private var accent: Color {
        switch snapshot.id {
        case .codex: Color(red: 0.37, green: 0.83, blue: 0.67)
        case .claude: Color(red: 0.94, green: 0.61, blue: 0.39)
        case .kimi: Color(red: 0.55, green: 0.66, blue: 1.0)
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
            }

            if let primary = snapshot.limits.first {
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
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

    init(model: AppModel, isPresented: Binding<Bool>) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
        _isPresented = isPresented
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
                    .frame(width: preferences.refreshMode == .custom ? 105 : 245)
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
                        .frame(width: 58)

                        Text(language.text("秒", "sec"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 0.43, green: 0.92, blue: 0.66))
                Text(language.text(
                    "状态只来自本地进程、会话事件和 command hook，不调用模型。",
                    "Status comes only from local processes, session events, and command hooks—never a model."
                ))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 2)
        }
        .padding(16)
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

    private var customSecondsBinding: Binding<Int> {
        Binding(
            get: { preferences.customRefreshSeconds },
            set: { newValue in
                preferences.customRefreshSeconds = min(max(newValue, 10), 3_600)
                model.preferencesChanged(languageChanged: false)
            }
        )
    }

    private var refreshDetail: String {
        if preferences.refreshMode == .custom {
            return language.text(
                "可输入 10–3600 秒",
                "Enter any value from 10–3600 seconds"
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
