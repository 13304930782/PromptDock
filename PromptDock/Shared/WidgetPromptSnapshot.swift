import Foundation

struct WidgetPromptSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let updatedDate: Date
    let isFavorite: Bool
}

enum BuiltInCategoryPresentation {
    static func displayName(
        for categoryName: String,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        switch categoryName {
        case "Teaching":
            String(localized: "Teaching", locale: locale)
        case "Coding":
            String(localized: "Coding", locale: locale)
        case "AI":
            String(localized: "AI", locale: locale)
        case "Writing":
            String(localized: "Writing", locale: locale)
        case "Uncategorized":
            String(localized: "Uncategorized", locale: locale)
        default:
            categoryName
        }
    }
}

enum WidgetSnapshotStoreError: LocalizedError {
    case missingAppGroupIdentifier
    case unavailableContainer(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroupIdentifier:
            "PromptDock is missing its App Group configuration."
        case .unavailableContainer(let identifier):
            "PromptDock could not open the App Group container \(identifier)."
        }
    }
}

struct WidgetSnapshotStore {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(appGroupIdentifier: String) throws {
        guard !appGroupIdentifier.isEmpty,
              !appGroupIdentifier.contains("$(")
        else {
            throw WidgetSnapshotStoreError.missingAppGroupIdentifier
        }
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw WidgetSnapshotStoreError.unavailableContainer(
                appGroupIdentifier
            )
        }
        fileURL = containerURL
            .appendingPathComponent("WidgetSnapshots", isDirectory: true)
            .appendingPathComponent("prompts.json", isDirectory: false)
    }

    func save(_ snapshots: [WidgetPromptSnapshot]) throws {
        let data = try JSONEncoder().encode(snapshots)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> [WidgetPromptSnapshot] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        return try JSONDecoder().decode(
            [WidgetPromptSnapshot].self,
            from: Data(contentsOf: fileURL)
        )
    }
}

enum WidgetSharedStore {
    static var appGroupIdentifier: String {
        Bundle.main.object(
            forInfoDictionaryKey: "PromptDockAppGroupIdentifier"
        ) as? String ?? ""
    }
    static let widgetKind = "PromptDockWidget"

    static func save(_ snapshots: [WidgetPromptSnapshot]) throws {
        try WidgetSnapshotStore(
            appGroupIdentifier: appGroupIdentifier
        ).save(snapshots)
    }

    static func load() throws -> [WidgetPromptSnapshot] {
        try WidgetSnapshotStore(
            appGroupIdentifier: appGroupIdentifier
        ).load()
    }
}
