import Foundation
import ServiceManagement

enum AppPreferences {
    static let showMenuBar = "preferences.showMenuBar"
    static let launchAtLogin = "preferences.launchAtLogin"
    static let globalQuickSearchEnabled = "preferences.globalQuickSearchEnabled"
    static let globalQuickSearchHotKey = "preferences.globalQuickSearchHotKey"
    static let aiTemplateAssistantEnabled =
        "preferences.aiTemplateAssistantEnabled"
    static let aiProvider = "preferences.aiProvider"
    static let aiDeepSeekModel = "preferences.aiDeepSeekModel"
    static let aiCustomBaseURL = "preferences.aiCustomBaseURL"
    static let aiCustomModel = "preferences.aiCustomModel"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBar: true,
            launchAtLogin: false,
            globalQuickSearchEnabled: true,
            aiTemplateAssistantEnabled: false,
            aiProvider: AIProviderKind.deepSeek.rawValue,
            aiDeepSeekModel:
                AIProviderConfiguration.defaultDeepSeekModel,
            aiCustomBaseURL: "",
            aiCustomModel: ""
        ])
    }

    static var isAITemplateAssistantEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: aiTemplateAssistantEnabled) }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: aiTemplateAssistantEnabled
            )
        }
    }

    static var selectedAIProvider: AIProviderKind {
        get {
            guard let rawValue = UserDefaults.standard.string(
                forKey: aiProvider
            ) else { return .deepSeek }
            return AIProviderKind(rawValue: rawValue) ?? .deepSeek
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: aiProvider)
        }
    }

    static var aiConfiguration: AIProviderConfiguration {
        switch selectedAIProvider {
        case .deepSeek:
            AIProviderConfiguration(
                provider: .deepSeek,
                baseURL: AIProviderConfiguration.deepSeekBaseURL,
                model: UserDefaults.standard.string(
                    forKey: aiDeepSeekModel
                ) ?? AIProviderConfiguration.defaultDeepSeekModel
            )
        case .custom:
            AIProviderConfiguration(
                provider: .custom,
                baseURL: UserDefaults.standard.string(
                    forKey: aiCustomBaseURL
                ) ?? "",
                model: UserDefaults.standard.string(
                    forKey: aiCustomModel
                ) ?? ""
            )
        }
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
