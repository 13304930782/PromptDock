import Foundation
import SwiftData

@Model
final class PromptVersion {
    @Attribute(.unique) var id: UUID
    var promptID: UUID
    var title: String
    var category: String
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        promptID: UUID,
        title: String,
        category: String,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.promptID = promptID
        self.title = title
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }
}

enum PromptTagColor: String, Codable, CaseIterable, Identifiable {
    case gray, red, orange, yellow, green, blue, purple

    var id: String { rawValue }
}

@Model
final class PromptTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorRawValue: String
    var promptIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: PromptTagColor = .gray,
        promptIDs: [UUID] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorRawValue = color.rawValue
        self.promptIDs = promptIDs
        self.createdAt = createdAt
    }

    var color: PromptTagColor {
        get { PromptTagColor(rawValue: colorRawValue) ?? .gray }
        set { colorRawValue = newValue.rawValue }
    }
}

@Model
final class SmartCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var query: String
    var category: String?
    var tagIDs: [UUID]
    var favoriteOnly: Bool
    var updatedWithinDays: Int?
    var matchAll: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        query: String = "",
        category: String? = nil,
        tagIDs: [UUID] = [],
        favoriteOnly: Bool = false,
        updatedWithinDays: Int? = nil,
        matchAll: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.category = category
        self.tagIDs = tagIDs
        self.favoriteOnly = favoriteOnly
        self.updatedWithinDays = updatedWithinDays
        self.matchAll = matchAll
        self.createdAt = createdAt
    }
}

@Model
final class TemplateVariableDefinition {
    @Attribute(.unique) var id: UUID
    var promptID: UUID
    var name: String
    var label: String
    var defaultValue: String
    var order: Int
    var isRepeatable: Bool

    init(
        id: UUID = UUID(),
        promptID: UUID,
        name: String,
        label: String? = nil,
        defaultValue: String = "",
        order: Int = 0,
        isRepeatable: Bool = false
    ) {
        self.id = id
        self.promptID = promptID
        self.name = name
        self.label = label ?? name
        self.defaultValue = defaultValue
        self.order = order
        self.isRepeatable = isRepeatable
    }
}

@MainActor
enum Phase1Service {
    static let maximumPromptVersions = 50

    static func captureVersionIfChanged(
        for prompt: Prompt,
        title: String,
        category: String,
        content: String,
        in context: ModelContext
    ) throws {
        guard prompt.title != title || prompt.category != category || prompt.content != content else {
            return
        }

        context.insert(PromptVersion(
            promptID: prompt.id,
            title: prompt.title,
            category: prompt.category,
            content: prompt.content
        ))

        let promptID = prompt.id
        let versions = try context.fetch(FetchDescriptor<PromptVersion>(
            predicate: #Predicate { $0.promptID == promptID },
            sortBy: [SortDescriptor(\PromptVersion.createdAt, order: .reverse)]
        ))
        for version in versions.dropFirst(maximumPromptVersions) {
            context.delete(version)
        }
    }

    static func restore(
        _ version: PromptVersion,
        to prompt: Prompt,
        in context: ModelContext
    ) throws {
        do {
            try captureVersionIfChanged(
                for: prompt,
                title: version.title,
                category: version.category,
                content: version.content,
                in: context
            )
            prompt.title = version.title
            prompt.category = version.category
            prompt.content = version.content
            prompt.updatedDate = .now
            try saveOrRollback(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func ensureVariableDefinitions(
        for prompt: Prompt,
        in context: ModelContext
    ) throws -> [TemplateVariableDefinition] {
        let template = PromptTemplate(prompt.content)
        let promptID = prompt.id
        let existing = try context.fetch(FetchDescriptor<TemplateVariableDefinition>(
            predicate: #Predicate { $0.promptID == promptID },
            sortBy: [SortDescriptor(\TemplateVariableDefinition.order)]
        ))
        var byName: [String: TemplateVariableDefinition] = [:]
        for definition in existing {
            if byName[definition.name] == nil {
                byName[definition.name] = definition
            } else {
                context.delete(definition)
            }
        }
        for (index, field) in template.fields.enumerated() where byName[field.name] == nil {
            let definition = TemplateVariableDefinition(
                promptID: prompt.id,
                name: field.name,
                order: index,
                isRepeatable: field.isRepeatable
            )
            context.insert(definition)
            byName[field.name] = definition
        }
        try context.save()
        return byName.values.sorted { $0.order < $1.order }
    }

    static func applyOrganization(
        to prompt: Prompt,
        draft: PromptDraft,
        tags: [PromptTag],
        in context: ModelContext
    ) throws {
        for tag in tags {
            if draft.tagIDs.contains(tag.id) {
                if !tag.promptIDs.contains(prompt.id) { tag.promptIDs.append(prompt.id) }
            } else {
                tag.promptIDs.removeAll { $0 == prompt.id }
            }
        }
        var knownTagNames = Set(tags.map { CategoryNameIdentity.normalized($0.name) })
        for name in draft.newTagNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let identity = CategoryNameIdentity.normalized(trimmed)
            if knownTagNames.insert(identity).inserted {
                context.insert(PromptTag(name: trimmed, color: .blue, promptIDs: [prompt.id]))
            }
        }
        try syncVariableDefinitions(
            promptID: prompt.id,
            drafts: draft.variableDefinitions,
            content: draft.content,
            in: context
        )
    }

    static func syncVariableDefinitions(
        promptID: UUID,
        drafts: [TemplateVariableDraft],
        content: String,
        in context: ModelContext
    ) throws {
        let fields = PromptTemplate(content).fields
        let fieldNames = Set(fields.map(\.name))
        let existing = try context.fetch(FetchDescriptor<TemplateVariableDefinition>(
            predicate: #Predicate { $0.promptID == promptID }
        ))
        var byName: [String: TemplateVariableDefinition] = [:]
        for definition in existing {
            if byName[definition.name] == nil {
                byName[definition.name] = definition
            } else {
                context.delete(definition)
            }
        }
        let draftByName = Dictionary(
            drafts.map { ($0.name, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        for definition in existing where !fieldNames.contains(definition.name) {
            context.delete(definition)
            byName[definition.name] = nil
        }
        for (fallbackOrder, field) in fields.enumerated() {
            let draft = draftByName[field.name]
            let definition = byName[field.name] ?? TemplateVariableDefinition(
                promptID: promptID,
                name: field.name
            )
            if byName[field.name] == nil { context.insert(definition) }
            definition.label = draft?.label.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? field.name
            definition.defaultValue = draft?.defaultValue ?? ""
            definition.order = draft?.order ?? fallbackOrder
            definition.isRepeatable = field.isRepeatable
        }
    }

    static func move(
        prompts: [Prompt],
        to category: String,
        in context: ModelContext
    ) throws {
        for prompt in prompts {
            prompt.category = category
            prompt.updatedDate = .now
        }
        try saveOrRollback(context)
    }

    static func setTag(
        _ tag: PromptTag,
        for prompts: [Prompt],
        isIncluded: Bool,
        in context: ModelContext
    ) throws {
        let ids = Set(prompts.map(\.id))
        if isIncluded {
            tag.promptIDs = Array(Set(tag.promptIDs).union(ids))
        } else {
            tag.promptIDs.removeAll(where: ids.contains)
        }
        try saveOrRollback(context)
    }

    static func setFavorite(
        _ value: Bool,
        for prompts: [Prompt],
        in context: ModelContext
    ) throws {
        for prompt in prompts { prompt.isFavorite = value }
        try saveOrRollback(context)
    }

    static func delete(
        prompts: [Prompt],
        tags: [PromptTag],
        in context: ModelContext
    ) throws {
        let ids = Set(prompts.map(\.id))
        let versions = try context.fetch(FetchDescriptor<PromptVersion>())
            .filter { ids.contains($0.promptID) }
        let definitions = try context.fetch(FetchDescriptor<TemplateVariableDefinition>())
            .filter { ids.contains($0.promptID) }

        for tag in tags { tag.promptIDs.removeAll(where: ids.contains) }
        for version in versions { context.delete(version) }
        for definition in definitions { context.delete(definition) }
        for prompt in prompts { context.delete(prompt) }
        try saveOrRollback(context)
    }

    private static func saveOrRollback(_ context: ModelContext) throws {
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
    }

    static func matches(
        _ prompt: Prompt,
        collection: SmartCollection,
        tags: [PromptTag],
        now: Date = .now
    ) -> Bool {
        var checks: [Bool] = []
        let query = collection.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            checks.append([prompt.title, prompt.category, prompt.content].joined(separator: " ")
                .localizedCaseInsensitiveContains(query))
        }
        if let category = collection.category, !category.isEmpty {
            checks.append(CategoryNameIdentity.normalized(prompt.category) == CategoryNameIdentity.normalized(category))
        }
        if collection.favoriteOnly { checks.append(prompt.isFavorite) }
        if let days = collection.updatedWithinDays {
            checks.append(prompt.updatedDate >= now.addingTimeInterval(-Double(days) * 86_400))
        }
        if !collection.tagIDs.isEmpty {
            let promptTagIDs = Set(tags.filter { $0.promptIDs.contains(prompt.id) }.map(\PromptTag.id))
            let matched = collection.tagIDs.filter(promptTagIDs.contains).count
            checks.append(collection.matchAll ? matched == collection.tagIDs.count : matched > 0)
        }
        return checks.isEmpty || (collection.matchAll ? checks.allSatisfy { $0 } : checks.contains(true))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
