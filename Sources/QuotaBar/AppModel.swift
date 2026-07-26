import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshots: [ProviderSnapshot] = ProviderID.allCases.map {
        ProviderSnapshot.placeholder($0)
    }
    @Published var isRefreshing = false
    @Published var notice: String?
    @Published var lastRefresh = Date()

    let preferences = AppPreferences()

    private let codexClient = CodexUsageClient()
    private let kimiClient = KimiUsageClient()
    private var scheduledRefresh: Task<Void, Never>?

    var language: AppLanguage { preferences.language }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.2.0"
        return "v\(version)"
    }

    var refreshPolicyText: String {
        preferences.refreshMode.label(language: language)
    }

    func start() {
        if
            LocalCollectors.claudeCollectorInstalled(),
            LocalCollectors.claudeCollectorNeedsRepair()
        {
            try? ClaudeCollectorInstaller.install()
        }
        Task { await refresh(forceRemote: true) }
    }

    func refresh(forceRemote: Bool) async {
        guard !isRefreshing else { return }
        scheduledRefresh?.cancel()
        isRefreshing = true
        let currentLanguage = preferences.language

        let bundle = await Task.detached(priority: .utility) {
            LocalCollectors.collect(language: currentLanguage)
        }.value
        var merged = [bundle.codex, bundle.claude, bundle.kimi]

        if bundle.codex.isInstalled {
            do {
                let usage = try await codexClient.fetchIfNeeded(
                    force: forceRemote,
                    language: currentLanguage
                )
                if let index = merged.firstIndex(where: { $0.id == .codex }) {
                    merged[index].limits = usage.limits
                    merged[index].lastUpdated = usage.fetchedAt
                    merged[index].source = currentLanguage.text(
                        "Codex 账号额度 + 本地任务状态",
                        "Codex account quota + local task status"
                    )
                    if !usage.plan.isEmpty,
                       !merged[index].detail.localizedCaseInsensitiveContains(usage.plan) {
                        merged[index].detail = "\(usage.plan) · \(merged[index].detail)"
                    }
                }
            } catch {
                if let index = merged.firstIndex(where: { $0.id == .codex }) {
                    merged[index].source = currentLanguage.text(
                        "Codex 本地快照（账号同步暂不可用）",
                        "Local Codex snapshot (account sync unavailable)"
                    )
                }
            }
        }

        if bundle.kimi.isInstalled {
            do {
                let kimiIsActive = bundle.kimi.activity.isActive
                let usage = try await kimiClient.fetchIfNeeded(
                    force: forceRemote,
                    allowRemote: kimiIsActive,
                    kimiIsWorking: kimiIsActive
                )
                if let index = merged.firstIndex(where: { $0.id == .kimi }) {
                    merged[index].limits = usage.limits
                    merged[index].lastUpdated = usage.fetchedAt
                    if usage.limits.isEmpty {
                        merged[index].detail = currentLanguage.text(
                            "额度服务暂未返回可展示窗口",
                            "The quota service returned no displayable window"
                        )
                    }
                }
            } catch {
                if let index = merged.firstIndex(where: { $0.id == .kimi }) {
                    if !bundle.kimi.activity.isActive {
                        merged[index].activity = .needsAttention
                    }
                    merged[index].detail = kimiError(error, language: currentLanguage)
                }
            }
        }

        snapshots = merged
        lastRefresh = Date()
        isRefreshing = false
        scheduleNextRefresh()
    }

    func preferencesChanged(languageChanged: Bool) {
        if languageChanged {
            Task { await refresh(forceRemote: false) }
        } else {
            scheduleNextRefresh()
        }
    }

    func installClaudeCollector() {
        do {
            try ClaudeCollectorInstaller.install()
            notice = language.text(
                "Claude 零额度采集器已配置；重启 Claude Code，首次正常响应后会显示额度、重置时间和审批状态。",
                "Claude zero-token capture is configured. Restart Claude Code; quota, reset times, and approval state appear after its first normal response."
            )
            Task { await refresh(forceRemote: false) }
        } catch {
            notice = error.localizedDescription
        }
    }

    func dismissNotice() {
        notice = nil
    }

    private func scheduleNextRefresh() {
        scheduledRefresh?.cancel()
        let hasActiveProvider = snapshots.contains { $0.activity.isActive }
        guard let interval = preferences.refreshMode.interval(
            hasActiveProvider: hasActiveProvider,
            customSeconds: preferences.customRefreshSeconds
        ) else {
            return
        }

        scheduledRefresh = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            await self?.refresh(forceRemote: false)
        }
    }

    private func kimiError(_ error: Error, language: AppLanguage) -> String {
        if let collectorError = error as? CollectorError {
            switch collectorError {
            case .invalidCredential:
                return language.text(
                    "Kimi 登录已过期，请先运行 kimi login",
                    "Kimi sign-in expired; run kimi login"
                )
            case .http(let status):
                return language.text(
                    "Kimi 额度服务返回 HTTP \(status)",
                    "Kimi quota service returned HTTP \(status)"
                )
            default:
                break
            }
        }
        return language.text("Kimi 额度同步失败", "Kimi quota sync failed")
    }
}
