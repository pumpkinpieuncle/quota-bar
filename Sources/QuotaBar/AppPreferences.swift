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

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "appLanguage"
        static let refreshMode = "refreshMode"
        static let customRefreshSeconds = "customRefreshSeconds"
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
    }
}
