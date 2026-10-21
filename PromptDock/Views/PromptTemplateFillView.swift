import SwiftUI

struct PromptTemplateCopyRequest: Identifiable {
    let id = UUID()
    let promptID: UUID
    let promptTitle: String
    let template: PromptTemplate
    let fields: [PromptTemplateField]

    init(prompt: Prompt, definitions: [TemplateVariableDefinition] = []) {
        promptID = prompt.id
        promptTitle = prompt.title
        let parsedTemplate = PromptTemplate(prompt.content)
        template = parsedTemplate
        let byName = Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0) })
        var configuredFields: [(index: Int, field: PromptTemplateField)] = []
        for (index, field) in parsedTemplate.fields.enumerated() {
            let definition = byName[field.name]
            configuredFields.append((index, PromptTemplateField(
                variable: field,
                label: definition?.label ?? field.name,
                defaultValue: definition?.defaultValue ?? "",
                order: definition?.order ?? Int.max
            )))
        }
        configuredFields.sort {
            $0.field.order == $1.field.order
                ? $0.index < $1.index
                : $0.field.order < $1.field.order
        }
        fields = configuredFields.map(\.field)
    }
}

struct PromptTemplateField: Identifiable {
    var id: String { variable.id }
    let variable: PromptTemplateVariable
    let label: String
    let defaultValue: String
    let order: Int
}

enum PromptTemplateFillPresentation {
    case sheet
    case compact
}

struct PromptTemplateFillView: View {
    let request: PromptTemplateCopyRequest
    let presentation: PromptTemplateFillPresentation
    let usesChinese: Bool
    let onCancel: () -> Void
    let onCopy: (String) -> Bool

    @State private var values: [String: String]
    @State private var repeatableValues: [String: [String]]
    @State private var hasAttemptedCopy = false
    @FocusState private var focusedField: TemplateFieldFocus?

    init(
        request: PromptTemplateCopyRequest,
        presentation: PromptTemplateFillPresentation,
        usesChinese: Bool,
        onCancel: @escaping () -> Void,
        onCopy: @escaping (String) -> Bool
    ) {
        self.request = request
        self.presentation = presentation
        self.usesChinese = usesChinese
        self.onCancel = onCancel
        self.onCopy = onCopy
        _values = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: request.fields.compactMap {
                    $0.variable.isRepeatable ? nil : ($0.variable.name, $0.defaultValue)
                }
            )
        )
        _repeatableValues = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: request.fields.compactMap {
                    $0.variable.isRepeatable ? ($0.variable.name, [$0.defaultValue]) : nil
                }
            )
        )
    }

    private var missingFields: [PromptTemplateVariable] {
        request.template.unresolvedFields(
            values: values,
            repeatableValues: repeatableValues
        )
    }

    private var renderedPrompt: String {
        request.template.render(
            values: values,
            repeatableValues: repeatableValues,
            listSeparator: usesChinese ? "、" : ", "
        )
    }

    private var isComplete: Bool {
        missingFields.isEmpty
    }

    var body: some View {
        Group {
            switch presentation {
            case .sheet:
                sheetContent
            case .compact:
                compactContent
            }
        }
        .onExitCommand(perform: onCancel)
        .task {
            await Task.yield()
            focusedField = focusTarget(
                for: request.fields.first?.variable
            )
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Label {
                    Text(usesChinese ? "填写变量" : "Fill Variables")
                } icon: {
                    Image(systemName: "curlybraces")
                }
                .font(.title2.weight(.semibold))

                Text(
                    usesChinese
                        ? "完成“\(request.promptTitle)”中的变量，然后复制最终提示词。"
                        : "Complete the variables in “\(request.promptTitle)”, then copy the finished prompt."
                )
                .foregroundStyle(.secondary)
            }

            variableFields

            preview(minHeight: 90, maxHeight: 180)

            validationMessage

            HStack {
                Spacer()
                Button(usesChinese ? "取消" : "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button {
                    submit()
                } label: {
                    Label {
                        Text(usesChinese ? "复制提示词" : "Copy Prompt")
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 600)
        .frame(minHeight: 440)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help(usesChinese ? "返回搜索结果" : "Back to Search Results")
                .accessibilityLabel(
                    usesChinese ? "返回搜索结果" : "Back to Search Results"
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(usesChinese ? "填写后复制" : "Fill and Copy")
                        .font(.headline)
                    Text(request.promptTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(
                    "\(request.template.variables.count)"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    usesChinese
                        ? "\(request.template.variables.count) 个变量"
                        : "\(request.template.variables.count) variables"
                )
            }

            Divider()

            variableFields

            preview(minHeight: 78, maxHeight: 112)

            validationMessage

            HStack {
                Text(
                    usesChinese
                        ? "Tab 切换 · Return 复制 · Esc 返回"
                        : "Tab to move · Return to copy · Esc to go back"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    submit()
                } label: {
                    Label {
                        Text(usesChinese ? "复制" : "Copy")
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 410, height: 480, alignment: .top)
    }

    private var variableFields: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(request.fields) { field in
                    if field.variable.isRepeatable {
                        repeatableField(field.variable, label: field.label)
                    } else {
                        valueField(field.variable, label: field.label)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(
            minHeight: presentation == .sheet ? 80 : 90,
            maxHeight: presentation == .sheet ? 210 : 150
        )
    }

    private func valueField(
        _ field: PromptTemplateVariable,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(
                usesChinese
                    ? "输入\(field.name)"
                    : "Enter \(field.name)",
                text: binding(for: field.name)
            )
            .textFieldStyle(.roundedBorder)
            .focused(
                $focusedField,
                equals: TemplateFieldFocus(
                    variableID: field.id,
                    itemIndex: nil
                )
            )
            .accessibilityLabel(field.name)
            .onSubmit(submit)
        }
    }

    private func repeatableField(
        _ field: PromptTemplateVariable,
        label: String
    ) -> some View {
        let items = repeatableValues[field.name] ?? [""]

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(usesChinese ? "可重复" : "Repeatable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(
                    "\(items.count)/\(PromptTemplate.maximumRepeatableValueCount)"
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)

                Button {
                    addRepeatableValue(for: field)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(
                    items.count
                        >= PromptTemplate.maximumRepeatableValueCount
                )
                .help(
                    usesChinese
                        ? "添加一项"
                        : "Add Item"
                )
                .accessibilityLabel(
                    usesChinese
                        ? "为\(field.name)添加一项"
                        : "Add an item to \(field.name)"
                )
            }

            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    TextField(
                        usesChinese
                            ? "第 \(index + 1) 项"
                            : "Item \(index + 1)",
                        text: repeatableBinding(
                            for: field.name,
                            index: index
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused(
                        $focusedField,
                        equals: TemplateFieldFocus(
                            variableID: field.id,
                            itemIndex: index
                        )
                    )
                    .accessibilityLabel(
                        usesChinese
                            ? "\(field.name)，第 \(index + 1) 项"
                            : "\(field.name), item \(index + 1)"
                    )
                    .onSubmit(submit)

                    if items.count > 1 {
                        Button {
                            removeRepeatableValue(
                                for: field,
                                at: index
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help(
                            usesChinese
                                ? "移除这一项"
                                : "Remove Item"
                        )
                        .accessibilityLabel(
                            usesChinese
                                ? "移除\(field.name)的第 \(index + 1) 项"
                                : "Remove item \(index + 1) from \(field.name)"
                        )
                    }
                }
            }
        }
    }

    private func preview(
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> some View {
        GroupBox {
            ScrollView {
                Text(renderedPrompt)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.vertical, 4)
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
        } label: {
            Label {
                Text(usesChinese ? "实时预览" : "Live Preview")
            } icon: {
                Image(systemName: "doc.text")
            }
        }
    }

    @ViewBuilder
    private var validationMessage: some View {
        if hasAttemptedCopy, let firstMissing = missingFields.first {
            Label {
                Text(
                    usesChinese
                        ? "请填写“\(firstMissing.name)”。"
                        : "Enter a value for “\(firstMissing.name)”."
                )
            } icon: {
                Image(systemName: "exclamationmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityAddTraits(.isStaticText)
        }
    }

    private func binding(for variable: String) -> Binding<String> {
        Binding(
            get: { values[variable, default: ""] },
            set: { values[variable] = $0 }
        )
    }

    private func repeatableBinding(
        for variable: String,
        index: Int
    ) -> Binding<String> {
        Binding(
            get: {
                let items = repeatableValues[variable] ?? []
                guard items.indices.contains(index) else { return "" }
                return items[index]
            },
            set: { newValue in
                var items = repeatableValues[variable] ?? [""]
                guard items.indices.contains(index) else { return }
                items[index] = newValue
                repeatableValues[variable] = items
            }
        )
    }

    private func addRepeatableValue(
        for field: PromptTemplateVariable
    ) {
        var items = repeatableValues[field.name] ?? [""]
        guard
            items.count < PromptTemplate.maximumRepeatableValueCount
        else {
            return
        }

        items.append("")
        repeatableValues[field.name] = items
        let newIndex = items.count - 1
        Task { @MainActor in
            await Task.yield()
            focusedField = TemplateFieldFocus(
                variableID: field.id,
                itemIndex: newIndex
            )
        }
    }

    private func removeRepeatableValue(
        for field: PromptTemplateVariable,
        at index: Int
    ) {
        var items = repeatableValues[field.name] ?? [""]
        guard items.count > 1, items.indices.contains(index) else {
            return
        }

        items.remove(at: index)
        repeatableValues[field.name] = items
        focusedField = TemplateFieldFocus(
            variableID: field.id,
            itemIndex: min(index, items.count - 1)
        )
    }

    private func focusTarget(
        for field: PromptTemplateVariable?
    ) -> TemplateFieldFocus? {
        guard let field else { return nil }
        return TemplateFieldFocus(
            variableID: field.id,
            itemIndex: field.isRepeatable ? 0 : nil
        )
    }

    private var firstMissingFocusTarget: TemplateFieldFocus? {
        for field in request.template.fields {
            if field.isRepeatable {
                let items = repeatableValues[field.name] ?? [""]
                if let index = items.firstIndex(where: {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }) {
                    return TemplateFieldFocus(
                        variableID: field.id,
                        itemIndex: index
                    )
                }
            } else if values[field.name]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty != false {
                return TemplateFieldFocus(
                    variableID: field.id,
                    itemIndex: nil
                )
            }
        }
        return nil
    }

    private func submit() {
        guard isComplete else {
            hasAttemptedCopy = true
            focusedField = firstMissingFocusTarget
            return
        }

        if onCopy(renderedPrompt) {
            hasAttemptedCopy = false
        }
    }
}

private struct TemplateFieldFocus: Hashable {
    let variableID: String
    let itemIndex: Int?
}
