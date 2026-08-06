import SwiftUI

struct PromptTagDraft {
    var name = ""
    var color: PromptTagColor = .blue
}

struct SmartCollectionDraft {
    var name = ""
    var query = ""
    var category: String?
    var tagIDs: Set<UUID> = []
    var favoriteOnly = false
    var updatedWithinDays: Int?
    var matchAll = true
}

struct SidebarView: View {
    @Environment(\.locale) private var locale
    @Binding var selection: PromptSection
    let categories: [PromptCategory]
    let tags: [PromptTag]
    let collections: [SmartCollection]
    let usesChinese: Bool
    let onCreateCategory: (String, CategoryIconDraft) -> Void
    let onMoveCategories: (IndexSet, Int) -> Void
    let onRenameCategory: (PromptCategory, String, CategoryIconDraft) -> Void
    let onDeleteCategory: (PromptCategory) -> Void
    let onSaveTag: (PromptTag?, PromptTagDraft) -> Void
    let onDeleteTag: (PromptTag) -> Void
    let onSaveCollection: (SmartCollection?, SmartCollectionDraft) -> Void
    let onDeleteCollection: (SmartCollection) -> Void

    @State private var isCategoryEditorPresented = false
    @State private var editingCategoryID: UUID?
    @State private var categoryPendingDeletionID: UUID?
    @State private var editingTagID: UUID?
    @State private var isTagEditorPresented = false
    @State private var tagPendingDeletionID: UUID?
    @State private var editingCollectionID: UUID?
    @State private var isCollectionEditorPresented = false
    @State private var collectionPendingDeletionID: UUID?
    @State private var libraryExpanded = true
    @State private var collectionsExpanded = true
    @State private var categoriesExpanded = true
    @State private var tagsExpanded = true

    var body: some View {
        List(selection: $selection) {
            Section(isExpanded: $libraryExpanded) {
                ForEach(PromptSection.librarySections) { section in
                    navigationLabel(for: section)
                }
            } header: { Text(usesChinese ? "资料库" : "Library") }

            Section(isExpanded: $collectionsExpanded) {
                ForEach(collections) { collection in
                    Label(collection.name, systemImage: "square.stack.3d.up")
                        .tag(PromptSection.smartCollection(collection.id, collection.name))
                        .contextMenu {
                            editButton { edit(collection) }
                            deleteButton { collectionPendingDeletionID = collection.id }
                        }
                }
                addButton(usesChinese ? "添加智能集合" : "Add Smart Collection") {
                    editingCollectionID = nil
                    isCollectionEditorPresented = true
                }
            } header: { Text(usesChinese ? "智能集合" : "Smart Collections") }

            Section(isExpanded: $categoriesExpanded) {
                ForEach(categories) { category in categoryLabel(category) }
                    .onMove(perform: onMoveCategories)
                addButton(usesChinese ? "添加分类" : "Add Category") {
                    editingCategoryID = nil
                    isCategoryEditorPresented = true
                }
            } header: { Text(usesChinese ? "分类" : "Categories") }

            Section(isExpanded: $tagsExpanded) {
                ForEach(tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Image(systemName: "tag.fill").foregroundStyle(color(for: tag.color))
                    }
                    .tag(PromptSection.tag(tag.id, tag.name))
                    .contextMenu {
                        editButton { edit(tag) }
                        deleteButton { tagPendingDeletionID = tag.id }
                    }
                }
                addButton(usesChinese ? "添加标签" : "Add Tag") {
                    editingTagID = nil
                    isTagEditorPresented = true
                }
            } header: { Text(usesChinese ? "标签" : "Tags") }
        }
        .listStyle(.sidebar)
        .navigationTitle("PromptDock")
        .sheet(isPresented: $isCategoryEditorPresented) {
            CategoryEditorView(category: editingCategory) { name, icon in
                if let editingCategory { onRenameCategory(editingCategory, name, icon) }
                else { onCreateCategory(name, icon) }
            }
        }
        .sheet(isPresented: $isTagEditorPresented) {
            TagEditorSheet(tag: editingTag, usesChinese: usesChinese) { draft in
                onSaveTag(editingTag, draft)
            }
        }
        .sheet(isPresented: $isCollectionEditorPresented) {
            SmartCollectionEditorSheet(
                collection: editingCollection,
                categories: categories,
                tags: tags,
                usesChinese: usesChinese
            ) { draft in
                onSaveCollection(editingCollection, draft)
            }
        }
        .confirmationDialog(usesChinese ? "删除分类？" : "Delete Category?", isPresented: categoryDeletionPresented, presenting: categoryPendingDeletion) { category in
            Button(usesChinese ? "删除“\(displayName(for: category))”" : "Delete “\(displayName(for: category))”", role: .destructive) {
                onDeleteCategory(category); categoryPendingDeletionID = nil
            }
        }
        .confirmationDialog(usesChinese ? "删除标签？" : "Delete Tag?", isPresented: tagDeletionPresented, presenting: tagPendingDeletion) { tag in
            Button(usesChinese ? "删除“\(tag.name)”" : "Delete “\(tag.name)”", role: .destructive) {
                onDeleteTag(tag); tagPendingDeletionID = nil
            }
        } message: { _ in Text(usesChinese ? "提示词不会被删除。" : "Prompts will not be deleted.") }
        .confirmationDialog(usesChinese ? "删除智能集合？" : "Delete Smart Collection?", isPresented: collectionDeletionPresented, presenting: collectionPendingDeletion) { collection in
            Button(usesChinese ? "删除“\(collection.name)”" : "Delete “\(collection.name)”", role: .destructive) {
                onDeleteCollection(collection); collectionPendingDeletionID = nil
            }
        } message: { _ in Text(usesChinese ? "集合中的提示词不会被删除。" : "Prompts in the collection will not be deleted.") }
    }

    private func categoryLabel(_ category: PromptCategory) -> some View {
        Label { Text(displayName(for: category)) } icon: { CategoryIconView(category: category) }
            .tag(PromptSection.category(category.name))
            .contextMenu {
                if !category.isBuiltIn {
                    editButton { editingCategoryID = category.id; isCategoryEditorPresented = true }
                    deleteButton { categoryPendingDeletionID = category.id }
                }
            }
    }

    private func navigationLabel(for section: PromptSection) -> some View {
        Label(LocalizedStringKey(section.title), systemImage: section.systemImage).tag(section)
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: "plus") }
            .buttonStyle(.plain).foregroundStyle(.secondary)
    }

    private func editButton(action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(usesChinese ? "编辑" : "Edit", systemImage: "pencil") }
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) { Label(usesChinese ? "删除" : "Delete", systemImage: "trash") }
    }

    private func edit(_ tag: PromptTag) { editingTagID = tag.id; isTagEditorPresented = true }
    private func edit(_ collection: SmartCollection) { editingCollectionID = collection.id; isCollectionEditorPresented = true }
    private func displayName(for category: PromptCategory) -> String { BuiltInCategoryPresentation.displayName(for: category.name, locale: locale) }
    private func color(for value: PromptTagColor) -> Color {
        switch value { case .gray: .gray; case .red: .red; case .orange: .orange; case .yellow: .yellow; case .green: .green; case .blue: .blue; case .purple: .purple }
    }
    private var editingCategory: PromptCategory? { categories.first { $0.id == editingCategoryID } }
    private var categoryPendingDeletion: PromptCategory? { categories.first { $0.id == categoryPendingDeletionID } }
    private var editingTag: PromptTag? { tags.first { $0.id == editingTagID } }
    private var tagPendingDeletion: PromptTag? { tags.first { $0.id == tagPendingDeletionID } }
    private var editingCollection: SmartCollection? { collections.first { $0.id == editingCollectionID } }
    private var collectionPendingDeletion: SmartCollection? { collections.first { $0.id == collectionPendingDeletionID } }
    private var categoryDeletionPresented: Binding<Bool> { presented(categoryPendingDeletionID, clear: { categoryPendingDeletionID = nil }) }
    private var tagDeletionPresented: Binding<Bool> { presented(tagPendingDeletionID, clear: { tagPendingDeletionID = nil }) }
    private var collectionDeletionPresented: Binding<Bool> { presented(collectionPendingDeletionID, clear: { collectionPendingDeletionID = nil }) }
    private func presented(_ id: UUID?, clear: @escaping () -> Void) -> Binding<Bool> { Binding(get: { id != nil }, set: { if !$0 { clear() } }) }
}

private struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tag: PromptTag?
    let usesChinese: Bool
    let onSave: (PromptTagDraft) -> Void
    @State private var draft: PromptTagDraft

    init(tag: PromptTag?, usesChinese: Bool, onSave: @escaping (PromptTagDraft) -> Void) {
        self.tag = tag; self.usesChinese = usesChinese; self.onSave = onSave
        _draft = State(initialValue: PromptTagDraft(name: tag?.name ?? "", color: tag?.color ?? .blue))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(tag == nil ? (usesChinese ? "新建标签" : "New Tag") : (usesChinese ? "编辑标签" : "Edit Tag")).font(.title2.bold())
            TextField(usesChinese ? "名称" : "Name", text: $draft.name)
            Picker(usesChinese ? "颜色" : "Color", selection: $draft.color) {
                ForEach(PromptTagColor.allCases) { color in Text(color.rawValue.capitalized).tag(color) }
            }
            HStack { Spacer(); Button(usesChinese ? "取消" : "Cancel") { dismiss() }; Button(usesChinese ? "保存" : "Save") { onSave(draft); dismiss() }.buttonStyle(.borderedProminent).disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 380)
    }
}

private struct SmartCollectionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let collection: SmartCollection?
    let categories: [PromptCategory]
    let tags: [PromptTag]
    let usesChinese: Bool
    let onSave: (SmartCollectionDraft) -> Void
    @State private var draft: SmartCollectionDraft

    init(collection: SmartCollection?, categories: [PromptCategory], tags: [PromptTag], usesChinese: Bool, onSave: @escaping (SmartCollectionDraft) -> Void) {
        self.collection = collection; self.categories = categories; self.tags = tags; self.usesChinese = usesChinese; self.onSave = onSave
        _draft = State(initialValue: SmartCollectionDraft(name: collection?.name ?? "", query: collection?.query ?? "", category: collection?.category, tagIDs: Set(collection?.tagIDs ?? []), favoriteOnly: collection?.favoriteOnly ?? false, updatedWithinDays: collection?.updatedWithinDays, matchAll: collection?.matchAll ?? true))
    }
    var body: some View {
        Form {
            TextField(usesChinese ? "集合名称" : "Collection Name", text: $draft.name)
            Picker(usesChinese ? "条件" : "Conditions", selection: $draft.matchAll) {
                Text(usesChinese ? "满足全部条件" : "Match All").tag(true)
                Text(usesChinese ? "满足任一条件" : "Match Any").tag(false)
            }
            TextField(usesChinese ? "搜索词（可选）" : "Search Text (Optional)", text: $draft.query)
            Picker(usesChinese ? "分类" : "Category", selection: $draft.category) {
                Text(usesChinese ? "任意分类" : "Any Category").tag(String?.none)
                ForEach(categories) { Text($0.name).tag(Optional($0.name)) }
            }
            Toggle(usesChinese ? "仅收藏" : "Favorites Only", isOn: $draft.favoriteOnly)
            Picker(usesChinese ? "更新时间" : "Updated", selection: $draft.updatedWithinDays) {
                Text(usesChinese ? "不限" : "Any Time").tag(Int?.none)
                Text(usesChinese ? "最近 7 天" : "Last 7 Days").tag(Optional(7))
                Text(usesChinese ? "最近 30 天" : "Last 30 Days").tag(Optional(30))
            }
            Section(usesChinese ? "标签" : "Tags") {
                ForEach(tags) { tag in Toggle(tag.name, isOn: Binding(get: { draft.tagIDs.contains(tag.id) }, set: { if $0 { draft.tagIDs.insert(tag.id) } else { draft.tagIDs.remove(tag.id) } })) }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) { HStack { Spacer(); Button(usesChinese ? "取消" : "Cancel") { dismiss() }; Button(usesChinese ? "保存" : "Save") { onSave(draft); dismiss() }.buttonStyle(.borderedProminent).disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding() }
        .frame(width: 500, height: 580)
    }
}

private struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selection: .constant(.all), categories: [], tags: [], collections: [], usesChinese: false, onCreateCategory: { _, _ in }, onMoveCategories: { _, _ in }, onRenameCategory: { _, _, _ in }, onDeleteCategory: { _ in }, onSaveTag: { _, _ in }, onDeleteTag: { _ in }, onSaveCollection: { _, _ in }, onDeleteCollection: { _ in }).frame(width: 240, height: 600)
    }
}
