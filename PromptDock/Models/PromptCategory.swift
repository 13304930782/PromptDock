import Foundation
import SwiftData
import SwiftUI

enum CategoryIconKind: String, Codable, CaseIterable {
    case sfSymbol
    case emoji
    case localImage
}

struct CategoryIconDraft {
    var kind: CategoryIconKind
    var emoji: String?
    var imageData: Data?

    static let defaultEmoji = CategoryIconDraft(
        kind: .emoji,
        emoji: "📁",
        imageData: nil
    )

    init(
        kind: CategoryIconKind,
        emoji: String? = nil,
        imageData: Data? = nil
    ) {
        self.kind = kind
        self.emoji = emoji
        self.imageData = imageData
    }

    init(category: PromptCategory) {
        kind = category.iconKind
        emoji = category.iconEmoji
        imageData = category.iconImageData
    }
}

@Model
final class PromptCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemImage: String
    var sortOrder: Int
    var createdDate: Date
    var isBuiltIn: Bool
    var iconKindRawValue: String = CategoryIconKind.sfSymbol.rawValue
    var iconEmoji: String?
    @Attribute(.externalStorage) var iconImageData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        systemImage: String = "folder",
        sortOrder: Int,
        createdDate: Date = .now,
        isBuiltIn: Bool = false,
        iconKind: CategoryIconKind = .sfSymbol,
        iconEmoji: String? = nil,
        iconImageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.sortOrder = sortOrder
        self.createdDate = createdDate
        self.isBuiltIn = isBuiltIn
        iconKindRawValue = iconKind.rawValue
        self.iconEmoji = iconEmoji
        self.iconImageData = iconImageData
    }

    var iconKind: CategoryIconKind {
        get {
            CategoryIconKind(rawValue: iconKindRawValue) ?? .sfSymbol
        }
        set {
            iconKindRawValue = newValue.rawValue
        }
    }
}

enum CategoryValidationError: LocalizedError {
    case missingName
    case duplicateName
    case builtInCategory

    var errorDescription: String? {
        switch self {
        case .missingName:
            String(localized: "Enter a category name.")
        case .duplicateName:
            String(localized: "A category with this name already exists.")
        case .builtInCategory:
            String(localized: "Built-in categories cannot be changed.")
        }
    }
}

@MainActor
enum CategoryService {
    struct DefaultCategory {
        let name: String
        let systemImage: String
    }

    static let defaultCategories: [DefaultCategory] = [
        DefaultCategory(name: "Teaching", systemImage: "graduationcap"),
        DefaultCategory(
            name: "Coding",
            systemImage: "chevron.left.forwardslash.chevron.right"
        ),
        DefaultCategory(name: "AI", systemImage: "sparkles"),
        DefaultCategory(name: "Writing", systemImage: "pencil.line")
    ]

    static func ensureCategories(
        for prompts: [Prompt],
        in context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<PromptCategory>())
        var knownNames = Set(existing.map { normalizedKey($0.name) })
        var nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        var insertedCategory = false

        for definition in defaultCategories {
            guard knownNames.insert(normalizedKey(definition.name)).inserted
            else { continue }

            context.insert(
                PromptCategory(
                    name: definition.name,
                    systemImage: definition.systemImage,
                    sortOrder: nextOrder,
                    isBuiltIn: true
                )
            )
            nextOrder += 1
            insertedCategory = true
        }

        for prompt in prompts {
            let name = prompt.category.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !name.isEmpty,
                  knownNames.insert(normalizedKey(name)).inserted
            else { continue }

            context.insert(
                PromptCategory(
                    name: name,
                    sortOrder: nextOrder
                )
            )
            nextOrder += 1
            insertedCategory = true
        }

        guard insertedCategory else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    static func createCategory(
        named proposedName: String,
        icon: CategoryIconDraft = .defaultEmoji,
        in context: ModelContext
    ) throws -> PromptCategory {
        let name = proposedName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty else {
            throw CategoryValidationError.missingName
        }

        let existing = try context.fetch(FetchDescriptor<PromptCategory>())
        guard !existing.contains(where: {
            normalizedKey($0.name) == normalizedKey(name)
        }) else {
            throw CategoryValidationError.duplicateName
        }

        let category = PromptCategory(
            name: name,
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1,
            iconKind: icon.kind,
            iconEmoji: icon.emoji,
            iconImageData: icon.imageData
        )
        context.insert(category)

        do {
            try context.save()
            return category
        } catch {
            context.rollback()
            throw error
        }
    }

    static func moveCategories(
        _ categories: [PromptCategory],
        from source: IndexSet,
        to destination: Int,
        in context: ModelContext
    ) throws {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    static func renameCategory(
        _ category: PromptCategory,
        to proposedName: String,
        icon: CategoryIconDraft? = nil,
        prompts: [Prompt],
        in context: ModelContext
    ) throws -> String {
        guard !category.isBuiltIn else {
            throw CategoryValidationError.builtInCategory
        }

        let name = proposedName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty else {
            throw CategoryValidationError.missingName
        }

        let existing = try context.fetch(FetchDescriptor<PromptCategory>())
        guard !existing.contains(where: {
            $0.id != category.id
                && normalizedKey($0.name) == normalizedKey(name)
        }) else {
            throw CategoryValidationError.duplicateName
        }

        let previousKey = normalizedKey(category.name)
        category.name = name
        if let icon {
            apply(icon, to: category)
        }
        let updatedDate = Date.now

        for prompt in prompts where normalizedKey(prompt.category) == previousKey {
            prompt.category = name
            prompt.updatedDate = updatedDate
        }

        do {
            try context.save()
            return name
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    static func deleteCategory(
        _ category: PromptCategory,
        categories: [PromptCategory],
        prompts: [Prompt],
        in context: ModelContext
    ) throws -> String? {
        guard !category.isBuiltIn else {
            throw CategoryValidationError.builtInCategory
        }

        let remainingCategories = categories
            .filter { $0.id != category.id }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdDate < $1.createdDate
                }
                return $0.sortOrder < $1.sortOrder
            }
        let deletedKey = normalizedKey(category.name)
        let affectedPrompts = prompts.filter {
            normalizedKey($0.category) == deletedKey
        }
        var destination = remainingCategories.first

        if destination == nil, !affectedPrompts.isEmpty {
            let fallback = PromptCategory(
                name: "Uncategorized",
                sortOrder: 0
            )
            context.insert(fallback)
            destination = fallback
        }

        let updatedDate = Date.now

        if let destination {
            for prompt in affectedPrompts {
                prompt.category = destination.name
                prompt.updatedDate = updatedDate
            }
        }

        context.delete(category)
        for (index, remainingCategory) in remainingCategories.enumerated() {
            remainingCategory.sortOrder = index
        }

        do {
            try context.save()
            return destination?.name
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func normalizedKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
    }

    private static func apply(
        _ icon: CategoryIconDraft,
        to category: PromptCategory
    ) {
        category.iconKind = icon.kind
        category.iconEmoji = icon.kind == .emoji ? icon.emoji : nil
        category.iconImageData = icon.kind == .localImage
            ? icon.imageData
            : nil
    }
}
