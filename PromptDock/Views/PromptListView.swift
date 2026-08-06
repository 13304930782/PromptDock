import SwiftUI

struct PromptListView: View {
    let section: PromptSection
    let prompts: [Prompt]
    @Binding var selection: Set<UUID>
    @Binding var searchText: String
    let onCreate: () -> Void
    let onCopy: (Prompt) -> Void
    let onEdit: (Prompt) -> Void
    let onToggleFavorite: (Prompt) -> Void
    let onDelete: (Prompt) -> Void

    var body: some View {
        Group {
            if prompts.isEmpty {
                ContentUnavailableView {
                    Label(
                        emptyStateTitle,
                        systemImage: emptyStateSystemImage
                    )
                } description: {
                    emptyStateDescription
                } actions: {
                    if hasSearchQuery {
                        Button("Clear Search") {
                            searchText = ""
                        }
                    } else {
                        Button("New Prompt") {
                            onCreate()
                        }
                    }
                }
            } else {
                List(prompts, selection: $selection) { prompt in
                    PromptRowView(
                        prompt: prompt,
                        searchText: searchText
                    )
                        .tag(prompt.id)
                        .onTapGesture(count: 2) {
                            onEdit(prompt)
                        }
                        .contextMenu {
                            Button {
                                onCopy(prompt)
                            } label: {
                                Label(
                                    "Copy Prompt",
                                    systemImage: "doc.on.doc"
                                )
                            }

                            Divider()

                            Button {
                                onEdit(prompt)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

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

                            Divider()

                            Button(role: .destructive) {
                                onDelete(prompt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(Text(section.localizedTitle))
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Search Prompts"
        )
    }

    private var emptyStateTitle: LocalizedStringKey {
        guard !hasSearchQuery else { return "No Results" }
        return section == .all
            ? "No Prompts"
            : "No Prompts in This Category"
    }

    private var emptyStateSystemImage: String {
        hasSearchQuery ? "magnifyingglass" : section.systemImage
    }

    @ViewBuilder
    private var emptyStateDescription: some View {
        if hasSearchQuery {
            Text(
                "No prompts match “\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))”."
            )
        } else if section == .all {
            Text(
                "Create your first prompt to start building your AI workflow library."
            )
        } else {
            Text("Prompts in this section will appear here.")
        }
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }
}

private struct PromptRowView: View {
    @Environment(\.locale) private var locale
    let prompt: Prompt
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                SearchHighlightedText(
                    text: prompt.title,
                    query: searchText
                )
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Favorite")
                }
            }

            HStack {
                SearchHighlightedText(
                    text: BuiltInCategoryPresentation.displayName(
                        for: prompt.category,
                        locale: locale
                    ),
                    query: searchText
                )
                    .lineLimit(1)

                Spacer()

                Text(prompt.updatedDate, style: .relative)
                    .accessibilityLabel(
                        "Updated \(prompt.updatedDate.formatted(date: .abbreviated, time: .shortened))"
                    )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct PromptListView_Previews: PreviewProvider {
    static var previews: some View {
        PromptListView(
            section: .all,
            prompts: [
                Prompt(
                    title: "Explain SwiftData",
                    category: "Coding",
                    content: "Explain SwiftData with a practical example.",
                    isFavorite: true
                )
            ],
            selection: .constant([]),
            searchText: .constant(""),
            onCreate: {},
            onCopy: { _ in },
            onEdit: { _ in },
            onToggleFavorite: { _ in },
            onDelete: { _ in }
        )
        .frame(width: 320, height: 500)
    }
}
