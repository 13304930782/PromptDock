import Foundation

struct WidgetPromptSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let updatedDate: Date
    let isFavorite: Bool
}

enum WidgetSharedStore {
    // macOS supports Team-ID-prefixed groups without Developer Portal
    // registration, so this also works with a free Personal Team profile.
    static let appGroupIdentifier = "L96B6KHL5Y.PromptDock"
    static let widgetKind = "PromptDockWidget"
    static let snapshotKey = "widgetPromptSnapshots"

    private static let snapshotDirectoryName = "WidgetSnapshots"
    private static let snapshotFileName = "prompts.json"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func save(_ snapshots: [WidgetPromptSnapshot]) throws {
        let data = try JSONEncoder().encode(snapshots)

        // Keep UserDefaults for compatibility with existing installations, but
        // use an App Group file as the primary cross-process transport. A file
        // avoids stale cfprefsd values when WidgetKit launches the extension in
        // a process that was already alive before the host app refreshed data.
        sharedDefaults.set(data, forKey: snapshotKey)
        try saveSnapshotFile(data)
    }

    static func load() -> [WidgetPromptSnapshot] {
        if let fileURL = snapshotFileURL,
           let data = try? Data(contentsOf: fileURL),
           let snapshots = decode(data) {
            return snapshots
        }

        return load(from: sharedDefaults)
    }

    // These overloads keep persistence tests isolated from the real App Group.
    static func save(
        _ snapshots: [WidgetPromptSnapshot],
        to defaults: UserDefaults
    ) throws {
        defaults.set(try JSONEncoder().encode(snapshots), forKey: snapshotKey)
    }

    static func load(from defaults: UserDefaults) -> [WidgetPromptSnapshot] {
        guard let data = defaults.data(forKey: snapshotKey) else { return [] }
        return decode(data) ?? []
    }

    private static var snapshotFileURL: URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )?
            .appendingPathComponent(snapshotDirectoryName, isDirectory: true)
            .appendingPathComponent(snapshotFileName, isDirectory: false)
    }

    private static func saveSnapshotFile(_ data: Data) throws {
        guard let fileURL = snapshotFileURL else { return }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    private static func decode(
        _ data: Data
    ) -> [WidgetPromptSnapshot]? {
        try? JSONDecoder().decode([WidgetPromptSnapshot].self, from: data)
    }
}
