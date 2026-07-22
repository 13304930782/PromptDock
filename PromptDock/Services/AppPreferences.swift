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
