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

    private let kimiClient = KimiUsageClient()
    private var scheduledRefresh: Task<Void, Never>?

    var language: AppLanguage { preferences.language }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.1.0"
        return "v\(version)"
    }

    var refreshPolicyText: String {
        preferences.refreshMode.label(language: language)
    }

    func start() {
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
                "Claude 零额度采集器已启用；重启 Claude Code，首次响应后会显示额度和审批状态。",
                "Claude zero-token capture is enabled. Restart Claude Code; quota and approval state appear after its first response."
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
            hasActiveProvider: hasActiveProvider
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
