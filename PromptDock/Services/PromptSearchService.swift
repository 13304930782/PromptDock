import Foundation
import SwiftUI

struct PromptSearchSnapshot: Hashable, Sendable {
    let id: UUID
    let title: String
    let category: String
    let displayedCategory: String
    let content: String
    let isFavorite: Bool
    let updatedDate: Date
    let tags: [String]
}

struct PromptSearchInput: Hashable, Sendable {
    let snapshots: [PromptSearchSnapshot]
    let query: String
    let localeIdentifier: String
    var limit: Int? = nil
}

enum PromptSearchService {
    static func snapshots(_ prompts: [Prompt], tags: [PromptTag] = [], locale: Locale) -> [PromptSearchSnapshot] {
        var names: [UUID: [String]] = [:]
        for tag in tags { for id in tag.promptIDs { names[id, default: []].append(tag.name) } }
        return prompts.map {
            PromptSearchSnapshot(id: $0.id, title: $0.title, category: $0.category,
                displayedCategory: BuiltInCategoryPresentation.displayName(for: $0.category, locale: locale),
                content: $0.content, isFavorite: $0.isFavorite, updatedDate: $0.updatedDate,
                tags: (names[$0.id] ?? []).sorted())
        }
    }

    static func results(in prompts: [Prompt], query: String, locale: Locale = .autoupdatingCurrent, limit: Int? = nil, tags: [PromptTag] = []) -> [Prompt] {
        let ids = search(PromptSearchInput(snapshots: snapshots(prompts, tags: tags, locale: locale), query: query, localeIdentifier: locale.identifier, limit: limit))
        let byID = Dictionary(prompts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    static func search(_ input: PromptSearchInput) -> [UUID] {
        rankedResults(in: input.snapshots, query: input.query, locale: Locale(identifier: input.localeIdentifier), limit: input.limit).map(\.id)
    }

    private static func rankedResults(
        in prompts: [PromptSearchSnapshot],
        query proposedQuery: String,
        locale: Locale = .autoupdatingCurrent,
        limit: Int? = nil
    ) -> [PromptSearchSnapshot] {
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
            if Task.isCancelled { return [] }
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
        guard let snapshot = snapshots([prompt], locale: locale).first else { return false }
        return rank(snapshot, query: query, locale: locale) != nil
    }

    private struct RankedPrompt {
        let prompt: PromptSearchSnapshot
        let rank: Int
    }

    private static func rank(
        _ prompt: PromptSearchSnapshot,
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
        let displayedCategory = prompt.displayedCategory
        if equals(prompt.category, query: query, locale: locale)
            || equals(displayedCategory, query: query, locale: locale) {
            return 3
        }
        if contains(prompt.category, query: query, locale: locale)
            || contains(displayedCategory, query: query, locale: locale) {
            return 4
        }
        if prompt.tags.contains(where: { contains($0, query: query, locale: locale) }) { return 5 }
        if contains(prompt.content, query: query, locale: locale) {
            return 6
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


@MainActor
final class PromptSearchController: ObservableObject {
    @Published private(set) var ids: [UUID] = []
    @Published private(set) var completedInput: PromptSearchInput?
    private var generation = 0

    func search(_ input: PromptSearchInput) async {
        generation += 1
        let token = generation
        ids = []
        completedInput = nil
        guard !input.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
        guard !Task.isCancelled, token == generation else { return }
        let work = Task.detached(priority: .userInitiated) { PromptSearchService.search(input) }
        let result = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
        guard !Task.isCancelled, token == generation else { return }
        ids = result
        completedInput = input
    }
}
