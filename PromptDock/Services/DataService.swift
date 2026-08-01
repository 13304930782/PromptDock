import Foundation
import SwiftData

enum PromptDockSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Prompt.self, PromptCategory.self]
    }
}

enum PromptDockMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PromptDockSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // Add a new VersionedSchema and an explicit MigrationStage before
        // changing persisted model fields. V1 intentionally needs no stage.
        []
    }
}

enum DataService {
    static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PromptDockSchemaV1.self)
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                "PromptDock",
                schema: schema,
                url: storeURL
            )
        } else if isStoredInMemoryOnly {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            let storeURL = try persistentStoreURL()
            configuration = ModelConfiguration(
                "PromptDock",
                schema: schema,
                url: storeURL
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: PromptDockMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func dataDirectoryURLIfAvailable() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier:
                WidgetSharedStore.appGroupIdentifier
        ) else {
            return nil
        }
        return containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
    }

    private static func persistentStoreURL() throws -> URL {
        guard let applicationSupportURL = dataDirectoryURLIfAvailable() else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [
                    NSFilePathErrorKey: WidgetSharedStore.appGroupIdentifier
                ]
            )
        }

        try FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )

        return applicationSupportURL
            .appendingPathComponent("default.store", isDirectory: false)
    }
}
