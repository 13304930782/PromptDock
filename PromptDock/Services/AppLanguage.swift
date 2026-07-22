import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    static let storageKey = "appLanguage"

    var id: Self { self }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system:
            "Follow System"
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        }
    }

    var usesChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    func text(english: String, chinese: String) -> String {
        usesChinese ? chinese : english
    }
}
