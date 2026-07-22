import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let category: PromptCategory?
    let onSave: (String, CategoryIconDraft) -> Void

    @State private var name: String
    @State private var iconKind: CategoryIconKind
    @State private var emoji: String
    @State private var imageData: Data?
    @State private var isImporterPresented = false
    @State private var errorMessage: String?
    @FocusState private var isEmojiFieldFocused: Bool

    init(
        category: PromptCategory?,
        onSave: @escaping (String, CategoryIconDraft) -> Void
    ) {
        self.category = category
        self.onSave = onSave
        let draft = category.map(CategoryIconDraft.init(category:))
            ?? .defaultEmoji
        _name = State(initialValue: category?.name ?? "")
        _iconKind = State(initialValue: draft.kind)
        _emoji = State(initialValue: draft.emoji ?? "📁")
        _imageData = State(initialValue: draft.imageData)
    }

    private var iconDraft: CategoryIconDraft {
        CategoryIconDraft(
            kind: iconKind,
            emoji: iconKind == .emoji ? normalizedEmoji : nil,
            imageData: iconKind == .localImage ? imageData : nil
        )
    }

    private var normalizedEmoji: String? {
        guard let character = emoji.first else { return nil }
        let candidate = String(character)
        guard character.unicodeScalars.contains(where: {
            $0.properties.isEmoji || $0.properties.isEmojiPresentation
        }) else { return nil }
        return candidate
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (iconKind != .emoji || normalizedEmoji != nil)
            && (iconKind != .localImage || imageData != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Category Name", text: $name)
                        .accessibilityLabel("Category Name")
                }

                Section("Icon") {
                    HStack(spacing: 14) {
                        CategoryIconPreview(draft: iconDraft)

                        Picker("Icon Type", selection: $iconKind) {
                            Text("Emoji").tag(CategoryIconKind.emoji)
                            Text("Local Image").tag(CategoryIconKind.localImage)
                        }
                        .pickerStyle(.segmented)
                    }

                    if iconKind == .emoji {
                        HStack {
                            TextField("Emoji", text: $emoji)
                                .focused($isEmojiFieldFocused)
                                .frame(width: 90)
                                .onChange(of: emoji) { _, newValue in
                                    let firstCharacter = newValue.first.map(String.init)
                                        ?? ""
                                    if newValue != firstCharacter {
                                        emoji = firstCharacter
                                    }
                                }

                            Button("Choose Emoji…") {
                                isEmojiFieldFocused = true
                                NSApp.orderFrontCharacterPalette(nil)
                            }
                        }

                        Text("Choose one emoji from the macOS character palette.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if iconKind == .localImage {
                        HStack {
                            Button(imageData == nil ? "Choose Image…" : "Replace Image…") {
                                isImporterPresented = true
                            }

                            if imageData != nil {
                                Button("Use Default Emoji") {
                                    imageData = nil
                                    emoji = "📁"
                                    iconKind = .emoji
                                }
                            }
                        }

                        Text(
                            "The icon is stored only on this Mac. PromptDock does not upload it."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, iconDraft)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            importImage(result)
        }
        .alert("Unable to Use Image", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func importImage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            let data: Data
            do {
                data = try BoundedFileReader.read(
                    url: url,
                    maximumByteCount: CategoryImageProcessor.maximumSourceByteCount
                )
            } catch BoundedFileReaderError.fileTooLarge {
                throw CategoryImageError.fileTooLarge
            }
            imageData = try CategoryImageProcessor.process(data)
            iconKind = .localImage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
