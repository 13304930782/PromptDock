import SwiftData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    let prompt: Prompt?
    let searchText: String
    let isCopied: Bool
    @Binding var isCopyShortcutGuidePresented: Bool
    @State private var isHistoryPresented = false
    @State private var history: [PromptVersion] = []
    @State private var historyError: String?
    let hasLearnedCopyShortcut: Bool
    let usesChinese: Bool
    let onCopy: (Prompt) -> Void
    let onEdit: (Prompt) -> Void
    let onToggleFavorite: (Prompt) -> Void
    let onDelete: (Prompt) -> Void

    var body: some View {
        Group {
            if let prompt {
                let template = PromptTemplate(prompt.content)
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
                                    text: BuiltInCategoryPresentation.displayName(
                                        for: prompt.category,
                                        locale: locale
                                    ),
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
                            if template.hasVariables {
                                Label {
                                    Text(
                                        usesChinese
                                            ? "\(template.variables.count) 个变量"
                                            : "\(template.variables.count) variables"
                                    )
                                } icon: {
                                    Image(systemName: "curlybraces")
                                }
                                .help(
                                    usesChinese
                                        ? "复制前会请你填写这些变量。"
                                        : "You’ll fill these variables before copying."
                                )
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                onCopy(prompt)
                            } label: {
                                Label {
                                    Text(
                                        isCopied
                                            ? (usesChinese ? "已复制" : "Copied")
                                            : (template.hasVariables
                                                ? (usesChinese
                                                    ? "填写并复制"
                                                    : "Fill and Copy")
                                                : (usesChinese
                                                    ? "复制"
                                                    : "Copy"))
                                    )
                                } icon: {
                                    Image(
                                        systemName: isCopied
                                            ? "checkmark"
                                            : (template.hasVariables
                                                ? "curlybraces"
                                                : "doc.on.doc")
                                    )
                                }
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

                            Button {
                                loadHistory(for: prompt)
                            } label: {
                                Label("History", systemImage: "clock.arrow.circlepath")
                            }
                            .help("View Prompt History")

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
        .sheet(isPresented: $isHistoryPresented) {
            PromptHistoryView(prompt: prompt, versions: history) {
                isHistoryPresented = false
            }
        }
        .alert("Unable to Load History", isPresented: Binding(
            get: { historyError != nil },
            set: { if !$0 { historyError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(historyError ?? "")
        }
        .frame(minWidth: 360)
    }

    private func loadHistory(for prompt: Prompt) {
        do {
            let promptID = prompt.id
            history = try modelContext.fetch(FetchDescriptor<PromptVersion>(
                predicate: #Predicate { $0.promptID == promptID },
                sortBy: [SortDescriptor(\PromptVersion.createdAt, order: .reverse)]
            ))
            isHistoryPresented = true
        } catch {
            historyError = error.localizedDescription
        }
    }
}

private struct PromptHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: Prompt?
    let versions: [PromptVersion]
    let onClose: () -> Void
    @State private var selectedVersion: PromptVersion?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Version History")
                    .font(.title2.bold())
                Spacer()
                Button("Done", action: onClose)
            }

            if versions.isEmpty {
                ContentUnavailableView("No Saved Versions", systemImage: "clock.arrow.circlepath", description: Text("A version appears after you save a change."))
            } else {
                List(versions) { version in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(version.title).font(.headline)
                        Text(version.createdAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(version.content)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedVersion = version }
                    .background {
                        if selectedVersion?.id == version.id {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.12))
                        }
                    }
                }
                .frame(minHeight: 260)

                if let selectedVersion {
                    GroupBox("Preview") {
                        ScrollView {
                            Text(selectedVersion.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 120)
                    }

                    HStack {
                        Spacer()
                        Button("Restore This Version") {
                            restore(selectedVersion)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: versions.isEmpty ? 360 : 560)
        .alert("Unable to Restore", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func restore(_ version: PromptVersion) {
        guard let prompt else { return }
        do {
            try Phase1Service.restore(version, to: prompt, in: modelContext)
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
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
