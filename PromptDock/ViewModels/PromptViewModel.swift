import SwiftData
import SwiftUI

struct PromptDraft {
    var title: String
    var category: String
    var content: String
    var isFavorite: Bool

    init(
        title: String = "",
        category: String = "Teaching",
        content: String = "",
        isFavorite: Bool = false
    ) {
        self.title = title
        self.category = category
        self.content = content
        self.isFavorite = isFavorite
    }

    init(prompt: Prompt) {
        title = prompt.title
        category = prompt.category
        content = prompt.content
        isFavorite = prompt.isFavorite
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    case category(String)

    var id: String {
        switch self {
        case .all: "library.all"
        case .favorites: "library.favorites"
        case .category(let name): "category.\(name)"
        }
    }

    var title: String {
        switch self {
        case .all: "All Prompts"
        case .favorites: "Favorites"
        case .category(let name): name
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.stack"
        case .favorites: "star"
        case .category: "folder"
        }
    }

    var localizedTitle: LocalizedStringKey {
        LocalizedStringKey(title)
    }

    static let librarySections: [PromptSection] = [.all, .favorites]
}

@MainActor
final class PromptViewModel: ObservableObject {
    @Published var selectedSection: PromptSection = .all
    @Published var selectedPromptID: UUID?
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
        case .all, .favorites:
            categories.first?.name
                ?? CategoryService.defaultCategories[0].name
        }
    }

    func filteredPrompts(
        from prompts: [Prompt],
        locale: Locale = .autoupdatingCurrent
    ) -> [Prompt] {
        let sectionPrompts: [Prompt]
        switch selectedSection {
        case .all:
            sectionPrompts = prompts
        case .favorites:
            sectionPrompts = prompts.filter(\.isFavorite)
        case .category(let name):
            let sectionKey = CategoryNameIdentity.normalized(name)
            sectionPrompts = prompts.filter {
                CategoryNameIdentity.normalized($0.category) == sectionKey
            }
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
        locale: Locale = .autoupdatingCurrent
    ) {
        let visiblePrompts = filteredPrompts(from: prompts, locale: locale)

        if let selectedPromptID,
           visiblePrompts.contains(where: { $0.id == selectedPromptID }) {
            return
        }

        selectedPromptID = visiblePrompts.first?.id
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
        in context: ModelContext
    ) throws {
        let values = try validatedValues(from: draft)

        prompt.title = values.title
        prompt.category = values.category
        prompt.content = values.content
        prompt.isFavorite = draft.isFavorite
        prompt.updatedDate = .now

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deletePrompt(
        _ prompt: Prompt,
        in context: ModelContext
    ) throws {
        let deletedPromptID = prompt.id
        context.delete(prompt)

        do {
            try context.save()
            if selectedPromptID == deletedPromptID {
                selectedPromptID = nil
            }
        } catch {
            context.rollback()
            throw error
        }
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
