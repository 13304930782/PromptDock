import Foundation

enum PromptSearchService {
    static func results(
        in prompts: [Prompt],
        query proposedQuery: String,
        locale: Locale = .autoupdatingCurrent,
        limit: Int? = nil
    ) -> [Prompt] {
        let query = proposedQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return [] }

        if let limit, limit <= 0 { return [] }

        var matches: [RankedPrompt] = []
        if let limit {
            matches.reserveCapacity(limit)
        }

        for prompt in prompts {
            guard let rank = rank(prompt, query: query, locale: locale) else {
                continue
            }
            let candidate = RankedPrompt(prompt: prompt, rank: rank)

            if let limit {
                let insertionIndex = matches.firstIndex {
                    isOrderedBefore(candidate, $0, locale: locale)
                } ?? matches.endIndex
                matches.insert(candidate, at: insertionIndex)
                if matches.count > limit {
                    matches.removeLast()
                }
            } else {
                matches.append(candidate)
            }
        }

        if limit == nil {
            matches.sort {
                isOrderedBefore($0, $1, locale: locale)
            }
        }
        return matches.map(\.prompt)
    }

    static func matches(
        _ prompt: Prompt,
        query: String,
        locale: Locale = .autoupdatingCurrent
    ) -> Bool {
        rank(prompt, query: query, locale: locale) != nil
    }

    private struct RankedPrompt {
        let prompt: Prompt
        let rank: Int
    }

    private static func rank(
        _ prompt: Prompt,
        query: String,
        locale: Locale
    ) -> Int? {
        if prompt.title.compare(
            query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        ) == .orderedSame {
            return 0
        }
        if prompt.title.range(
            of: query,
            options: [.anchored, .caseInsensitive, .diacriticInsensitive],
            locale: locale
        ) != nil {
            return 1
        }
        if contains(prompt.title, query: query, locale: locale) {
            return 2
        }
        let displayedCategory = BuiltInCategoryPresentation.displayName(
            for: prompt.category,
            locale: locale
        )
        if equals(prompt.category, query: query, locale: locale)
            || equals(displayedCategory, query: query, locale: locale) {
            return 3
        }
        if contains(prompt.category, query: query, locale: locale)
            || contains(displayedCategory, query: query, locale: locale) {
            return 4
        }
        if contains(prompt.content, query: query, locale: locale) {
            return 5
        }
        return nil
    }

    private static func isOrderedBefore(
        _ first: RankedPrompt,
        _ second: RankedPrompt,
        locale: Locale
    ) -> Bool {
        if first.rank != second.rank { return first.rank < second.rank }
        if first.prompt.isFavorite != second.prompt.isFavorite {
            return first.prompt.isFavorite
        }
        if first.prompt.updatedDate != second.prompt.updatedDate {
            return first.prompt.updatedDate > second.prompt.updatedDate
        }
        return first.prompt.title.compare(
            second.prompt.title,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        ) == .orderedAscending
    }

    private static func equals(
        _ value: String,
        query: String,
        locale: Locale
    ) -> Bool {
        value.compare(
            query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        ) == .orderedSame
    }

    private static func contains(
        _ value: String,
        query: String,
        locale: Locale
    ) -> Bool {
        value.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        ) != nil
    }
}
