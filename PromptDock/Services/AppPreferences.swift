import Foundation
import ServiceManagement

enum AppPreferences {
    static let showMenuBar = "preferences.showMenuBar"
    static let launchAtLogin = "preferences.launchAtLogin"
    static let globalQuickSearchEnabled = "preferences.globalQuickSearchEnabled"
    static let globalQuickSearchHotKey = "preferences.globalQuickSearchHotKey"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBar: true,
            launchAtLogin: false,
            globalQuickSearchEnabled: true
        ])
    }

    static var selectedLanguage: AppLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(
                forKey: AppLanguage.storageKey
            ) else { return .system }
            return AppLanguage(rawValue: rawValue) ?? .system
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: AppLanguage.storageKey
            )
        }
    }

    static var isMenuBarVisible: Bool {
        get { UserDefaults.standard.bool(forKey: showMenuBar) }
        set { UserDefaults.standard.set(newValue, forKey: showMenuBar) }
    }

    static var isLaunchAtLoginEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: launchAtLogin) }
        set { UserDefaults.standard.set(newValue, forKey: launchAtLogin) }
    }

    static var isGlobalQuickSearchEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: globalQuickSearchEnabled)
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: globalQuickSearchEnabled
            )
        }
    }

    static func loadGlobalQuickSearchHotKey() -> HotKeyCombination? {
        guard let data = UserDefaults.standard.data(
            forKey: globalQuickSearchHotKey
        ) else { return nil }
        return try? JSONDecoder().decode(
            HotKeyCombination.self,
            from: data
        )
    }

    static func saveGlobalQuickSearchHotKey(
        _ combination: HotKeyCombination
    ) throws {
        UserDefaults.standard.set(
            try JSONEncoder().encode(combination),
            forKey: globalQuickSearchHotKey
        )
    }
}

@MainActor
enum LoginItemService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
