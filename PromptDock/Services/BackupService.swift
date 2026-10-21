import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PromptDockBackup: Codable, Equatable {
    static let currentFormatVersion = 3

    enum Kind: String, Codable { case full, content }
    var kind: Kind = .full
    var formatVersion: Int
    var createdAt: Date
    var appVersion: String
    var prompts: [PromptRecord]
    var categories: [CategoryRecord]
    var versions: [VersionRecord] = []
    var tags: [TagRecord] = []
    var smartCollections: [SmartCollectionRecord] = []
    var variableDefinitions: [VariableDefinitionRecord] = []
    var trash: [TrashRecord] = []

    struct TrashRecord: Codable, Equatable {
        var promptID: UUID
        var deletedAt: Date
    }

    struct PromptRecord: Codable, Equatable {
        var id: UUID
        var title: String
        var category: String
        var content: String
        var createdDate: Date
        var updatedDate: Date
        var isFavorite: Bool
    }

    struct CategoryRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var systemImage: String
        var sortOrder: Int
        var createdDate: Date
        var isBuiltIn: Bool
        var iconKind: CategoryIconKind
        var iconEmoji: String?
        var iconImageData: Data?
    }

    struct VersionRecord: Codable, Equatable {
        var id: UUID
        var promptID: UUID
        var title: String
        var category: String
        var content: String
        var createdAt: Date
    }

    struct TagRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var color: PromptTagColor
        var promptIDs: [UUID]
        var createdAt: Date
    }

    struct SmartCollectionRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var query: String
        var category: String?
        var tagIDs: [UUID]
        var favoriteOnly: Bool
        var updatedWithinDays: Int?
        var matchAll: Bool
        var createdAt: Date
    }

    struct VariableDefinitionRecord: Codable, Equatable {
        var id: UUID
        var promptID: UUID
        var name: String
        var label: String
        var defaultValue: String
        var order: Int
        var isRepeatable: Bool
    }

    var summary: BackupSummary {
        BackupSummary(
            promptCount: prompts.count,
            categoryCount: categories.count,
            createdAt: createdAt
        )
    }
}

struct BackupSummary: Equatable {
    let promptCount: Int
    let categoryCount: Int
    let createdAt: Date
}

enum BackupImportMode {
    case merge
    case replace
}

struct BackupImportResult: Equatable {
    let promptCount: Int
    let categoryCount: Int
    let safetyBackupURL: URL?
}

enum BackupError: LocalizedError {
    case fileTooLarge
    case unsupportedVersion(Int)
    case tooManyItems
    case duplicatePromptID
    case duplicateCategoryID
    case duplicateCategoryName(String)
    case invalidPrompt
    case invalidCategory
    case invalidEmoji(String)
    case invalidImage(String)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            String(localized: "The backup is larger than 100 MB.")
        case .unsupportedVersion(let version):
            String(
                localized: "This backup uses unsupported format version \(version)."
            )
        case .tooManyItems:
            String(
                localized: "The backup contains more items than PromptDock can safely import."
            )
        case .duplicatePromptID:
            String(localized: "The backup contains duplicate prompt identifiers.")
        case .duplicateCategoryID:
            String(localized: "The backup contains duplicate category identifiers.")
        case .duplicateCategoryName(let name):
            String(
                localized: "The backup contains more than one category named “\(name)”."
            )
        case .invalidPrompt:
            String(
                localized: "The backup contains a prompt with a missing title, category, or content."
            )
        case .invalidCategory:
            String(localized: "The backup contains an invalid category.")
        case .invalidEmoji(let name):
            String(
                localized: "The icon for “\(name)” is not a single emoji or character."
            )
        case .invalidImage(let name):
            String(
                localized: "The local image for “\(name)” is missing or invalid."
            )
        }
    }
}

struct PromptDockBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: PromptDockBackup

    init(backup: PromptDockBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = try BackupService.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try BackupService.encode(backup))
    }
}

@MainActor
enum BackupService {
    nonisolated static let maximumBackupByteCount = 100 * 1_024 * 1_024
    private nonisolated static let maximumPromptCount = 100_000
    private nonisolated static let maximumCategoryCount = 10_000

    static func makeBackup(in context: ModelContext) throws -> PromptDockBackup {
        let prompts = try context.fetch(
            FetchDescriptor<Prompt>(
                sortBy: [SortDescriptor(\Prompt.createdDate)]
            )
        )
        let categories = try context.fetch(
            FetchDescriptor<PromptCategory>(
                sortBy: [
                    SortDescriptor(\PromptCategory.sortOrder),
                    SortDescriptor(\PromptCategory.createdDate)
                ]
            )
        )
        let versions = try context.fetch(FetchDescriptor<PromptVersion>())
        let tags = try context.fetch(FetchDescriptor<PromptTag>())
        let smartCollections = try context.fetch(FetchDescriptor<SmartCollection>())
        let variableDefinitions = try context.fetch(
            FetchDescriptor<TemplateVariableDefinition>(
                sortBy: [SortDescriptor(\TemplateVariableDefinition.order)]
            )
        )

        return PromptDockBackup(
            formatVersion: PromptDockBackup.currentFormatVersion,
            createdAt: .now,
            appVersion: appVersion,
            prompts: prompts.map {
                PromptDockBackup.PromptRecord(
                    id: $0.id,
                    title: $0.title,
                    category: $0.category,
                    content: $0.content,
                    createdDate: $0.createdDate,
                    updatedDate: $0.updatedDate,
                    isFavorite: $0.isFavorite
                )
            },
            categories: categories.map {
                PromptDockBackup.CategoryRecord(
                    id: $0.id,
                    name: $0.name,
                    systemImage: $0.systemImage,
                    sortOrder: $0.sortOrder,
                    createdDate: $0.createdDate,
                    isBuiltIn: $0.isBuiltIn,
                    iconKind: $0.iconKind,
                    iconEmoji: $0.iconEmoji,
                    iconImageData: $0.iconImageData
                )
            },
            versions: versions.map {
                PromptDockBackup.VersionRecord(
                    id: $0.id,
                    promptID: $0.promptID,
                    title: $0.title,
                    category: $0.category,
                    content: $0.content,
                    createdAt: $0.createdAt
                )
            },
            tags: tags.map {
                PromptDockBackup.TagRecord(
                    id: $0.id,
                    name: $0.name,
                    color: $0.color,
                    promptIDs: $0.promptIDs,
                    createdAt: $0.createdAt
                )
            },
            smartCollections: smartCollections.map {
                PromptDockBackup.SmartCollectionRecord(
                    id: $0.id,
                    name: $0.name,
                    query: $0.query,
                    category: $0.category,
                    tagIDs: $0.tagIDs,
                    favoriteOnly: $0.favoriteOnly,
                    updatedWithinDays: $0.updatedWithinDays,
                    matchAll: $0.matchAll,
                    createdAt: $0.createdAt
                )
            },
            variableDefinitions: variableDefinitions.map {
                PromptDockBackup.VariableDefinitionRecord(
                    id: $0.id,
                    promptID: $0.promptID,
                    name: $0.name,
                    label: $0.label,
                    defaultValue: $0.defaultValue,
                    order: $0.order,
                    isRepeatable: $0.isRepeatable
                )
            },
            trash: try context.fetch(FetchDescriptor<TrashEntry>()).map {
                PromptDockBackup.TrashRecord(promptID: $0.promptID, deletedAt: $0.deletedAt)
            }
        )
    }

    nonisolated static func encode(_ backup: PromptDockBackup) throws -> Data {
        try validate(backup)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(backup)
    }

    nonisolated static func decode(_ data: Data) throws -> PromptDockBackup {
        guard data.count <= maximumBackupByteCount else {
            throw BackupError.fileTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let backup = try decoder.decode(PromptDockBackup.self, from: data)
        try validate(backup)
        return backup
    }

    nonisolated static func validate(_ backup: PromptDockBackup) throws {
        guard (1...PromptDockBackup.currentFormatVersion).contains(backup.formatVersion) else {
            throw BackupError.unsupportedVersion(backup.formatVersion)
        }
        guard backup.prompts.count <= maximumPromptCount,
              backup.categories.count <= maximumCategoryCount
        else {
            throw BackupError.tooManyItems
        }
        guard Set(backup.prompts.map(\.id)).count == backup.prompts.count else {
            throw BackupError.duplicatePromptID
        }
        guard Set(backup.categories.map(\.id)).count == backup.categories.count else {
            throw BackupError.duplicateCategoryID
        }
        guard Set(backup.versions.map(\.id)).count == backup.versions.count,
              Set(backup.tags.map(\.id)).count == backup.tags.count,
              Set(backup.smartCollections.map(\.id)).count == backup.smartCollections.count,
              Set(backup.variableDefinitions.map(\.id)).count == backup.variableDefinitions.count
        else {
            throw BackupError.tooManyItems
        }

        let promptIDs = Set(backup.prompts.map(\.id))
        guard Set(backup.trash.map(\.promptID)).count == backup.trash.count,
              backup.trash.allSatisfy({ promptIDs.contains($0.promptID) }) else {
            throw BackupError.invalidPrompt
        }

        var categoryNames = Set<String>()
        for category in backup.categories {
            let name = CategoryNameIdentity.trimmed(category.name)
            guard !name.isEmpty, !category.systemImage.isEmpty else {
                throw BackupError.invalidCategory
            }
            guard categoryNames.insert(CategoryNameIdentity.normalized(name)).inserted else {
                throw BackupError.duplicateCategoryName(name)
            }

            switch category.iconKind {
            case .sfSymbol:
                break
            case .emoji:
                guard let emoji = category.iconEmoji,
                      emoji.count == 1
                else {
                    throw BackupError.invalidEmoji(name)
                }
            case .localImage:
                guard let data = category.iconImageData,
                      !data.isEmpty,
                      data.count <= CategoryImageProcessor.maximumSourceByteCount,
                      let source = CGImageSourceCreateWithData(
                        data as CFData,
                        nil
                      ),
                      CGImageSourceGetCount(source) > 0
                else {
                    throw BackupError.invalidImage(name)
                }
            }
        }

        for prompt in backup.prompts {
            guard !CategoryNameIdentity.trimmed(prompt.title).isEmpty,
                  !CategoryNameIdentity.trimmed(prompt.category).isEmpty,
                  !CategoryNameIdentity.trimmed(prompt.content).isEmpty
            else {
                throw BackupError.invalidPrompt
            }
        }
    }

    static func importBackup(
        _ backup: PromptDockBackup,
        mode: BackupImportMode,
        in context: ModelContext,
        createsSafetyBackup: Bool = !AppEnvironment.isTesting,
        persist: @MainActor (ModelContext) throws -> Void = { try LibraryPersistence.save($0) }
    ) throws -> BackupImportResult {
        try validate(backup)
        guard mode != .replace || backup.kind == .full else { throw TransferError.invalid("Only complete backups may replace the library.") }

        let safetyBackupURL: URL?
        if mode == .replace, createsSafetyBackup || !AppEnvironment.isTesting {
            safetyBackupURL = try writeSafetyBackup(in: context)
        } else {
            safetyBackupURL = nil
        }

        do {
            switch mode {
            case .merge:
                try merge(backup, in: context)
            case .replace:
                try replace(with: backup, in: context)
            }
            try mergePhase1Records(backup, in: context)
            let existingTrash = Set(try context.fetch(FetchDescriptor<TrashEntry>()).map(\.promptID))
            for entry in backup.trash where !existingTrash.contains(entry.promptID) {
                context.insert(TrashEntry(promptID: entry.promptID, deletedAt: entry.deletedAt))
            }
            try persist(context)
        } catch {
            context.rollback()
            throw error
        }

        return BackupImportResult(
            promptCount: backup.prompts.count,
            categoryCount: backup.categories.count,
            safetyBackupURL: safetyBackupURL
        )
    }

    private static func merge(
        _ backup: PromptDockBackup,
        in context: ModelContext
    ) throws {
        var prompts = try context.fetch(FetchDescriptor<Prompt>())
        var categories = try context.fetch(FetchDescriptor<PromptCategory>())

        var promptsByID = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0) })
        var categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var categoriesByName: [String: PromptCategory] = [:]
        for category in categories
        where categoriesByName[CategoryNameIdentity.normalized(category.name)] == nil {
            categoriesByName[CategoryNameIdentity.normalized(category.name)] = category
        }

        for record in backup.categories {
            let nameKey = CategoryNameIdentity.normalized(record.name)
            let target = categoriesByID[record.id] ?? categoriesByName[nameKey]
            if let target {
                let nameOwner = categoriesByName[nameKey]
                if nameOwner == nil || nameOwner?.id == target.id {
                    categoriesByName.removeValue(
                        forKey: CategoryNameIdentity.normalized(target.name)
                    )
                    target.name = CategoryNameIdentity.trimmed(record.name)
                    categoriesByName[nameKey] = target
                }
                apply(record, to: target)
                categoriesByID[target.id] = target
            } else {
                let category = makeCategory(from: record)
                context.insert(category)
                categories.append(category)
                categoriesByID[category.id] = category
                categoriesByName[nameKey] = category
            }
        }

        for record in backup.prompts {
            if let prompt = promptsByID[record.id] {
                apply(record, to: prompt)
            } else {
                let prompt = makePrompt(from: record)
                context.insert(prompt)
                prompts.append(prompt)
                promptsByID[prompt.id] = prompt
            }
        }

        canonicalizePromptCategories(prompts, using: categories)
        insertMissingCategories(for: prompts, categories: &categories, in: context)
        insertDefaultCategoriesIfEmpty(&categories, in: context)
        normalizeSortOrder(categories)
    }

    private static func replace(
        with backup: PromptDockBackup,
        in context: ModelContext
    ) throws {
        for entry in try context.fetch(FetchDescriptor<TrashEntry>()) { context.delete(entry) }
        for version in try context.fetch(FetchDescriptor<PromptVersion>()) {
            context.delete(version)
        }
        for tag in try context.fetch(FetchDescriptor<PromptTag>()) {
            context.delete(tag)
        }
        for collection in try context.fetch(FetchDescriptor<SmartCollection>()) {
            context.delete(collection)
        }
        for definition in try context.fetch(FetchDescriptor<TemplateVariableDefinition>()) {
            context.delete(definition)
        }
        for prompt in try context.fetch(FetchDescriptor<Prompt>()) {
            context.delete(prompt)
        }
        for category in try context.fetch(FetchDescriptor<PromptCategory>()) {
            context.delete(category)
        }

        var categories = backup.categories.map(makeCategory)
        let prompts = backup.prompts.map(makePrompt)
        categories.forEach(context.insert)
        prompts.forEach(context.insert)
        insertMissingCategories(for: prompts, categories: &categories, in: context)
    }

    private static func mergePhase1Records(
        _ backup: PromptDockBackup,
        in context: ModelContext
    ) throws {
        let existingVersions = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<PromptVersion>()).map { ($0.id, $0) }
        )
        for record in backup.versions where existingVersions[record.id] == nil {
            context.insert(PromptVersion(
                id: record.id,
                promptID: record.promptID,
                title: record.title,
                category: record.category,
                content: record.content,
                createdAt: record.createdAt
            ))
        }

        let existingTags = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<PromptTag>()).map { ($0.id, $0) }
        )
        for record in backup.tags {
            if let tag = existingTags[record.id] {
                tag.name = record.name
                tag.color = record.color
                tag.promptIDs = record.promptIDs
            } else {
                context.insert(PromptTag(
                    id: record.id,
                    name: record.name,
                    color: record.color,
                    promptIDs: record.promptIDs,
                    createdAt: record.createdAt
                ))
            }
        }

        let existingCollections = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<SmartCollection>()).map { ($0.id, $0) }
        )
        for record in backup.smartCollections {
            if let collection = existingCollections[record.id] {
                collection.name = record.name
                collection.query = record.query
                collection.category = record.category
                collection.tagIDs = record.tagIDs
                collection.favoriteOnly = record.favoriteOnly
                collection.updatedWithinDays = record.updatedWithinDays
                collection.matchAll = record.matchAll
            } else {
                context.insert(SmartCollection(
                    id: record.id,
                    name: record.name,
                    query: record.query,
                    category: record.category,
                    tagIDs: record.tagIDs,
                    favoriteOnly: record.favoriteOnly,
                    updatedWithinDays: record.updatedWithinDays,
                    matchAll: record.matchAll,
                    createdAt: record.createdAt
                ))
            }
        }

        let existingDefinitions = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<TemplateVariableDefinition>()).map { ($0.id, $0) }
        )
        for record in backup.variableDefinitions {
            if let definition = existingDefinitions[record.id] {
                definition.label = record.label
                definition.defaultValue = record.defaultValue
                definition.order = record.order
                definition.isRepeatable = record.isRepeatable
            } else {
                context.insert(TemplateVariableDefinition(
                    id: record.id,
                    promptID: record.promptID,
                    name: record.name,
                    label: record.label,
                    defaultValue: record.defaultValue,
                    order: record.order,
                    isRepeatable: record.isRepeatable
                ))
            }
        }
    }

    private static func writeSafetyBackup(in context: ModelContext) throws -> URL {
        let backup = try makeBackup(in: context)
        let data = try encode(backup)
        let fileManager = FileManager.default
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL
            .appendingPathComponent("PromptDock", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = directory.appendingPathComponent(
            "Before Import \(formatter.string(from: .now))-\(UUID().uuidString.prefix(8)).json"
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func insertMissingCategories(
        for prompts: [Prompt],
        categories: inout [PromptCategory],
        in context: ModelContext
    ) {
        var names = Set(categories.map { CategoryNameIdentity.normalized($0.name) })
        var nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1

        for prompt in prompts {
            let name = CategoryNameIdentity.trimmed(prompt.category)
            guard names.insert(CategoryNameIdentity.normalized(name)).inserted
            else { continue }
            let category = PromptCategory(
                name: name,
                sortOrder: nextOrder,
                iconKind: .emoji,
                iconEmoji: "📁"
            )
            nextOrder += 1
            context.insert(category)
            categories.append(category)
        }
    }

    private static func canonicalizePromptCategories(
        _ prompts: [Prompt],
        using categories: [PromptCategory]
    ) {
        let canonicalNames = categories.reduce(into: [String: String]()) {
            result, category in
            let key = CategoryNameIdentity.normalized(category.name)
            if result[key] == nil {
                result[key] = category.name
            }
        }

        for prompt in prompts {
            let key = CategoryNameIdentity.normalized(prompt.category)
            if let canonicalName = canonicalNames[key] {
                prompt.category = canonicalName
            }
        }
    }

    private static func normalizeSortOrder(_ categories: [PromptCategory]) {
        let ordered = categories.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            if $0.createdDate != $1.createdDate {
                return $0.createdDate < $1.createdDate
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
        }
    }

    private static func insertDefaultCategoriesIfEmpty(
        _ categories: inout [PromptCategory],
        in context: ModelContext
    ) {
        guard categories.isEmpty else { return }

        for (index, definition) in CategoryService.defaultCategories.enumerated() {
            let category = PromptCategory(
                name: definition.name,
                systemImage: definition.systemImage,
                sortOrder: index,
                isBuiltIn: true
            )
            context.insert(category)
            categories.append(category)
        }
    }

    private static func makePrompt(
        from record: PromptDockBackup.PromptRecord
    ) -> Prompt {
        Prompt(
            id: record.id,
            title: record.title,
            category: record.category,
            content: record.content,
            createdDate: record.createdDate,
            updatedDate: record.updatedDate,
            isFavorite: record.isFavorite
        )
    }

    private static func apply(
        _ record: PromptDockBackup.PromptRecord,
        to prompt: Prompt
    ) {
        prompt.title = CategoryNameIdentity.trimmed(record.title)
        prompt.category = CategoryNameIdentity.trimmed(record.category)
        prompt.content = record.content
        prompt.createdDate = record.createdDate
        prompt.updatedDate = record.updatedDate
        prompt.isFavorite = record.isFavorite
    }

    private static func makeCategory(
        from record: PromptDockBackup.CategoryRecord
    ) -> PromptCategory {
        PromptCategory(
            id: record.id,
            name: record.name,
            systemImage: record.systemImage,
            sortOrder: record.sortOrder,
            createdDate: record.createdDate,
            isBuiltIn: record.isBuiltIn,
            iconKind: record.iconKind,
            iconEmoji: record.iconEmoji,
            iconImageData: record.iconImageData
        )
    }

    private static func apply(
        _ record: PromptDockBackup.CategoryRecord,
        to category: PromptCategory
    ) {
        category.systemImage = record.systemImage
        category.sortOrder = record.sortOrder
        category.createdDate = record.createdDate
        category.isBuiltIn = category.isBuiltIn || record.isBuiltIn
        category.iconKind = record.iconKind
        category.iconEmoji = record.iconKind == .emoji ? record.iconEmoji : nil
        category.iconImageData = record.iconKind == .localImage
            ? record.iconImageData
            : nil
    }

    private nonisolated static var appVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

}


extension PromptDockBackup {
    enum CodingKeys: String, CodingKey {
        case kind, formatVersion, createdAt, appVersion, prompts, categories
        case versions, tags, smartCollections, variableDefinitions, trash
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .full
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        appVersion = try c.decode(String.self, forKey: .appVersion)
        prompts = try c.decode([PromptRecord].self, forKey: .prompts)
        categories = try c.decode([CategoryRecord].self, forKey: .categories)
        versions = try c.decodeIfPresent([VersionRecord].self, forKey: .versions) ?? []
        tags = try c.decodeIfPresent([TagRecord].self, forKey: .tags) ?? []
        smartCollections = try c.decodeIfPresent([SmartCollectionRecord].self, forKey: .smartCollections) ?? []
        variableDefinitions = try c.decodeIfPresent([VariableDefinitionRecord].self, forKey: .variableDefinitions) ?? []
        trash = try c.decodeIfPresent([TrashRecord].self, forKey: .trash) ?? []
    }
}

/// All application saves pass here; the independent context reads the last
/// committed state, not the pending edit that triggered the backup.
@MainActor
enum LibraryPersistence {
    static func save(_ context: ModelContext) throws {
        if !AppEnvironment.isTesting {
            AutomaticBackupService.shared.beforeSave(container: context.container)
        }
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
final class AutomaticBackupService: ObservableObject {
    static let shared = AutomaticBackupService()
    @Published private(set) var lastError: String?
    private var completedDay: Date?
    private let directory: URL
    private let defaults: UserDefaults

    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("PromptDock/AutomaticBackups"), defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
        self.completedDay = defaults.object(forKey: "automaticBackupCompletedDay") as? Date
    }

    var isEnabled: Bool {
        get { !defaults.bool(forKey: "automaticBackupsDisabled") }
        set { defaults.set(!newValue, forKey: "automaticBackupsDisabled") }
    }

    var directoryURL: URL { directory }

    func beforeSave(container: ModelContainer, now: Date = .now) {
        guard isEnabled, lastError == nil else { return }
        let day = Calendar.current.startOfDay(for: now)
        guard completedDay != day else { return }
        do { try backupNow(container: container, now: now) }
        catch { lastError = error.localizedDescription }
    }

    func backupNow(container: ModelContainer, now: Date = .now) throws {
        do {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let data = try BackupService.encode(BackupService.makeBackup(in: context))
            let fm = FileManager.default
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Automatic-\(now.timeIntervalSince1970)-\(UUID().uuidString).json")
            try data.write(to: url, options: .atomic)
            let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.lastPathComponent.hasPrefix("Automatic-") && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in files.dropFirst(7) { try fm.removeItem(at: old) }
            completedDay = Calendar.current.startOfDay(for: now)
            defaults.set(completedDay, forKey: "automaticBackupCompletedDay")
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
}
