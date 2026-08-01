import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Prompt.updatedDate, order: .reverse)
    private var prompts: [Prompt]

    @Query(sort: [
        SortDescriptor(\PromptCategory.sortOrder),
        SortDescriptor(\PromptCategory.createdDate)
    ])
    private var categories: [PromptCategory]

    @AppStorage(AppLanguage.storageKey)
    private var languageRawValue = AppLanguage.system.rawValue

    @StateObject private var viewModel = PromptViewModel()
    @State private var isEditorPresented = false
    @State private var editorPromptID: UUID?
    @State private var promptPendingDeletionID: UUID?
    @State private var actionErrorMessage: String?
    @State private var copiedPromptID: UUID?
    @State private var copyFeedbackToken: UUID?
    @State private var templateCopyRequest: PromptTemplateCopyRequest?
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

    private var visiblePrompts: [Prompt] {
        viewModel.filteredPrompts(
            from: prompts,
            locale: selectedLanguage.locale
        )
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

    private var editorPrompt: Prompt? {
        guard let editorPromptID else { return nil }
        return prompts.first { $0.id == editorPromptID }
    }

    private var promptPendingDeletion: Prompt? {
        guard let promptPendingDeletionID else { return nil }
        return prompts.first { $0.id == promptPendingDeletionID }
    }

    private var selectedPrompt: Prompt? {
        viewModel.selectedPrompt(in: prompts)
    }

    private var commandActions: PromptCommandActions {
        PromptCommandActions(
            selectedPromptTitle: selectedPrompt?.title,
            isSelectedPromptFavorite: selectedPrompt?.isFavorite ?? false,
            createPrompt: { presentEditor(for: nil) },
            copySelectedPrompt: {
                guard let selectedPrompt else { return }
                copy(selectedPrompt)
            },
            editSelectedPrompt: {
                guard let selectedPrompt else { return }
                presentEditor(for: selectedPrompt)
            },
            toggleSelectedPromptFavorite: {
                guard let selectedPrompt else { return }
                toggleFavorite(for: selectedPrompt)
            },
            deleteSelectedPrompt: {
                guard let selectedPrompt else { return }
                requestDeletion(of: selectedPrompt)
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

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $viewModel.selectedSection,
                categories: categories,
                onCreateCategory: createCategory,
                onMoveCategories: moveCategories,
                onRenameCategory: renameCategory,
                onDeleteCategory: deleteCategory
            )
                .navigationSplitViewColumnWidth(
                    min: 180,
                    ideal: 220,
                    max: 280
                )
        } content: {
            PromptListView(
                section: viewModel.selectedSection,
                prompts: visiblePrompts,
                selection: $viewModel.selectedPromptID,
                searchText: $viewModel.searchText,
                onCreate: { presentEditor(for: nil) },
                onCopy: copy,
                onEdit: { presentEditor(for: $0) },
                onToggleFavorite: { toggleFavorite(for: $0) },
                onDelete: { requestDeletion(of: $0) }
            )
            .navigationSplitViewColumnWidth(
                min: 260,
                ideal: 320,
                max: 440
            )
        } detail: {
            PromptDetailView(
                prompt: selectedPrompt,
                searchText: viewModel.searchText,
                isCopied: copiedPromptID == viewModel.selectedPromptID,
                isCopyShortcutGuidePresented: $isCopyShortcutGuidePresented,
                hasLearnedCopyShortcut: hasLearnedCopyShortcut,
                usesChinese: selectedLanguage.usesChinese,
                onCopy: copy,
                onEdit: { presentEditor(for: $0) },
                onToggleFavorite: { toggleFavorite(for: $0) },
                onDelete: { requestDeletion(of: $0) }
            )
        }
        .toolbar {
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
        .sheet(isPresented: $isEditorPresented) {
            EditorView(
                prompt: editorPrompt,
                categories: categories,
                initialCategory: viewModel.preferredNewPromptCategory(
                    from: categories
                )
            ) { draft in
                if let editorPrompt {
                    try viewModel.updatePrompt(
                        editorPrompt,
                        from: draft,
                        in: modelContext
                    )
                } else {
                    let createdPrompt = try viewModel.createPrompt(
                        from: draft,
                        in: modelContext
                    )
                    viewModel.selectedSection = .all
                    viewModel.selectedPromptID = createdPrompt.id
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
                "This will permanently delete “\(prompt.title)”. This action cannot be undone."
            )
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
            ensureCategories()
            viewModel.reconcileSelection(
                in: prompts,
                locale: selectedLanguage.locale
            )
            WidgetSnapshotService.refresh(from: prompts)
        }
        .onChange(of: viewModel.selectedSection) {
            viewModel.reconcileSelection(
                in: prompts,
                locale: selectedLanguage.locale
            )
        }
        .onChange(of: visiblePromptIDs) {
            viewModel.reconcileSelection(
                in: prompts,
                locale: selectedLanguage.locale
            )
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
        editorPromptID = prompt?.id
        isEditorPresented = true
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

    private func toggleFavorite(for prompt: Prompt) {
        performAction {
            try viewModel.toggleFavorite(
                for: prompt,
                in: modelContext
            )
        }
    }

    private func copy(_ prompt: Prompt) {
        let template = PromptTemplate(prompt.content)
        guard !template.hasVariables else {
            templateCopyRequest = PromptTemplateCopyRequest(prompt: prompt)
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
            try viewModel.deletePrompt(prompt, in: modelContext)
            promptPendingDeletionID = nil
        }
    }

    private func performAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
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
