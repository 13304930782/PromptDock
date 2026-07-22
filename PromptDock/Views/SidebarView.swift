import SwiftUI

struct SidebarView: View {
    @Binding var selection: PromptSection
    let categories: [PromptCategory]
    let onCreateCategory: (String, CategoryIconDraft) -> Void
    let onMoveCategories: (IndexSet, Int) -> Void
    let onRenameCategory: (
        PromptCategory,
        String,
        CategoryIconDraft
    ) -> Void
    let onDeleteCategory: (PromptCategory) -> Void

    @State private var isCategoryEditorPresented = false
    @State private var editingCategoryID: UUID?
    @State private var categoryPendingDeletionID: UUID?
    @State private var isReorderHintPresented = false
    @State private var reorderHintToken: UUID?

    @AppStorage("categoryReorderHint.hasShown")
    private var hasShownReorderHint = false

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                ForEach(PromptSection.librarySections) { section in
                    navigationLabel(for: section)
                }
            }

            Section("Categories") {
                ForEach(categories) { category in
                    categoryLabel(category)
                }
                .onMove(perform: onMoveCategories)

                Button {
                    editingCategoryID = nil
                    isCategoryEditorPresented = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add Category")
                .popover(
                    isPresented: $isReorderHintPresented,
                    arrowEdge: .leading
                ) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Drag categories to reorder")
                                .font(.headline)
                            Text(
                                "Drag rows to reorder. Right-click a custom category to rename or delete it."
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    .padding(14)
                    .frame(width: 300, alignment: .leading)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PromptDock")
        .sheet(isPresented: $isCategoryEditorPresented) {
            CategoryEditorView(category: editingCategory) { name, icon in
                if let editingCategory {
                    onRenameCategory(editingCategory, name, icon)
                } else {
                    onCreateCategory(name, icon)
                    presentReorderHintIfNeeded()
                }
                editingCategoryID = nil
            }
        }
        .confirmationDialog(
            "Delete Category?",
            isPresented: deletionIsPresented,
            presenting: categoryPendingDeletion
        ) { category in
            Button("Delete “\(category.name)”", role: .destructive) {
                onDeleteCategory(category)
                categoryPendingDeletionID = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            Text(
                "Prompts in “\(category.name)” will be kept and moved to another category."
            )
        }
    }

    @ViewBuilder
    private func categoryLabel(_ category: PromptCategory) -> some View {
        Label {
            Text(LocalizedStringKey(category.name))
        } icon: {
            CategoryIconView(category: category)
        }
        .tag(PromptSection.category(category.name))
        .help(
            category.isBuiltIn
                ? "Drag to reorder categories"
                : "Drag to reorder. Right-click to rename or delete."
        )
        .contextMenu {
            if !category.isBuiltIn {
                Button {
                    editingCategoryID = category.id
                    isCategoryEditorPresented = true
                } label: {
                    Label("Rename Category", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    categoryPendingDeletionID = category.id
                } label: {
                    Label("Delete Category", systemImage: "trash")
                }
            }
        }
    }

    private func navigationLabel(for section: PromptSection) -> some View {
        Label {
            Text(section.localizedTitle)
        } icon: {
            Image(systemName: section.systemImage)
        }
            .tag(section)
    }

    private func presentReorderHintIfNeeded() {
        guard !hasShownReorderHint else { return }

        hasShownReorderHint = true
        let token = UUID()
        reorderHintToken = token

        Task { @MainActor in
            await Task.yield()
            isReorderHintPresented = true
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard reorderHintToken == token else { return }
            isReorderHintPresented = false
            reorderHintToken = nil
        }
    }

    private var editingCategory: PromptCategory? {
        guard let editingCategoryID else { return nil }
        return categories.first { $0.id == editingCategoryID }
    }

    private var categoryPendingDeletion: PromptCategory? {
        guard let categoryPendingDeletionID else { return nil }
        return categories.first { $0.id == categoryPendingDeletionID }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { categoryPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    categoryPendingDeletionID = nil
                }
            }
        )
    }

}

private struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(
            selection: .constant(.all),
            categories: [
                PromptCategory(
                    name: "Teaching",
                    systemImage: "graduationcap",
                    sortOrder: 0,
                    isBuiltIn: true
                )
            ],
            onCreateCategory: { _, _ in },
            onMoveCategories: { _, _ in },
            onRenameCategory: { _, _, _ in },
            onDeleteCategory: { _ in }
        )
        .frame(width: 220, height: 500)
    }
}
