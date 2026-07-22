import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PromptDockBackup: Codable, Equatable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var createdAt: Date
    var appVersion: String
    var prompts: [PromptRecord]
    var categories: [CategoryRecord]

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
        guard backup.formatVersion == PromptDockBackup.currentFormatVersion else {
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

        var categoryNames = Set<String>()
        for category in backup.categories {
            let name = trimmed(category.name)
            guard !name.isEmpty, !category.systemImage.isEmpty else {
                throw BackupError.invalidCategory
            }
            guard categoryNames.insert(normalized(name)).inserted else {
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
            guard !trimmed(prompt.title).isEmpty,
                  !trimmed(prompt.category).isEmpty,
                  !trimmed(prompt.content).isEmpty
            else {
                throw BackupError.invalidPrompt
            }
        }
    }

    static func importBackup(
        _ backup: PromptDockBackup,
        mode: BackupImportMode,
        in context: ModelContext,
        createsSafetyBackup: Bool = true
    ) throws -> BackupImportResult {
        try validate(backup)

        let safetyBackupURL: URL?
        if mode == .replace, createsSafetyBackup {
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
            try context.save()
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
        for category in categories where categoriesByName[normalized(category.name)] == nil {
            categoriesByName[normalized(category.name)] = category
        }

        for record in backup.categories {
            let nameKey = normalized(record.name)
            let target = categoriesByID[record.id] ?? categoriesByName[nameKey]
            if let target {
                let nameOwner = categoriesByName[nameKey]
                if nameOwner == nil || nameOwner?.id == target.id {
                    categoriesByName.removeValue(forKey: normalized(target.name))
                    target.name = trimmed(record.name)
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

        insertMissingCategories(for: prompts, categories: &categories, in: context)
        insertDefaultCategoriesIfEmpty(&categories, in: context)
        normalizeSortOrder(categories)
    }

    private static func replace(
        with backup: PromptDockBackup,
        in context: ModelContext
    ) throws {
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
        insertDefaultCategoriesIfEmpty(&categories, in: context)
        normalizeSortOrder(categories)
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
        var names = Set(categories.map { normalized($0.name) })
        var nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1

        for prompt in prompts {
            let name = trimmed(prompt.category)
            guard names.insert(normalized(name)).inserted else { continue }
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
            title: trimmed(record.title),
            category: trimmed(record.category),
            content: trimmed(record.content),
            createdDate: record.createdDate,
            updatedDate: record.updatedDate,
            isFavorite: record.isFavorite
        )
    }

    private static func apply(
        _ record: PromptDockBackup.PromptRecord,
        to prompt: Prompt
    ) {
        prompt.title = trimmed(record.title)
        prompt.category = trimmed(record.category)
        prompt.content = trimmed(record.content)
        prompt.createdDate = record.createdDate
        prompt.updatedDate = record.updatedDate
        prompt.isFavorite = record.isFavorite
    }

    private static func makeCategory(
        from record: PromptDockBackup.CategoryRecord
    ) -> PromptCategory {
        PromptCategory(
            id: record.id,
            name: trimmed(record.name),
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

    private nonisolated static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func normalized(_ value: String) -> String {
        trimmed(value).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
