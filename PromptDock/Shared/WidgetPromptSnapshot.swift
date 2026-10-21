import Foundation

struct WidgetPromptSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let updatedDate: Date
    let isFavorite: Bool
}

private final class BuiltInCategoryBundleToken: NSObject {}

enum BuiltInCategoryPresentation {
    private static let localizationBundle = Bundle(
        for: BuiltInCategoryBundleToken.self
    )

    private static func localizedString(
        for key: String,
        locale: Locale
    ) -> String {
        let preferredLocalizations = Bundle.preferredLocalizations(
            from: localizationBundle.localizations,
            forPreferences: [locale.identifier]
        )

        guard
            let localization = preferredLocalizations.first,
            let path = localizationBundle.path(
                forResource: localization,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return key
        }

        return bundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    static func displayName(
        for categoryName: String,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        switch categoryName {
        case "Teaching":
            localizedString(for: "Teaching", locale: locale)
        case "Coding":
            localizedString(for: "Coding", locale: locale)
        case "AI":
            localizedString(for: "AI", locale: locale)
        case "Writing":
            localizedString(for: "Writing", locale: locale)
        case "Uncategorized":
            localizedString(for: "Uncategorized", locale: locale)
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
        guard !AppEnvironment.isTesting else { return }
        try WidgetSnapshotStore(
            appGroupIdentifier: appGroupIdentifier
        ).save(snapshots)
    }

    static func load() throws -> [WidgetPromptSnapshot] {
        guard !AppEnvironment.isTesting else { return [] }
        return try WidgetSnapshotStore(
            appGroupIdentifier: appGroupIdentifier
        ).load()
    }
}

/// Shared by the app and extension. No container lookup is performed here.
enum AppEnvironment {
    static var isTesting: Bool {
        isTesting(environment: ProcessInfo.processInfo.environment)
    }

    static func isTesting(environment: [String: String]) -> Bool {
        environment["PROMPTDOCK_TESTING"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    static var keychainService: String {
        #if DEBUG
        "com.promptdock.PromptDock.Dev.ai-api-key"
        #else
        "com.promptdock.PromptDock.ai-api-key"
        #endif
    }
}


/// Shared app/Widget usage metadata; never part of a library backup.
struct RecentUsageStore {
    struct Entry: Codable, Equatable { let id: UUID; let usedAt: Date }
    let fileURL: URL
    func load() throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: fileURL))
    }
    static func recording(_ id: UUID, at date: Date, in entries: [Entry]) -> [Entry] {
        Array(([Entry(id: id, usedAt: date)] + entries.filter { $0.id != id }).prefix(100))
    }
    func record(_ id: UUID, at date: Date = .now) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            do {
                let store = RecentUsageStore(fileURL: url)
                let entries = Self.recording(id, at: date, in: try store.load())
                try JSONEncoder().encode(entries).write(to: url, options: .atomic)
            } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError as NSError? { throw error }
    }
}

@MainActor
enum RecentUsage {
    // Stop accessing the container after failure for this process lifetime.
    private(set) static var lastError: Error?
    private static func store() throws -> RecentUsageStore {
        let snapshot = try WidgetSnapshotStore(appGroupIdentifier: WidgetSharedStore.appGroupIdentifier)
        return RecentUsageStore(fileURL: snapshot.fileURL.deletingLastPathComponent().appendingPathComponent("recent-usage.json"))
    }
    static func retry() { lastError = nil; _ = ids() }
    static func ids() -> [UUID] {
        guard !AppEnvironment.isTesting, lastError == nil else { return [] }
        do { return try store().load().map(\.id) }
        catch { lastError = error; return [] }
    }
    static func record(_ id: UUID) {
        guard !AppEnvironment.isTesting, lastError == nil else { return }
        do { try store().record(id) }
        catch { lastError = error }
    }
}
