import SwiftUI

struct SearchHighlightedText: View {
    let text: String
    let query: String

    var body: some View {
        Text(SearchHighlighter.attributedString(for: text, query: query))
    }
}

enum SearchHighlighter {
    static func attributedString(
        for text: String,
        query: String
    ) -> AttributedString {
        var attributedText = AttributedString(text)

        for range in matchingRanges(in: text, query: query) {
            guard let lowerBound = AttributedString.Index(
                range.lowerBound,
                within: attributedText
            ), let upperBound = AttributedString.Index(
                range.upperBound,
                within: attributedText
            ) else {
                continue
            }

            attributedText[lowerBound..<upperBound].backgroundColor =
                Color.accentColor.opacity(0.28)
        }

        return attributedText
    }

    static func matchCount(in text: String, query: String) -> Int {
        matchingRanges(in: text, query: query).count
    }

    private static func matchingRanges(
        in text: String,
        query: String
    ) -> [Range<String.Index>] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange,
            locale: .current
        ) {
            ranges.append(range)

            guard range.upperBound < text.endIndex else { break }
            searchRange = range.upperBound..<text.endIndex
        }

        return ranges
    }
}
