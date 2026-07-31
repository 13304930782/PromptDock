import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openWindow) private var openWindow

    private let prompt: Prompt?
    private let categories: [PromptCategory]
    private let onSave: (PromptDraft) throws -> Void

    @State private var title: String
    @State private var category: String
    @State private var content: String
    @State private var isFavorite: Bool
    @State private var errorMessage: String?

    init(
        prompt: Prompt?,
        categories: [PromptCategory],
        initialCategory: String = "Teaching",
        onSave: @escaping (PromptDraft) throws -> Void
    ) {
        self.prompt = prompt
        self.categories = categories
        self.onSave = onSave

        let draft = prompt.map(PromptDraft.init(prompt:))
            ?? PromptDraft(category: initialCategory)
        _title = State(initialValue: draft.title)
        _category = State(initialValue: draft.category)
        _content = State(initialValue: draft.content)
        _isFavorite = State(initialValue: draft.isFavorite)
    }

    private var draft: PromptDraft {
        PromptDraft(
            title: title,
            category: category,
            content: content,
            isFavorite: isFavorite
        )
    }

    private var promptTemplate: PromptTemplate {
        PromptTemplate(content)
    }

    private var usesChinese: Bool {
        locale.identifier.lowercased().hasPrefix("zh")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextField("Title", text: $title)
                        .accessibilityLabel("Prompt Title")

                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { name in
                            Text(
                                BuiltInCategoryPresentation.displayName(
                                    for: name,
                                    locale: locale
                                )
                            )
                            .tag(name)
                        }
                    }
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 220)
                        .accessibilityLabel("Prompt Content")

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Label {
                            if promptTemplate.hasVariables {
                                Text(
                                    usesChinese
                                        ? "已识别 \(promptTemplate.fields.count) 个变量，其中 \(promptTemplate.repeatableVariables.count) 个可重复。"
                                        : "\(promptTemplate.fields.count) variables detected, including \(promptTemplate.repeatableVariables.count) repeatable."
                                )
                            } else {
                                Text(
                                    usesChinese
                                        ? "输入 {{名称}} 创建普通变量；输入 {{文件名[]}} 创建可用加号扩展的重复项。"
                                        : "Use {{name}} for one value, or {{filename[]}} for a repeatable list with an Add button."
                                )
                            }
                        } icon: {
                            Image(systemName: "curlybraces")
                        }
                        .accessibilityElement(children: .combine)

                        Spacer(minLength: 8)

                        Button {
                            openWindow(id: "template-guide")
                        } label: {
                            Label(
                                usesChinese ? "操作手册" : "Guide",
                                systemImage: "questionmark.circle"
                            )
                        }
                        .buttonStyle(.link)
                        .help(
                            usesChinese
                                ? "打开模板变量操作手册"
                                : "Open the template variables guide"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Options") {
                    Toggle("Favorite", isOn: $isFavorite)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(prompt == nil ? "New Prompt" : "Edit Prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .alert(
            "Unable to Save Prompt",
            isPresented: errorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var categoryOptions: [String] {
        var names = categories.map(\.name)
        if !category.isEmpty,
           !names.contains(where: {
               CategoryNameIdentity.normalized($0)
                   == CategoryNameIdentity.normalized(category)
           }) {
            names.append(category)
        }
        return names.isEmpty ? ["Teaching"] : names
    }

    private func save() {
        do {
            try onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(
            prompt: nil,
            categories: [
                PromptCategory(name: "Teaching", sortOrder: 0)
            ]
        ) { _ in }
    }
}
