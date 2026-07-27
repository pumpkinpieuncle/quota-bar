import Combine
import Foundation
import QuotaBarHUD

/// Owns the HUD server and keeps it fed with the same snapshots the panel
/// shows. Everything here is read-only: the HUD can never change app state.
@MainActor
final class HUDBridge: ObservableObject {
    @Published private(set) var state: HUDServerState = .stopped
    @Published private(set) var addresses: [String] = []

    private let server: HUDServer
    private var isRunning = false

    init() {
        server = HUDServer(
            payload: .empty(version: AppVersion.short, host: ProcessInfo.processInfo.hostName)
        )
        server.onStateChange { [weak self] newState in
            Task { @MainActor [weak self] in
                self?.state = newState
            }
        }
    }

    var statusText: String {
        switch state {
        case .stopped: ""
        case .starting: "…"
        case .running(let port): ":\(port)"
        case .failed(let message): message
        }
    }

    var isServing: Bool {
        if case .running = state { return true }
        return false
    }

    /// URL a phone on the same network should open, token included.
    func hudURL(preferences: AppPreferences) -> String? {
        guard isServing else { return nil }
        let host = preferences.hudAllowsLAN
            ? (addresses.first ?? "127.0.0.1")
            : "127.0.0.1"
        return "http://\(host):\(preferences.hudPort)/?token=\(preferences.hudToken())"
    }

    func apply(preferences: AppPreferences, snapshots: [ProviderSnapshot]) {
        publish(preferences: preferences, snapshots: snapshots)

        guard preferences.hudEnabled else {
            if isRunning {
                isRunning = false
                addresses = []
                server.stop()
            }
            return
        }
        addresses = HUDServer.localAddresses()
        isRunning = true
        server.start(
            settings: HUDServerSettings(
                port: UInt16(clamping: preferences.hudPort),
                allowsLAN: preferences.hudAllowsLAN,
                token: preferences.hudToken()
            )
        )
    }

    private func publish(preferences: AppPreferences, snapshots: [ProviderSnapshot]) {
        let language = preferences.language
        let providers = preferences.visibleProviderOrder.compactMap { id -> HUDProvider? in
            guard let snapshot = snapshots.first(where: { $0.id == id }) else { return nil }
            let ordered = QuotaWindowSelector.ordered(snapshot.limits)
            let headlineLimit = QuotaWindowSelector.primary(
                in: snapshot.limits,
                preference: preferences.quotaWindow
            )
            let percent = headlineLimit.map { Int($0.clampedRemaining.rounded()) }
            let headline = MenuBarSummary.value(
                snapshot: snapshot,
                preference: preferences.quotaWindow
            ) ?? "—"
            return HUDProvider(
                id: id.rawValue,
                title: id.title,
                accent: id.accentHex,
                state: snapshot.activity.rawValue,
                stateLabel: snapshot.activity.label(language: language),
                isActive: snapshot.activity.isActive,
                headline: headline,
                percent: headline.hasSuffix("%") ? percent : nil,
                detail: snapshot.detail,
                limits: ordered.map { limit in
                    HUDLimit(
                        label: limit.label,
                        remainingPercent: Int(limit.clampedRemaining.rounded()),
                        resetAt: limit.resetAt,
                        resetText: limit.resetText(language: language)
                    )
                },
                updatedAt: snapshot.lastUpdated
            )
        }

        server.update(
            payload: HUDPayload(
                version: AppVersion.short,
                host: ProcessInfo.processInfo.hostName,
                language: language.rawValue,
                quotaWindow: preferences.quotaWindow.rawValue,
                lowQuotaThreshold: preferences.lowQuotaThreshold,
                providers: providers
            )
        )
    }
}
