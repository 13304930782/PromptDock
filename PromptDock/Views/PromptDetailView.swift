import SwiftUI

struct PromptDetailView: View {
    let prompt: Prompt?
    let searchText: String
    let isCopied: Bool
    @Binding var isCopyShortcutGuidePresented: Bool
    let hasLearnedCopyShortcut: Bool
    let usesChinese: Bool
    let onCopy: (Prompt) -> Void
    let onEdit: (Prompt) -> Void
    let onToggleFavorite: (Prompt) -> Void
    let onDelete: (Prompt) -> Void

    var body: some View {
        Group {
            if let prompt {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SearchHighlightedText(
                            text: prompt.title,
                            query: searchText
                        )
                            .font(.title)
                            .fontWeight(.semibold)
                            .textSelection(.enabled)

                        HStack(spacing: 16) {
                            Label {
                                SearchHighlightedText(
                                    text: prompt.category,
                                    query: searchText
                                )
                            } icon: {
                                Image(systemName: "folder")
                            }
                            Label {
                                Text(
                                    prompt.updatedDate,
                                    format: .dateTime
                                        .year()
                                        .month()
                                        .day()
                                        .hour()
                                        .minute()
                                )
                            } icon: {
                                Image(systemName: "clock")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                onCopy(prompt)
                            } label: {
                                Label(
                                    isCopied ? "Copied" : "Copy",
                                    systemImage: isCopied
                                        ? "checkmark"
                                        : "doc.on.doc"
                                )
                            }
                            .help("Copy Prompt (Shift-Command-C)")
                            .popover(
                                isPresented: $isCopyShortcutGuidePresented,
                                arrowEdge: .top
                            ) {
                                ShortcutGuidePopover(
                                    title: usesChinese
                                        ? "复制快捷键"
                                        : "Copy shortcut",
                                    message: hasLearnedCopyShortcut
                                        ? (usesChinese
                                            ? "按对了，快捷键已掌握。"
                                            : "That’s it — shortcut learned.")
                                        : (usesChinese
                                            ? "试着按下这个组合键。"
                                            : "Try pressing this key combination."),
                                    items: [
                                        ShortcutGuideItem(
                                            shortcut: .copyPrompt,
                                            title: usesChinese
                                                ? "复制所选提示词"
                                                : "Copy selected prompt",
                                            keys: "⇧⌘C",
                                            isCompleted: hasLearnedCopyShortcut
                                        )
                                    ]
                                )
                            }

                            Button {
                                onEdit(prompt)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .help("Edit Prompt (Command-E)")

                            Button {
                                onToggleFavorite(prompt)
                            } label: {
                                Label(
                                    prompt.isFavorite
                                        ? "Unfavorite"
                                        : "Favorite",
                                    systemImage: prompt.isFavorite
                                        ? "star.slash"
                                        : "star"
                                )
                            }
                            .help("Add or Remove from Favorites (Shift-Command-F)")

                            Spacer()

                            Button(role: .destructive) {
                                onDelete(prompt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .help("Delete Prompt")
                        }

                        Divider()

                        SearchHighlightedText(
                            text: prompt.content,
                            query: searchText
                        )
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(24)
                }
                .navigationTitle(prompt.title)
            } else {
                ContentUnavailableView(
                    "Select a Prompt",
                    systemImage: "text.bubble",
                    description: Text(
                        "Choose a prompt from the list to view its contents."
                    )
                )
            }
        }
        .frame(minWidth: 360)
    }
}

private struct PromptDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PromptDetailView(
            prompt: Prompt(
                title: "Explain SwiftData",
                category: "Coding",
                content: "Explain SwiftData with a practical example."
            ),
            searchText: "SwiftData",
            isCopied: false,
            isCopyShortcutGuidePresented: .constant(false),
            hasLearnedCopyShortcut: false,
            usesChinese: false,
            onCopy: { _ in },
            onEdit: { _ in },
            onToggleFavorite: { _ in },
            onDelete: { _ in }
        )
        .frame(width: 520, height: 500)
    }
}
