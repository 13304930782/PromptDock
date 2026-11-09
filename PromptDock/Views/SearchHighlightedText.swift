import SwiftUI

struct SearchHighlightedText: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let text: String
    let query: String

    var body: some View {
        Text(SearchHighlighter.attributedString(for: text, query: query, increasedContrast: contrast == .increased))
    }
}

enum SearchHighlighter {
    static func attributedString(
        for text: String,
        query: String,
        increasedContrast: Bool = false
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
                Color.blue.opacity(0.22)
            attributedText[lowerBound..<upperBound].foregroundColor = .primary
            if increasedContrast {
                attributedText[lowerBound..<upperBound].underlineStyle = .single
            }
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
