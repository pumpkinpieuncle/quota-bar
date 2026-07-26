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
    @Published var deepSeekKeyConfigured = DeepSeekCredentialStore.load() != nil

    let preferences = AppPreferences()

    private let codexClient = CodexUsageClient()
    private let deepSeekClient = DeepSeekBalanceClient()
    private let kimiClient = KimiUsageClient()
    private var scheduledRefresh: Task<Void, Never>?

    var language: AppLanguage { preferences.language }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.2.5"
        return "v\(version)"
    }

    var refreshPolicyText: String {
        preferences.refreshMode.label(language: language)
    }

    var visibleSnapshots: [ProviderSnapshot] {
        preferences.visibleProviderOrder.compactMap { provider in
            snapshots.first { $0.id == provider }
        }
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

    func refresh(
        forceRemote: Bool,
        preserveRemoteDataOnFailure: Bool = false
    ) async {
        guard !isRefreshing else { return }
        scheduledRefresh?.cancel()
        isRefreshing = true
        let currentLanguage = preferences.language
        let previousSnapshots = snapshots

        let bundle = await Task.detached(priority: .utility) {
            LocalCollectors.collect(language: currentLanguage)
        }.value
        var merged = [bundle.codex, bundle.claude, bundle.kimi]
        merged.append(
            ProviderSnapshot(
                id: .deepseek,
                activity: deepSeekKeyConfigured ? .connected : .needsAttention,
                limits: [],
                detail: currentLanguage.text(
                    deepSeekKeyConfigured
                        ? "等待同步账户余额"
                        : "在模型管理中配置 API Key",
                    deepSeekKeyConfigured
                        ? "Waiting to sync account balance"
                        : "Configure an API key in Model management"
                ),
                source: currentLanguage.text(
                    "DeepSeek 官方账户余额接口",
                    "Official DeepSeek account balance endpoint"
                ),
                lastUpdated: nil,
                setupAvailable: !deepSeekKeyConfigured,
                isInstalled: deepSeekKeyConfigured
            )
        )

        for provider in preferences.pausedProviders {
            guard
                let currentIndex = merged.firstIndex(where: { $0.id == provider }),
                let previous = previousSnapshots.first(where: { $0.id == provider })
            else {
                continue
            }
            merged[currentIndex].limits = previous.limits
            merged[currentIndex].balances = previous.balances
            merged[currentIndex].lastUpdated = previous.lastUpdated
            merged[currentIndex].source = previous.source
            if provider == .deepseek {
                merged[currentIndex].activity = previous.activity
            }
            merged[currentIndex].detail = currentLanguage.text(
                "额度刷新已暂停",
                "Quota refresh paused"
            )
        }

        if
            bundle.codex.isInstalled,
            !preferences.hiddenProviders.contains(.codex),
            !preferences.pausedProviders.contains(.codex)
        {
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

        if
            bundle.kimi.isInstalled,
            !preferences.hiddenProviders.contains(.kimi),
            !preferences.pausedProviders.contains(.kimi)
        {
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

        if
            deepSeekKeyConfigured,
            !preferences.hiddenProviders.contains(.deepseek),
            !preferences.pausedProviders.contains(.deepseek)
        {
            do {
                let balance = try await deepSeekClient.fetchIfNeeded(force: forceRemote)
                if let index = merged.firstIndex(where: { $0.id == .deepseek }) {
                    merged[index].balances = balance.balances
                    merged[index].lastUpdated = balance.fetchedAt
                    merged[index].activity = balance.isAvailable
                        ? .connected
                        : .needsAttention
                    let primary = balance.balances.first
                    merged[index].detail = currentLanguage.text(
                        primary.map { "账户余额 \($0.compactText)" }
                            ?? "已同步账户余额",
                        primary.map { "Account balance \($0.compactText)" }
                            ?? "Account balance synced"
                    )
                }
            } catch {
                if let index = merged.firstIndex(where: { $0.id == .deepseek }) {
                    if
                        preserveRemoteDataOnFailure,
                        let previous = previousSnapshots.first(where: {
                            $0.id == .deepseek && !$0.balances.isEmpty
                        })
                    {
                        merged[index].balances = previous.balances
                        merged[index].lastUpdated = previous.lastUpdated
                        merged[index].activity = previous.activity
                        merged[index].detail = currentLanguage.text(
                            "自动刷新暂时失败，保留上次余额",
                            "Automatic refresh failed; showing the last balance"
                        )
                    } else {
                        merged[index].activity = .needsAttention
                        merged[index].detail = deepSeekError(
                            error,
                            language: currentLanguage
                        )
                    }
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

    func saveDeepSeekAPIKey(_ key: String) async {
        do {
            let normalized = DeepSeekCredentialStore.normalizedAPIKey(key)
            _ = try await deepSeekClient.validate(apiKey: normalized)
            try DeepSeekCredentialStore.save(normalized)
            deepSeekKeyConfigured = true
            preferences.setProvider(.deepseek, hidden: false)
            notice = language.text(
                "DeepSeek API Key 验证成功，余额已同步。",
                "DeepSeek API key verified and balance synced."
            )
            await refresh(forceRemote: false)
        } catch {
            notice = deepSeekError(error, language: language)
        }
    }

    func removeDeepSeekAPIKey() async {
        do {
            try DeepSeekCredentialStore.delete()
            deepSeekKeyConfigured = false
            notice = language.text(
                "DeepSeek API Key 已从 macOS 钥匙串移除。",
                "DeepSeek API key was removed from macOS Keychain."
            )
            await refresh(forceRemote: false)
        } catch {
            notice = deepSeekError(error, language: language)
        }
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
            await self?.scheduledRefreshDidFire()
        }
    }

    private func scheduledRefreshDidFire() async {
        scheduledRefresh = nil
        await refresh(
            forceRemote: true,
            preserveRemoteDataOnFailure: true
        )
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

    private func deepSeekError(_ error: Error, language: AppLanguage) -> String {
        if let clientError = error as? DeepSeekBalanceClient.ClientError {
            switch clientError {
            case .missingCredential:
                return language.text(
                    "请先配置 DeepSeek API Key",
                    "Configure a DeepSeek API key first"
                )
            case .invalidCredential:
                return language.text(
                    "DeepSeek 拒绝了该 Key（401）。请使用开放平台生成的 API Key，不是网页或桌面端登录信息。",
                    "DeepSeek rejected this key (401). Use an API key created on the developer platform, not web or desktop sign-in details."
                )
            case .http(let status):
                return language.text(
                    "DeepSeek 余额接口返回 HTTP \(status)",
                    "DeepSeek balance endpoint returned HTTP \(status)"
                )
            case .keychain:
                return language.text(
                    "无法访问 macOS 钥匙串",
                    "Could not access macOS Keychain"
                )
            case .invalidResponse:
                return language.text(
                    "DeepSeek 返回了无法识别的余额数据",
                    "DeepSeek returned unreadable balance data"
                )
            }
        }
        return language.text("DeepSeek 余额同步失败", "DeepSeek balance sync failed")
    }
}
