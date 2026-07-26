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

    @Published var panelLayout: PanelLayoutMode {
        didSet { defaults.set(panelLayout.rawValue, forKey: Keys.panelLayout) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "appLanguage"
        static let refreshMode = "refreshMode"
        static let customRefreshSeconds = "customRefreshSeconds"
        static let quotaWindow = "quotaWindow"
        static let panelLayout = "panelLayout"
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
            : min(max(savedSeconds, 10), 3_600)

        if
            let raw = defaults.string(forKey: Keys.quotaWindow),
            let saved = QuotaWindowPreference(rawValue: raw)
        {
            quotaWindow = saved
        } else {
            quotaWindow = .fiveHour
        }

        if
            let raw = defaults.string(forKey: Keys.panelLayout),
            let saved = PanelLayoutMode(rawValue: raw)
        {
            panelLayout = saved
        } else {
            panelLayout = .standard
        }
    }
}
