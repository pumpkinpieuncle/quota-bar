import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var refreshMode: RefreshMode {
        didSet { defaults.set(refreshMode.rawValue, forKey: Keys.refreshMode) }
    }

    @Published var customRefreshSeconds: Int {
        didSet {
            defaults.set(customRefreshSeconds, forKey: Keys.customRefreshSeconds)
        }
    }

    @Published var quotaWindow: QuotaWindowPreference {
        didSet { defaults.set(quotaWindow.rawValue, forKey: Keys.quotaWindow) }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            defaults.set(
                menuBarDisplayMode.rawValue,
                forKey: Keys.menuBarDisplayMode
            )
        }
    }

    @Published var panelLayout: PanelLayoutMode {
        didSet { defaults.set(panelLayout.rawValue, forKey: Keys.panelLayout) }
    }

    @Published var providerOrder: [ProviderID] {
        didSet {
            defaults.set(providerOrder.map(\.rawValue), forKey: Keys.providerOrder)
        }
    }

    @Published var hiddenProviders: Set<ProviderID> {
        didSet {
            defaults.set(
                hiddenProviders.map(\.rawValue).sorted(),
                forKey: Keys.hiddenProviders
            )
        }
    }

    @Published var pausedProviders: Set<ProviderID> {
        didSet {
            defaults.set(
                pausedProviders.map(\.rawValue).sorted(),
                forKey: Keys.pausedProviders
            )
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "appLanguage"
        static let refreshMode = "refreshMode"
        static let customRefreshSeconds = "customRefreshSeconds"
        static let quotaWindow = "quotaWindow"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let panelLayout = "panelLayout"
        static let providerOrder = "providerOrder"
        static let hiddenProviders = "hiddenProviders"
        static let pausedProviders = "pausedProviders"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let raw = defaults.string(forKey: Keys.language),
            let saved = AppLanguage(rawValue: raw)
        {
            language = saved
        } else {
            language = Locale.preferredLanguages.first?.hasPrefix("zh") == true
                ? .chinese
                : .english
        }

        if
            let raw = defaults.string(forKey: Keys.refreshMode),
            let saved = RefreshMode(rawValue: raw)
        {
            refreshMode = saved
        } else {
            refreshMode = .smart
        }

        let savedSeconds = defaults.integer(forKey: Keys.customRefreshSeconds)
        customRefreshSeconds = savedSeconds == 0
            ? 120
            : min(max(savedSeconds, 10), 86_400)

        if
            let raw = defaults.string(forKey: Keys.quotaWindow),
            let saved = QuotaWindowPreference(rawValue: raw)
        {
            quotaWindow = saved
        } else {
            quotaWindow = .fiveHour
        }

        if
            let raw = defaults.string(forKey: Keys.menuBarDisplayMode),
            let saved = MenuBarDisplayMode(rawValue: raw)
        {
            menuBarDisplayMode = saved
        } else {
            menuBarDisplayMode = .automatic
        }

        if
            let raw = defaults.string(forKey: Keys.panelLayout),
            let saved = PanelLayoutMode(rawValue: raw)
        {
            panelLayout = saved
        } else {
            panelLayout = .standard
        }

        let savedOrder = (defaults.stringArray(forKey: Keys.providerOrder) ?? [])
            .compactMap(ProviderID.init(rawValue:))
        providerOrder = savedOrder
            + ProviderID.allCases.filter { !savedOrder.contains($0) }

        if defaults.object(forKey: Keys.hiddenProviders) != nil {
            hiddenProviders = Set(
                (defaults.stringArray(forKey: Keys.hiddenProviders) ?? [])
                    .compactMap(ProviderID.init(rawValue:))
            )
        } else {
            hiddenProviders = [.deepseek]
        }

        pausedProviders = Set(
            (defaults.stringArray(forKey: Keys.pausedProviders) ?? [])
                .compactMap(ProviderID.init(rawValue:))
        )
    }

    var visibleProviderOrder: [ProviderID] {
        providerOrder.filter { !hiddenProviders.contains($0) }
    }

    func setProvider(_ provider: ProviderID, hidden: Bool) {
        var next = hiddenProviders
        if hidden {
            guard visibleProviderOrder.count > 1 else { return }
            next.insert(provider)
        } else {
            next.remove(provider)
        }
        hiddenProviders = next
    }

    func moveProvider(_ provider: ProviderID, offset: Int) {
        guard
            let oldIndex = providerOrder.firstIndex(of: provider),
            providerOrder.indices.contains(oldIndex + offset)
        else {
            return
        }
        var next = providerOrder
        next.swapAt(oldIndex, oldIndex + offset)
        providerOrder = next
    }

    func setProvider(_ provider: ProviderID, paused: Bool) {
        var next = pausedProviders
        if paused {
            next.insert(provider)
        } else {
            next.remove(provider)
        }
        pausedProviders = next
    }
}
