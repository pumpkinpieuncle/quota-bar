import ServiceManagement

/// Thin wrapper around `SMAppService` so the settings toggle only deals with
/// a Bool and an optional error message.
///
/// `SMAppService.mainApp` keeps the registration in the system's login items,
/// so it survives reinstalls of the app at the same bundle identifier and the
/// status query is the single source of truth — no UserDefaults needed.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns `nil` on success, or a human-readable error description.
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return nil }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status != .notRegistered else { return nil }
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
