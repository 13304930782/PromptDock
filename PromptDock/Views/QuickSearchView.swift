import SwiftData
import SwiftUI

struct QuickSearchView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \Prompt.updatedDate, order: .reverse)
    private var prompts: [Prompt]

    let onClose: () -> Void
    let onPreferredHeightChange: (CGFloat) -> Void

    @State private var query = ""
    @State private var selectedPromptID: UUID?
    @State private var copiedPromptID: UUID?
    @State private var errorMessage: String?
    @State private var results: [Prompt] = []
    @State private var templateCopyRequest: PromptTemplateCopyRequest?
    @FocusState private var isSearchFocused: Bool

    private let clipboardService = ClipboardService()

    init(
        onClose: @escaping () -> Void,
        onPreferredHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.onClose = onClose
        self.onPreferredHeightChange = onPreferredHeightChange
    }

    private var promptRevision: [PromptSearchRevision] {
        prompts.map {
            PromptSearchRevision(
                id: $0.id,
                updatedDate: $0.updatedDate,
                category: $0.category
            )
        }
    }

    private var preferredHeight: CGFloat {
        if templateCopyRequest != nil {
            return 480
        }

        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedQuery.isEmpty else { return 88 }
        guard !results.isEmpty else { return 221 }

        let resultAreaHeight = min(
            CGFloat(300),
            CGFloat(12 + results.count * 70)
        )
        return 51 + resultAreaHeight
    }

    var body: some View {
        Group {
            if let request = templateCopyRequest {
                PromptTemplateFillView(
                    request: request,
                    presentation: .compact,
                    usesChinese: usesChinese,
                    onCancel: cancelTemplateCopy,
                    onCopy: { renderedPrompt in
                        finishCopy(
                            renderedPrompt,
                            promptID: request.promptID
                        )
                    }
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search Prompts", text: $query)
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)
                            .accessibilityLabel("Search Prompts")

                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Clear Search")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        Text("Type to search · ↑↓ to move · Return to copy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if results.isEmpty {
                        Divider()
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("Try a title, category, or phrase from the prompt.")
                        )
                        .frame(height: 170)
                    } else {
                        Divider()
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(results) { prompt in
                                    Button {
                                        beginCopy(prompt)
                                    } label: {
                                        quickSearchRow(prompt)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(6)
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
        }
        .frame(width: 410)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.7), lineWidth: 0.5)
        }
        .onAppear {
            query = ""
            results = []
            selectedPromptID = nil
            templateCopyRequest = nil
            onPreferredHeightChange(preferredHeight)
            Task { @MainActor in
                await Task.yield()
                isSearchFocused = true
            }
        }
        .onChange(of: query) {
            refreshResults()
        }
        .onChange(of: promptRevision) {
            refreshResults()
        }
        .onChange(of: locale.identifier) {
            refreshResults()
        }
        .onChange(of: preferredHeight) { _, height in
            onPreferredHeightChange(height)
        }
        .onKeyPress(.downArrow) {
            guard templateCopyRequest == nil else { return .ignored }
            moveSelection(offset: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard templateCopyRequest == nil else { return .ignored }
            moveSelection(offset: -1)
            return .handled
        }
        .onKeyPress(.return) {
            guard templateCopyRequest == nil else { return .ignored }
            guard let selectedPrompt else { return .ignored }
            beginCopy(selectedPrompt)
            return .handled
        }
        .onExitCommand {
            if templateCopyRequest != nil {
                cancelTemplateCopy()
            } else {
                onClose()
            }
        }
        .alert("Unable to Copy", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var selectedPrompt: Prompt? {
        guard let selectedPromptID else { return results.first }
        return results.first { $0.id == selectedPromptID }
    }

    private var usesChinese: Bool {
        locale.identifier.lowercased().hasPrefix("zh")
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func quickSearchRow(_ prompt: Prompt) -> some View {
        HStack(spacing: 10) {
            Image(systemName: copiedPromptID == prompt.id
                ? "checkmark.circle.fill"
                : (prompt.isFavorite ? "star.fill" : "text.bubble"))
                .foregroundStyle(
                    copiedPromptID == prompt.id ? Color.green : Color.accentColor
                )
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(
                    BuiltInCategoryPresentation.displayName(
                        for: prompt.category,
                        locale: locale
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(
                    prompt.content.replacingOccurrences(
                        of: "\n",
                        with: " "
                    )
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            let templateVariableCount = PromptTemplate(
                prompt.content
            ).variables.count
            if templateVariableCount > 0 {
                Label(
                    "\(templateVariableCount)",
                    systemImage: "curlybraces"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    usesChinese
                        ? "\(templateVariableCount) 个变量"
                        : "\(templateVariableCount) variables"
                )
            }

            if selectedPromptID == prompt.id {
                Text("↩")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            selectedPromptID == prompt.id
                ? Color.accentColor.opacity(0.14)
                : Color.clear,
            in: .rect(cornerRadius: 7)
        )
    }

    private func moveSelection(offset: Int) {
        guard !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selectedPromptID }
            ?? (offset > 0 ? -1 : 0)
        let nextIndex = (index + offset + results.count) % results.count
        selectedPromptID = results[nextIndex].id
    }

    private func refreshResults() {
        results = PromptSearchService.results(
            in: prompts,
            query: query,
            locale: locale,
            limit: 12
        )
        if let selectedPromptID,
           results.contains(where: { $0.id == selectedPromptID }) {
            return
        }
        selectedPromptID = results.first?.id
    }

    private func beginCopy(_ prompt: Prompt) {
        let request = PromptTemplateCopyRequest(prompt: prompt)
        guard request.template.hasVariables else {
            _ = finishCopy(prompt.content, promptID: prompt.id)
            return
        }

        selectedPromptID = prompt.id
        isSearchFocused = false
        templateCopyRequest = request
    }

    private func cancelTemplateCopy() {
        templateCopyRequest = nil
        Task { @MainActor in
            await Task.yield()
            isSearchFocused = true
        }
    }

    @discardableResult
    private func finishCopy(
        _ content: String,
        promptID: UUID
    ) -> Bool {
        guard clipboardService.copy(content) else {
            errorMessage = "PromptDock could not write to the clipboard."
            return false
        }

        templateCopyRequest = nil
        copiedPromptID = promptID
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            onClose()
        }
        return true
    }
}

private struct PromptSearchRevision: Equatable {
    let id: UUID
    let updatedDate: Date
    let category: String
}
