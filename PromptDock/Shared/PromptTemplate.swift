import Foundation

struct PromptTemplateVariable: Hashable, Identifiable {
    enum Kind: String {
        case value
        case list
    }

    let name: String
    let kind: Kind

    var id: String {
        "\(kind.rawValue):\(name)"
    }

    var isRepeatable: Bool {
        kind == .list
    }
}

struct PromptTemplate: Equatable {
    static let maximumRepeatableValueCount = 100

    let source: String
    let fields: [PromptTemplateVariable]

    init(_ source: String) {
        self.source = source

        var seen = Set<PromptTemplateVariable>()
        fields = Self.matches(in: source).compactMap { match in
            guard seen.insert(match.variable).inserted else { return nil }
            return match.variable
        }
    }

    var variables: [String] {
        fields.map(\.name)
    }

    var hasVariables: Bool {
        !fields.isEmpty
    }

    var repeatableVariables: [String] {
        fields.filter(\.isRepeatable).map(\.name)
    }

    func unresolvedVariables(
        values: [String: String]
    ) -> [String] {
        unresolvedFields(
            values: values,
            repeatableValues: [:]
        ).map(\.name)
    }

    func unresolvedFields(
        values: [String: String],
        repeatableValues: [String: [String]]
    ) -> [PromptTemplateVariable] {
        fields.filter { field in
            switch field.kind {
            case .value:
                return values[field.name]?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty != false
            case .list:
                guard
                    let items = repeatableValues[field.name],
                    !items.isEmpty
                else {
                    return true
                }
                return items.contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                }
            }
        }
    }

    func render(
        values: [String: String],
        repeatableValues: [String: [String]] = [:],
        listSeparator: String = "、"
    ) -> String {
        let rendered = NSMutableString(string: source)

        for match in Self.matches(in: source).reversed() {
            let replacement: String?
            switch match.variable.kind {
            case .value:
                replacement = values[match.variable.name]
            case .list:
                replacement = repeatableValues[match.variable.name]?
                    .joined(separator: listSeparator)
            }

            guard let replacement else { continue }
            rendered.replaceCharacters(
                in: match.range,
                with: replacement
            )
        }

        return (rendered as String).replacingOccurrences(
            of: "\\{{",
            with: "{{"
        )
    }

    private struct Match {
        let range: NSRange
        let variable: PromptTemplateVariable
    }

    private static let expression = try! NSRegularExpression(
        pattern: #"(?<!\\)\{\{\s*([^{}\r\n]+?)\s*\}\}"#
    )

    private static func matches(in source: String) -> [Match] {
        let range = NSRange(source.startIndex..., in: source)

        return expression.matches(in: source, range: range).compactMap {
            result in
            guard
                let nameRange = Range(result.range(at: 1), in: source)
            else {
                return nil
            }

            var name = source[nameRange].trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let kind: PromptTemplateVariable.Kind
            if name.hasSuffix("[]") {
                name.removeLast(2)
                name = name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                kind = .list
            } else {
                kind = .value
            }

            guard !name.isEmpty else { return nil }
            return Match(
                range: result.range,
                variable: PromptTemplateVariable(
                    name: name,
                    kind: kind
                )
            )
        }
    }
}
