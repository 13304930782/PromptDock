import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextField("Title", text: $title)
                        .accessibilityLabel("Prompt Title")

                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { name in
                            Text(LocalizedStringKey(name)).tag(name)
                        }
                    }
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 220)
                        .accessibilityLabel("Prompt Content")
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
               $0.localizedCaseInsensitiveCompare(category) == .orderedSame
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
