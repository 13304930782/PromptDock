import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Prompt.updatedDate, order: .reverse)
    private var allPrompts: [Prompt]
    @Query private var trashEntries: [TrashEntry]
    private var prompts: [Prompt] {
        let deleted = Set(trashEntries.map(\.promptID))
        return allPrompts.filter { !deleted.contains($0.id) }
    }

    @Query(sort: [
        SortDescriptor(\PromptCategory.sortOrder),
        SortDescriptor(\PromptCategory.createdDate)
    ])
    private var categories: [PromptCategory]

    @Query(sort: \PromptTag.createdAt) private var tags: [PromptTag]
    @Query(sort: \SmartCollection.createdAt) private var collections: [SmartCollection]
    @Query(sort: \TemplateVariableDefinition.order) private var variableDefinitions: [TemplateVariableDefinition]

    @AppStorage(AppLanguage.storageKey)
    private var languageRawValue = AppLanguage.system.rawValue

    @StateObject private var viewModel = PromptViewModel()
    @StateObject private var searchController = PromptSearchController()
    @State private var showsTransfer = false
    @State private var importedIDs: Set<UUID>?
    @State private var recentUsageIDs: [UUID] = []
    @State private var editorRequest: PromptEditorRequest?
    @State private var promptPendingDeletionID: UUID?
    @State private var actionErrorMessage: String?
    @State private var copiedPromptID: UUID?
    @State private var copyFeedbackToken: UUID?
    @State private var templateCopyRequest: PromptTemplateCopyRequest?
    @State private var isBulkDeletePresented = false
    @State private var rewritePromptID: UUID?
    @State private var rewriteBaseline: Date?
    @State private var rewriteDraft: PromptDraft?
    @State private var contentSize = CGSize(width: 760, height: 520)
    @State private var rewriteSize = CGSize(width: 712, height: 472)
    @State private var isCopyShortcutGuidePresented = false
    @State private var isSearchShortcutGuidePresented = false
    @State private var copyShortcutGuideToken: UUID?
    @State private var searchShortcutGuideToken: UUID?
    @State private var shortcutSuccessMessage: String?
    @State private var shortcutSuccessToken: UUID?

    @AppStorage(ShortcutLearningStorage.copyPrompt)
    private var hasLearnedCopyShortcut = false
    @AppStorage(ShortcutLearningStorage.nextSearchResult)
    private var hasLearnedNextSearchShortcut = false
    @AppStorage(ShortcutLearningStorage.previousSearchResult)
    private var hasLearnedPreviousSearchShortcut = false

    private let clipboardService = ClipboardService()

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var sectionPrompts: [Prompt] {
        viewModel.filteredPrompts(from: importedIDs.map { ids in prompts.filter { ids.contains($0.id) } } ?? prompts, tags: tags, collections: collections,
            locale: selectedLanguage.locale, applySearch: false, recentIDs: recentUsageIDs)
    }

    private var searchInput: PromptSearchInput {
        guard !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return PromptSearchInput(snapshots: [], query: viewModel.searchText, localeIdentifier: selectedLanguage.locale.identifier)
        }
        return PromptSearchInput(snapshots: PromptSearchService.snapshots(sectionPrompts, tags: tags, locale: selectedLanguage.locale),
            query: viewModel.searchText, localeIdentifier: selectedLanguage.locale.identifier)
    }

    private var visiblePrompts: [Prompt] {
        guard viewModel.hasSearchQuery else { return sectionPrompts }
        guard searchController.completedInput == searchInput else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: sectionPrompts.map { ($0.id, $0) })
        return searchController.ids.compactMap { byID[$0] }
    }

    private var visiblePromptIDs: [UUID] {
        visiblePrompts.map(\.id)
    }

    private var widgetSnapshotRevision: [WidgetSnapshotRevision] {
        prompts.map {
            WidgetSnapshotRevision(
                id: $0.id,
                updatedDate: $0.updatedDate,
                isFavorite: $0.isFavorite
            )
        }
    }

    private var promptPendingDeletion: Prompt? {
        guard let promptPendingDeletionID else { return nil }
        return prompts.first { $0.id == promptPendingDeletionID }
    }

    private var rewritePrompt: Prompt? {
        guard let rewritePromptID else { return nil }
        return prompts.first { $0.id == rewritePromptID }
    }

    private var selectedPrompt: Prompt? {
        viewModel.selectedPrompt(in: prompts)
    }

    private var selectedPrompts: [Prompt] {
        prompts.filter { viewModel.selectedPromptIDs.contains($0.id) }
    }

    private var commandActions: PromptCommandActions {
        PromptCommandActions(
            selectedPromptTitle: selectedPrompt?.title,
            selectedPromptCount: selectedPrompts.count,
            areSelectedPromptsFavorite: !selectedPrompts.isEmpty && selectedPrompts.allSatisfy(\.isFavorite),
            categoryChoices: categories.map { category in
                PromptCommandChoice(id: category.id.uuidString, title: category.name) {
                    bulkMove(category.name)
                }
            },
            addTagChoices: tags.map { tag in
                PromptCommandChoice(id: tag.id.uuidString, title: tag.name) {
                    bulkSetTag(tag, true)
                }
            },
            removeTagChoices: tags.map { tag in
                PromptCommandChoice(id: tag.id.uuidString, title: tag.name) {
                    bulkSetTag(tag, false)
                }
            },
            createPrompt: { presentEditor(for: nil) },
            copySelectedPrompt: {
                guard selectedPrompts.count == 1, let selectedPrompt else { return }
                copy(selectedPrompt)
            },
            editSelectedPrompt: {
                guard selectedPrompts.count == 1, let selectedPrompt else { return }
                presentEditor(for: selectedPrompt)
            },
            toggleSelectedPromptFavorite: {
                guard !selectedPrompts.isEmpty else { return }
                if selectedPrompts.count == 1, let selectedPrompt {
                    toggleFavorite(for: selectedPrompt)
                } else {
                    bulkSetFavorite(!selectedPrompts.allSatisfy(\.isFavorite))
                }
            },
            deleteSelectedPrompt: {
                guard !selectedPrompts.isEmpty else { return }
                if selectedPrompts.count == 1, let selectedPrompt {
                    requestDeletion(of: selectedPrompt)
                } else {
                    isBulkDeletePresented = true
                }
            }
        )
    }

    private var totalSearchMatchCount: Int {
        guard viewModel.hasSearchQuery else { return 0 }

        return visiblePrompts.reduce(into: 0) { count, prompt in
            count += SearchHighlighter.matchCount(
                in: prompt.title,
                query: viewModel.searchText
            )
            count += SearchHighlighter.matchCount(
                in: BuiltInCategoryPresentation.displayName(
                    for: prompt.category,
                    locale: selectedLanguage.locale
                ),
                query: viewModel.searchText
            )
            count += SearchHighlighter.matchCount(
                in: prompt.content,
                query: viewModel.searchText
            )
        }
    }

    private var searchMatchDescription: String {
        if selectedLanguage.usesChinese {
            return "\(totalSearchMatchCount) 处匹配"
        }

        let noun = totalSearchMatchCount == 1 ? "match" : "matches"
        return "\(totalSearchMatchCount) \(noun)"
    }

    private var searchResultPositionDescription: String {
        let position = viewModel.searchResultPosition(in: visiblePrompts)
        guard selectedLanguage.usesChinese else { return position }
        return position.replacingOccurrences(of: " of ", with: "/")
    }

    private var libraryContent: some View {
        NavigationSplitView {
            SidebarView(
                selection: $viewModel.selectedSection,
                categories: categories,
                tags: tags,
                collections: collections,
                usesChinese: selectedLanguage.usesChinese,
                onCreateCategory: createCategory,
                onMoveCategories: moveCategories,
                onRenameCategory: renameCategory,
                onDeleteCategory: deleteCategory,
                onSaveTag: saveTag,
                onDeleteTag: deleteTag,
                onSaveCollection: saveCollection,
                onDeleteCollection: deleteCollection
            )
                .navigationSplitViewColumnWidth(
                    min: 180,
                    ideal: 220,
                    max: 280
                )
        } content: {
            if viewModel.selectedSection == .trash {
                TrashLibraryView()
                    .navigationTitle(Text("Trash"))
                    .navigationSplitViewColumnWidth(min: 320, ideal: 450, max: 600)
            } else {
            PromptListView(
                section: viewModel.selectedSection,
                prompts: visiblePrompts,
                selection: Binding(
                    get: { viewModel.selectedPromptIDs },
                    set: { viewModel.updateSelection($0, orderedBy: visiblePromptIDs) }
                ),
                searchText: $viewModel.searchText,
                onCreate: { presentEditor(for: nil) },
                onCopy: copy,
                onEdit: { presentEditor(for: $0) },
                onToggleFavorite: { toggleFavorite(for: $0) },
                onDelete: { requestDeletion(of: $0) },
                onImport: { showsTransfer = true },
                onSamples: prompts.isEmpty ? addSamples : nil,
                onDuplicate: duplicate
            )
            .navigationSplitViewColumnWidth(
                min: 260,
                ideal: 320,
                max: 440
            )
            }
        } detail: {
            if viewModel.selectedSection == .trash {
                ContentUnavailableView("Trash", systemImage: "trash", description: Text("Restore prompts to use them again."))
            } else if selectedPrompts.count > 1 {
                BulkPromptActionsView(
                    prompts: selectedPrompts,
                    categories: categories,
                    tags: tags,
                    usesChinese: selectedLanguage.usesChinese,
                    onMove: bulkMove,
                    onSetTag: bulkSetTag,
                    onSetFavorite: bulkSetFavorite,
                    onDelete: { isBulkDeletePresented = true }
                )
            } else {
                PromptDetailView(
                    prompt: selectedPrompt,
                    searchText: viewModel.searchText,
                    isCopied: copiedPromptID == viewModel.selectedPromptID,
                    isCopyShortcutGuidePresented: $isCopyShortcutGuidePresented,
                    hasLearnedCopyShortcut: hasLearnedCopyShortcut,
                    usesChinese: selectedLanguage.usesChinese,
                    onCopy: copy,
                    onEdit: { presentEditor(for: $0) },
                    onRewrite: presentRewrite,
                    onToggleFavorite: { toggleFavorite(for: $0) },
                    onDelete: { requestDeletion(of: $0) }
                )
            }
        }
        .onAppear { recentUsageIDs = RecentUsage.ids() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in recentUsageIDs = RecentUsage.ids() }
        .onReceive(NotificationCenter.default.publisher(for: .init("PromptDock.showImported"))) { notification in
            if let ids = notification.object as? Set<UUID> { showImported(ids) }
        }
        .onChange(of: viewModel.selectedSection) { importedIDs = nil }
        .toolbar {
            if importedIDs != nil {
                ToolbarItem { Button("Show All Prompts") { importedIDs = nil } }
            }
            if viewModel.hasSearchQuery {
                ToolbarItemGroup(placement: .secondaryAction) {
                    Text(
                        "\(searchResultPositionDescription) · \(searchMatchDescription)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel(
                        "Search result \(searchResultPositionDescription), \(searchMatchDescription)"
                    )

                    Button {
                        viewModel.selectPreviousSearchResult(
                            in: visiblePrompts
                        )
                    } label: {
                        Label(
                            "Previous Search Result",
                            systemImage: "chevron.up"
                        )
                    }
                    .keyboardShortcut(
                        "g",
                        modifiers: [.command, .shift]
                    )
                    .disabled(visiblePrompts.isEmpty)
                    .help("Previous Search Result (Shift-Command-G)")

                    Button {
                        viewModel.selectNextSearchResult(
                            in: visiblePrompts
                        )
                    } label: {
                        Label(
                            "Next Search Result",
                            systemImage: "chevron.down"
                        )
                    }
                    .keyboardShortcut("g", modifiers: .command)
                    .disabled(visiblePrompts.isEmpty)
                    .help("Next Search Result (Command-G)")
                    .popover(
                        isPresented: $isSearchShortcutGuidePresented,
                        arrowEdge: .top
                    ) {
                        searchShortcutGuide
                    }
                }
            }

            ToolbarItem(placement: .automatic) {
                Button("Import / Export", systemImage: "square.and.arrow.up.on.square") { showsTransfer = true }
            }

            ToolbarItem(placement: .automatic) {
                LanguageMenu(selection: $languageRawValue)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentEditor(for: nil)
                } label: {
                    Label("Add Prompt", systemImage: "plus")
                }
                .help("New Prompt (Command-N)")
            }
        }
        .focusedSceneValue(\.promptCommandActions, commandActions)
        .background {
            ShortcutKeyMonitor(onShortcut: handleShortcut)
                .frame(width: 0, height: 0)
        }
        .overlay(alignment: .top) {
            if let shortcutSuccessMessage {
                ShortcutSuccessBanner(message: shortcutSuccessMessage)
                    .padding(.top, 12)
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
            }
        }
        .animation(.snappy, value: shortcutSuccessMessage)
    }

    private var mainContent: some View {
        libraryContent
        .sheet(isPresented: $showsTransfer) {
            TransferView(onShowImported: showImported, selectedIDs: viewModel.selectedPromptIDs, filteredIDs: Set(visiblePromptIDs))
        }
        .sheet(item: $editorRequest) { request in
            let editorPrompt = request.promptID.flatMap { promptID in
                prompts.first { $0.id == promptID }
            }

            EditorView(
                prompt: editorPrompt,
                categories: categories,
                tags: tags,
                selectedTagIDs: Set(tags.filter { tag in
                    editorPrompt.map { tag.promptIDs.contains($0.id) } ?? false
                }.map(\.id)),
                variableDefinitions: variableDefinitions.filter { $0.promptID == editorPrompt?.id },
                initialCategory: viewModel.preferredNewPromptCategory(
                    from: categories
                ),
                usesChinese: selectedLanguage.usesChinese
            ) { draft in
                if let editorPrompt {
                    try viewModel.updatePrompt(
                        editorPrompt,
                        from: draft,
                        tags: tags,
                        in: modelContext
                    )
                } else {
                    let createdPrompt = try viewModel.createPrompt(
                        from: draft,
                        tags: tags,
                        in: modelContext
                    )
                    viewModel.selectedSection = .all
                    viewModel.selectedPromptID = createdPrompt.id
                    viewModel.selectedPromptIDs = [createdPrompt.id]
                }
            }
        }
        .sheet(item: $templateCopyRequest) { request in
            PromptTemplateFillView(
                request: request,
                presentation: .sheet,
                usesChinese: selectedLanguage.usesChinese,
                onCancel: {
                    templateCopyRequest = nil
                },
                onCopy: { renderedPrompt in
                    let copied = copyToClipboard(
                        renderedPrompt,
                        promptID: request.promptID
                    )
                    if copied {
                        templateCopyRequest = nil
                    }
                    return copied
                }
            )
        }
        .sheet(isPresented: Binding(get: { rewritePromptID != nil }, set: { if !$0 { rewritePromptID = nil } })) {
            rewriteSheet
        }
        .confirmationDialog(
            "Delete Prompt?",
            isPresented: deletionIsPresented,
            presenting: promptPendingDeletion
        ) { prompt in
            Button("Delete “\(prompt.title)”", role: .destructive) {
                delete(prompt)
            }
            Button("Cancel", role: .cancel) {}
        } message: { prompt in
            Text(
                "This will move “\(prompt.title)” to Trash for 30 days. You can restore it from Settings."
            )
        }
        .confirmationDialog(
            selectedLanguage.usesChinese ? "删除 \(selectedPrompts.count) 条提示词？" : "Delete \(selectedPrompts.count) Prompts?",
            isPresented: $isBulkDeletePresented
        ) {
            Button(selectedLanguage.usesChinese ? "删除" : "Delete", role: .destructive) { bulkDelete() }
            Button(selectedLanguage.usesChinese ? "取消" : "Cancel", role: .cancel) {}
        }
        .alert(
            "Unable to Complete Action",
            isPresented: actionErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "An unknown error occurred.")
        }
        .onAppear {
            do { try TrashService.purgeExpired(in: modelContext) }
            catch { actionErrorMessage = error.localizedDescription }
            ensureCategories()
            viewModel.reconcileSelection(
                in: prompts,
                tags: tags,
                collections: collections,
                locale: selectedLanguage.locale
            )
            WidgetSnapshotService.refresh(from: prompts)
        }
        .onChange(of: viewModel.selectedSection) {
            viewModel.reconcileSelection(
                in: prompts,
                tags: tags,
                collections: collections,
                locale: selectedLanguage.locale
            )
        }
        .task(id: searchInput) { await searchController.search(searchInput) }
        .onChange(of: visiblePromptIDs) {
            viewModel.selectedPromptIDs.formIntersection(Set(visiblePromptIDs))
            if !visiblePromptIDs.contains(viewModel.selectedPromptID ?? UUID()) {
                viewModel.selectedPromptID = visiblePromptIDs.first
                viewModel.selectedPromptIDs = visiblePromptIDs.first.map { [$0] } ?? []
            }
        }
        .onChange(of: widgetSnapshotRevision) {
            WidgetSnapshotService.refresh(from: prompts)
        }
        .onChange(of: viewModel.searchText) { oldValue, newValue in
            let oldQuery = oldValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let newQuery = newValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard oldQuery.isEmpty, !newQuery.isEmpty else { return }
            if !hasLearnedNextSearchShortcut
                || !hasLearnedPreviousSearchShortcut {
                presentSearchShortcutGuide()
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    var body: some View {
        mainContent
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { contentSize = geometry.size }
                    .onChange(of: geometry.size) { _, size in contentSize = size }
            }
        }
    }

    @ViewBuilder
    private var rewriteSheet: some View {
        if let rewriteDraft {
            AIRewriteView(
                title: rewriteDraft.title,
                presentationSize: rewriteSize,
                originalContent: rewriteDraft.content,
                usesChinese: selectedLanguage.usesChinese,
                definitions: rewriteDraft.variableDefinitions,
                onSaveCopy: { text in
                    var copy = rewriteDraft; copy.content = text
                    _ = try viewModel.createPrompt(from: copy, tags: tags, in: modelContext)
                    rewritePromptID = nil
                }
            ) { rewritten in
                guard let rewritePrompt = allPrompts.first(where: { $0.id == rewritePromptID }) else { throw PromptValidationError.staleDraft }
                try LocalEditorDraft(promptID: rewritePrompt.id, baselineDate: rewriteBaseline, draft: rewriteDraft)
                    .requireUnchanged(currentDate: rewritePrompt.updatedDate, isDeleted: rewritePrompt.isDeleted || trashEntries.contains { $0.promptID == rewritePrompt.id })
                var draft = rewriteDraft
                draft.content = rewritten
                try viewModel.updatePrompt(rewritePrompt, from: draft, tags: tags, in: modelContext)
                rewritePromptID = nil
            }
        }
    }

    private func presentRewrite(for prompt: Prompt) {
        // Freeze before presentation to avoid parent/sheet size feedback.
        rewriteSize = CGSize(
            width: min(820, contentSize.width - 48),
            height: min(720, contentSize.height - 48)
        )
        rewriteBaseline = prompt.updatedDate
        rewriteDraft = draft(for: prompt)
        rewritePromptID = prompt.id
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { promptPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    promptPendingDeletionID = nil
                }
            }
        )
    }

    private var actionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    actionErrorMessage = nil
                }
            }
        )
    }

    private func presentEditor(for prompt: Prompt?) {
        editorRequest = PromptEditorRequest(promptID: prompt?.id)
    }

    private func requestDeletion(of prompt: Prompt) {
        promptPendingDeletionID = prompt.id
    }

    private func ensureCategories() {
        performAction {
            try CategoryService.ensureCategories(
                for: prompts,
                in: modelContext
            )
        }
    }

    private func createCategory(
        named name: String,
        icon: CategoryIconDraft
    ) {
        performAction {
            let category = try CategoryService.createCategory(
                named: name,
                icon: icon,
                in: modelContext
            )
            viewModel.selectedSection = .category(category.name)
        }
    }

    private func moveCategories(
        from source: IndexSet,
        to destination: Int
    ) {
        performAction {
            try CategoryService.moveCategories(
                categories,
                from: source,
                to: destination,
                in: modelContext
            )
        }
    }

    private func renameCategory(
        _ category: PromptCategory,
        to name: String,
        icon: CategoryIconDraft
    ) {
        let previousName = category.name

        performAction {
            let renamedName = try CategoryService.renameCategory(
                category,
                to: name,
                icon: icon,
                prompts: prompts,
                in: modelContext
            )

            if case .category(let selectedName) = viewModel.selectedSection,
               selectedName.localizedCaseInsensitiveCompare(previousName)
                == .orderedSame {
                viewModel.selectedSection = .category(renamedName)
            }
        }
    }

    private func deleteCategory(_ category: PromptCategory) {
        let deletedName = category.name

        performAction {
            let destinationName = try CategoryService.deleteCategory(
                category,
                categories: categories,
                prompts: prompts,
                in: modelContext
            )

            if case .category(let selectedName) = viewModel.selectedSection,
               selectedName.localizedCaseInsensitiveCompare(deletedName)
                == .orderedSame {
                viewModel.selectedSection = destinationName.map {
                    .category($0)
                } ?? .all
            }
        }
    }

    private func saveTag(_ tag: PromptTag?, draft: PromptTagDraft) {
        performAction {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            if let tag {
                tag.name = name
                tag.color = draft.color
            } else {
                modelContext.insert(PromptTag(name: name, color: draft.color))
            }
            try LibraryPersistence.save(modelContext)
        }
    }

    private func deleteTag(_ tag: PromptTag) {
        performAction {
            if case .tag(let id, _) = viewModel.selectedSection, id == tag.id {
                viewModel.selectedSection = .all
            }
            for collection in collections {
                collection.tagIDs.removeAll { $0 == tag.id }
            }
            modelContext.delete(tag)
            try LibraryPersistence.save(modelContext)
        }
    }

    private func saveCollection(_ collection: SmartCollection?, draft: SmartCollectionDraft) {
        performAction {
            let target = collection ?? SmartCollection(name: draft.name)
            if collection == nil { modelContext.insert(target) }
            target.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            target.query = draft.query
            target.category = draft.category
            target.tagIDs = Array(draft.tagIDs)
            target.favoriteOnly = draft.favoriteOnly
            target.updatedWithinDays = draft.updatedWithinDays
            target.matchAll = draft.matchAll
            try LibraryPersistence.save(modelContext)
            viewModel.selectedSection = .smartCollection(target.id, target.name)
        }
    }

    private func deleteCollection(_ collection: SmartCollection) {
        performAction {
            if case .smartCollection(let id, _) = viewModel.selectedSection, id == collection.id {
                viewModel.selectedSection = .all
            }
            modelContext.delete(collection)
            try LibraryPersistence.save(modelContext)
        }
    }

    private func bulkMove(_ category: String) {
        performAction { try Phase1Service.move(prompts: selectedPrompts, to: category, in: modelContext) }
    }

    private func bulkSetTag(_ tag: PromptTag, _ isIncluded: Bool) {
        performAction { try Phase1Service.setTag(tag, for: selectedPrompts, isIncluded: isIncluded, in: modelContext) }
    }

    private func bulkSetFavorite(_ value: Bool) {
        performAction { try Phase1Service.setFavorite(value, for: selectedPrompts, in: modelContext) }
    }

    private func bulkDelete() {
        performAction {
            let ids = Set(selectedPrompts.map(\.id))
            try Phase1Service.delete(prompts: selectedPrompts, tags: tags, in: modelContext)
            viewModel.selectedPromptIDs.subtract(ids)
            viewModel.selectedPromptID = viewModel.selectedPromptIDs.first
            isBulkDeletePresented = false
        }
    }

    private func draft(for prompt: Prompt) -> PromptDraft {
        PromptDraft(
            title: prompt.title,
            category: prompt.category,
            content: prompt.content,
            isFavorite: prompt.isFavorite,
            tagIDs: Set(tags.filter { $0.promptIDs.contains(prompt.id) }.map(\.id)),
            variableDefinitions: variableDefinitions.filter { $0.promptID == prompt.id }.map(TemplateVariableDraft.init)
        )
    }

    private func toggleFavorite(for prompt: Prompt) {
        performAction {
            try viewModel.toggleFavorite(
                for: prompt,
                in: modelContext
            )
        }
    }

    private func showImported(_ ids: Set<UUID>) {
        viewModel.searchText = ""
        viewModel.selectedSection = .all
        Task { @MainActor in
            await Task.yield()
            importedIDs = ids
            viewModel.updateSelection(ids, orderedBy: prompts.filter { ids.contains($0.id) }.map(\.id))
        }
    }

    private func addSamples() {
        performAction { showImported(try SampleLibrary.install(in: modelContext, defaults: .standard)) }
    }

    private func duplicate(_ prompt: Prompt) {
        performAction {
            let draft = PromptDraft(title: prompt.title, category: prompt.category, content: prompt.content,
                isFavorite: prompt.isFavorite, tagIDs: Set(tags.filter { $0.promptIDs.contains(prompt.id) }.map(\.id)),
                variableDefinitions: variableDefinitions.filter { $0.promptID == prompt.id }.map(TemplateVariableDraft.init))
            let created = try viewModel.createPrompt(from: draft, tags: tags, in: modelContext)
            importedIDs = nil
            viewModel.selectedSection = .all
            viewModel.updateSelection([created.id], orderedBy: [created.id])
        }
    }

    private func copy(_ prompt: Prompt) {
        let template = PromptTemplate(prompt.content)
        guard !template.hasVariables else {
            templateCopyRequest = PromptTemplateCopyRequest(
                prompt: prompt,
                definitions: variableDefinitions.filter { $0.promptID == prompt.id }
            )
            return
        }

        _ = copyToClipboard(prompt.content, promptID: prompt.id)
    }

    @discardableResult
    private func copyToClipboard(
        _ content: String,
        promptID: UUID
    ) -> Bool {
        guard clipboardService.copy(content) else {
            actionErrorMessage = "PromptDock could not write to the clipboard."
            return false
        }

        RecentUsage.record(promptID)
        recentUsageIDs = RecentUsage.ids()
        let feedbackToken = UUID()
        copyFeedbackToken = feedbackToken
        copiedPromptID = promptID

        if !hasLearnedCopyShortcut {
            presentCopyShortcutGuide()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard copyFeedbackToken == feedbackToken else { return }
            copiedPromptID = nil
            copyFeedbackToken = nil
        }

        return true
    }

    private func delete(_ prompt: Prompt) {
        performAction {
            try viewModel.deletePrompt(prompt, tags: tags, in: modelContext)
            promptPendingDeletionID = nil
        }
    }

    private func performAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            modelContext.rollback()
            actionErrorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var searchShortcutGuide: some View {
        let allLearned = hasLearnedNextSearchShortcut
            && hasLearnedPreviousSearchShortcut

        ShortcutGuidePopover(
            title: selectedLanguage.usesChinese
                ? "搜索结果快捷键"
                : "Search result shortcuts",
            message: allLearned
                ? (selectedLanguage.usesChinese
                    ? "做得好，两个快捷键都已掌握。"
                    : "Nice — you learned both shortcuts.")
                : (selectedLanguage.usesChinese
                    ? "使用快捷键切换，按对后会自动打勾。"
                    : "Use the shortcuts to move; correct keys check themselves off."),
            items: [
                ShortcutGuideItem(
                    shortcut: .nextSearchResult,
                    title: selectedLanguage.usesChinese
                        ? "下一条搜索结果"
                        : "Next search result",
                    keys: "⌘G",
                    isCompleted: hasLearnedNextSearchShortcut
                ),
                ShortcutGuideItem(
                    shortcut: .previousSearchResult,
                    title: selectedLanguage.usesChinese
                        ? "上一条搜索结果"
                        : "Previous search result",
                    keys: "⇧⌘G",
                    isCompleted: hasLearnedPreviousSearchShortcut
                )
            ]
        )
    }

    private func handleShortcut(_ shortcut: LearnableShortcut) {
        switch shortcut {
        case .copyPrompt:
            guard selectedPrompt != nil, !hasLearnedCopyShortcut else {
                return
            }
            hasLearnedCopyShortcut = true
            presentCopyShortcutGuide(
                autoDismissAfter: 2_200_000_000
            )
            showShortcutSuccess(
                selectedLanguage.usesChinese
                    ? "按对了！复制快捷键已掌握"
                    : "That’s it! Copy shortcut learned"
            )

        case .nextSearchResult:
            guard viewModel.hasSearchQuery,
                  !visiblePrompts.isEmpty,
                  !hasLearnedNextSearchShortcut
            else { return }
            hasLearnedNextSearchShortcut = true
            presentSearchShortcutGuide(
                autoDismissAfter: hasLearnedPreviousSearchShortcut
                    ? 2_200_000_000
                    : 6_000_000_000
            )
            showShortcutSuccess(
                selectedLanguage.usesChinese
                    ? "按对了！已切换到下一条结果"
                    : "Correct! Moved to the next result"
            )

        case .previousSearchResult:
            guard viewModel.hasSearchQuery,
                  !visiblePrompts.isEmpty,
                  !hasLearnedPreviousSearchShortcut
            else { return }
            hasLearnedPreviousSearchShortcut = true
            presentSearchShortcutGuide(
                autoDismissAfter: hasLearnedNextSearchShortcut
                    ? 2_200_000_000
                    : 6_000_000_000
            )
            showShortcutSuccess(
                selectedLanguage.usesChinese
                    ? "按对了！已切换到上一条结果"
                    : "Correct! Moved to the previous result"
            )
        }
    }

    private func showShortcutSuccess(_ message: String) {
        let token = UUID()
        shortcutSuccessToken = token
        shortcutSuccessMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard shortcutSuccessToken == token else { return }
            shortcutSuccessMessage = nil
            shortcutSuccessToken = nil
        }
    }

    private func presentCopyShortcutGuide(
        autoDismissAfter nanoseconds: UInt64 = 6_000_000_000
    ) {
        let token = UUID()
        copyShortcutGuideToken = token
        isCopyShortcutGuidePresented = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard copyShortcutGuideToken == token else { return }
            isCopyShortcutGuidePresented = false
            copyShortcutGuideToken = nil
        }
    }

    private func presentSearchShortcutGuide(
        autoDismissAfter nanoseconds: UInt64 = 6_000_000_000
    ) {
        let token = UUID()
        searchShortcutGuideToken = token
        isSearchShortcutGuidePresented = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard searchShortcutGuideToken == token else { return }
            isSearchShortcutGuidePresented = false
            searchShortcutGuideToken = nil
        }
    }
}

private struct PromptEditorRequest: Identifiable {
    let id = UUID()
    let promptID: UUID?
}

private struct WidgetSnapshotRevision: Hashable {
    let id: UUID
    let updatedDate: Date
    let isFavorite: Bool
}

private struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .modelContainer(for: Prompt.self, inMemory: true)
    }
}
