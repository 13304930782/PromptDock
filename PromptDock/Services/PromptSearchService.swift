import Foundation

enum PromptSearchService {
    static func results(
        in prompts: [Prompt],
        query proposedQuery: String
    ) -> [Prompt] {
        let query = proposedQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return [] }

        return prompts.compactMap { prompt in
            rank(prompt, query: query).map { (prompt, $0) }
        }
        .sorted { first, second in
            if first.1 != second.1 { return first.1 < second.1 }
            if first.0.isFavorite != second.0.isFavorite {
                return first.0.isFavorite
            }
            if first.0.updatedDate != second.0.updatedDate {
                return first.0.updatedDate > second.0.updatedDate
            }
            return first.0.title.localizedStandardCompare(second.0.title)
                == .orderedAscending
        }
        .map(\.0)
    }

    static func matches(_ prompt: Prompt, query: String) -> Bool {
        rank(prompt, query: query) != nil
    }

    private static func rank(_ prompt: Prompt, query: String) -> Int? {
        if prompt.title.localizedCaseInsensitiveCompare(query) == .orderedSame {
            return 0
        }
        if prompt.title.range(
            of: query,
            options: [.anchored, .caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil {
            return 1
        }
        if prompt.title.localizedStandardContains(query) {
            return 2
        }
        if prompt.category.localizedCaseInsensitiveCompare(query) == .orderedSame {
            return 3
        }
        if prompt.category.localizedStandardContains(query) {
            return 4
        }
        if prompt.content.localizedStandardContains(query) {
            return 5
        }
        return nil
    }
}
