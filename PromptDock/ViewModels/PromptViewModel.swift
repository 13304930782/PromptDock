import SwiftData
import SwiftUI

struct PromptDraft {
    var title: String
    var category: String
    var content: String
    var isFavorite: Bool
    var tagIDs: Set<UUID>
    var variableDefinitions: [TemplateVariableDraft]
    var newTagNames: [String]

    init(
        title: String = "",
        category: String = "Teaching",
        content: String = "",
        isFavorite: Bool = false,
        tagIDs: Set<UUID> = [],
        variableDefinitions: [TemplateVariableDraft] = [],
        newTagNames: [String] = []
    ) {
        self.title = title
        self.category = category
        self.content = content
        self.isFavorite = isFavorite
        self.tagIDs = tagIDs
        self.variableDefinitions = variableDefinitions
        self.newTagNames = newTagNames
    }

    init(prompt: Prompt) {
        title = prompt.title
        category = prompt.category
        content = prompt.content
        isFavorite = prompt.isFavorite
        tagIDs = []
        variableDefinitions = []
        newTagNames = []
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TemplateVariableDraft: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var label: String
    var defaultValue: String
    var order: Int
    var isRepeatable: Bool

    init(
        name: String,
        label: String? = nil,
        defaultValue: String = "",
        order: Int,
        isRepeatable: Bool = false
    ) {
        self.name = name
        self.label = label ?? name
        self.defaultValue = defaultValue
        self.order = order
        self.isRepeatable = isRepeatable
    }

    init(_ definition: TemplateVariableDefinition) {
        name = definition.name
        label = definition.label
        defaultValue = definition.defaultValue
        order = definition.order
        isRepeatable = definition.isRepeatable
    }
}

enum PromptValidationError: LocalizedError {
    case missingTitle
    case missingContent

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            "Enter a title for the prompt."
        case .missingContent:
            "Enter the prompt content."
        }
    }
}

enum PromptSection: Hashable, Identifiable {
    case all
    case favorites
    case recent
    case smartCollection(UUID, String)
    case category(String)
    case tag(UUID, String)

    var id: String {
        switch self {
        case .all: "library.all"
        case .favorites: "library.favorites"
        case .recent: "library.recent"
        case .smartCollection(let id, _): "collection.\(id.uuidString)"
        case .category(let name): "category.\(name)"
        case .tag(let id, _): "tag.\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .all: "All Prompts"
        case .favorites: "Favorites"
        case .recent: "Recently Updated"
        case .smartCollection(_, let name), .tag(_, let name): name
        case .category(let name): name
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.stack"
        case .favorites: "star"
        case .recent: "clock"
        case .smartCollection: "square.stack.3d.up"
        case .category: "folder"
        case .tag: "tag"
        }
    }

    var localizedTitle: LocalizedStringKey {
        LocalizedStringKey(title)
    }

    static let librarySections: [PromptSection] = [.all, .favorites, .recent]
}

@MainActor
final class PromptViewModel: ObservableObject {
    @Published var selectedSection: PromptSection = .all
    @Published var selectedPromptID: UUID?
    @Published var selectedPromptIDs: Set<UUID> = []
    @Published var searchText = ""

    var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    func preferredNewPromptCategory(
        from categories: [PromptCategory]
    ) -> String {
        switch selectedSection {
        case .category(let name):
            name
        case .all, .favorites, .recent, .smartCollection, .tag:
            categories.first?.name
                ?? CategoryService.defaultCategories[0].name
        }
    }

    func filteredPrompts(
        from prompts: [Prompt],
        tags: [PromptTag] = [],
        collections: [SmartCollection] = [],
        locale: Locale = .autoupdatingCurrent
    ) -> [Prompt] {
        let sectionPrompts: [Prompt]
        switch selectedSection {
        case .all:
            sectionPrompts = prompts
        case .favorites:
            sectionPrompts = prompts.filter(\.isFavorite)
        case .recent:
            sectionPrompts = Array(
                prompts.sorted { $0.updatedDate > $1.updatedDate }.prefix(20)
            )
        case .smartCollection(let id, _):
            guard let collection = collections.first(where: { $0.id == id }) else {
                sectionPrompts = []
                break
            }
            sectionPrompts = prompts.filter {
                Phase1Service.matches($0, collection: collection, tags: tags)
            }
        case .category(let name):
            let sectionKey = CategoryNameIdentity.normalized(name)
            sectionPrompts = prompts.filter {
                CategoryNameIdentity.normalized($0.category) == sectionKey
            }
        case .tag(let id, _):
            let promptIDs = Set(tags.first(where: { $0.id == id })?.promptIDs ?? [])
            sectionPrompts = prompts.filter { promptIDs.contains($0.id) }
        }

        guard hasSearchQuery else { return sectionPrompts }
        return PromptSearchService.results(
            in: sectionPrompts,
            query: searchText,
            locale: locale
        )
    }

    func selectedPrompt(in prompts: [Prompt]) -> Prompt? {
        guard let selectedPromptID else { return nil }
        return prompts.first { $0.id == selectedPromptID }
    }

    func reconcileSelection(
        in prompts: [Prompt],
        tags: [PromptTag] = [],
        collections: [SmartCollection] = [],
        locale: Locale = .autoupdatingCurrent
    ) {
        let visiblePrompts = filteredPrompts(
            from: prompts,
            tags: tags,
            collections: collections,
            locale: locale
        )
        let visibleIDs = Set(visiblePrompts.map(\.id))
        selectedPromptIDs.formIntersection(visibleIDs)

        if let selectedPromptID,
           visiblePrompts.contains(where: { $0.id == selectedPromptID }) {
            if selectedPromptIDs.isEmpty { selectedPromptIDs = [selectedPromptID] }
            return
        }

        selectedPromptID = visiblePrompts.first?.id
        selectedPromptIDs = selectedPromptID.map { [$0] } ?? []
    }

    func updateSelection(_ ids: Set<UUID>, orderedBy visibleIDs: [UUID] = []) {
        let added = ids.subtracting(selectedPromptIDs)
        selectedPromptIDs = ids
        if let newlySelected = added.first {
            selectedPromptID = newlySelected
        } else if let selectedPromptID, ids.contains(selectedPromptID) {
            return
        } else {
            selectedPromptID = visibleIDs.first(where: ids.contains)
                ?? ids.sorted { $0.uuidString < $1.uuidString }.first
        }
    }

    func searchResultPosition(in prompts: [Prompt]) -> String {
        guard !prompts.isEmpty else { return "0 of 0" }
        guard let selectedPromptID,
              let index = prompts.firstIndex(where: {
                  $0.id == selectedPromptID
              }) else {
            return "0 of \(prompts.count)"
        }

        return "\(index + 1) of \(prompts.count)"
    }

    func selectNextSearchResult(in prompts: [Prompt]) {
        selectSearchResult(in: prompts, offset: 1)
    }

    func selectPreviousSearchResult(in prompts: [Prompt]) {
        selectSearchResult(in: prompts, offset: -1)
    }

    @discardableResult
    func createPrompt(
        from draft: PromptDraft,
        tags: [PromptTag] = [],
        in context: ModelContext
    ) throws -> Prompt {
        let values = try validatedValues(from: draft)
        let prompt = Prompt(
            title: values.title,
            category: values.category,
            content: values.content,
            isFavorite: draft.isFavorite
        )

        context.insert(prompt)

        do {
            try Phase1Service.applyOrganization(
                to: prompt,
                draft: draft,
                tags: tags,
                in: context
            )
            try context.save()
            return prompt
        } catch {
            context.rollback()
            throw error
        }
    }

    func updatePrompt(
        _ prompt: Prompt,
        from draft: PromptDraft,
        tags: [PromptTag] = [],
        in context: ModelContext
    ) throws {
        let values = try validatedValues(from: draft)

        try Phase1Service.captureVersionIfChanged(
            for: prompt,
            title: values.title,
            category: values.category,
            content: values.content,
            in: context
        )

        prompt.title = values.title
        prompt.category = values.category
        prompt.content = values.content
        prompt.isFavorite = draft.isFavorite
        prompt.updatedDate = .now

        do {
            try Phase1Service.applyOrganization(
                to: prompt,
                draft: draft,
                tags: tags,
                in: context
            )
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deletePrompt(
        _ prompt: Prompt,
        tags: [PromptTag] = [],
        in context: ModelContext
    ) throws {
        let deletedPromptID = prompt.id
        try Phase1Service.delete(prompts: [prompt], tags: tags, in: context)
        if selectedPromptID == deletedPromptID {
            selectedPromptID = nil
        }
        selectedPromptIDs.remove(deletedPromptID)
    }

    func toggleFavorite(
        for prompt: Prompt,
        in context: ModelContext
    ) throws {
        prompt.isFavorite.toggle()

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func validatedValues(
        from draft: PromptDraft
    ) throws -> (title: String, category: String, content: String) {
        let title = draft.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let content = draft.content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !title.isEmpty else {
            throw PromptValidationError.missingTitle
        }
        guard !content.isEmpty else {
            throw PromptValidationError.missingContent
        }

        return (
            title,
            CategoryNameIdentity.trimmed(draft.category),
            content
        )
    }

    private func selectSearchResult(
        in prompts: [Prompt],
        offset: Int
    ) {
        guard !prompts.isEmpty else {
            selectedPromptID = nil
            return
        }

        let currentIndex = prompts.firstIndex(where: {
            $0.id == selectedPromptID
        }) ?? (offset > 0 ? -1 : 0)
        let nextIndex = (currentIndex + offset + prompts.count)
            % prompts.count

        selectedPromptID = prompts[nextIndex].id
    }
}
