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
        []
    }
}

enum DataService {
    // Keep app data and widget snapshots in the same Team-ID App Group.
    // This form is supported by macOS without a separately registered
    // portal App Group and works with a Personal Team.
    private static let dataContainerIdentifier =
        "L96B6KHL5Y.PromptDock"

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

    private static func persistentStoreURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: dataContainerIdentifier
        ) else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [
                    NSFilePathErrorKey: dataContainerIdentifier
                ]
            )
        }

        let applicationSupportURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        try FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )

        return applicationSupportURL
            .appendingPathComponent("default.store", isDirectory: false)
    }
}
