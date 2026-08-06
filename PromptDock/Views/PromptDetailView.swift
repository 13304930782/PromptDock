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
    let onRewrite: (Prompt) -> Void
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
                                onRewrite(prompt)
                            } label: {
                                Label(usesChinese ? "AI 改写" : "AI Rewrite", systemImage: "sparkles")
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
            var descriptor = FetchDescriptor<PromptVersion>(
                predicate: #Predicate { $0.promptID == promptID },
                sortBy: [SortDescriptor(\PromptVersion.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = Phase1Service.maximumPromptVersions
            history = try modelContext.fetch(descriptor)
            isHistoryPresented = true
        } catch {
            historyError = error.localizedDescription
        }
    }
}

struct BulkPromptActionsView: View {
    let prompts: [Prompt]
    let categories: [PromptCategory]
    let tags: [PromptTag]
    let usesChinese: Bool
    let onMove: (String) -> Void
    let onSetTag: (PromptTag, Bool) -> Void
    let onSetFavorite: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(
                usesChinese ? "已选择 \(prompts.count) 条提示词" : "\(prompts.count) Prompts Selected",
                systemImage: "checkmark.circle"
            ).font(.title2.bold())
            Text(usesChinese ? "批量整理会一次应用到所有选中项。" : "Changes apply to every selected prompt at once.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Menu {
                    ForEach(categories) { category in
                        Button(category.name) { onMove(category.name) }
                    }
                } label: { Label(usesChinese ? "移动到分类" : "Move to Category", systemImage: "folder") }

                Menu {
                    if tags.isEmpty { Text(usesChinese ? "暂无标签" : "No Tags") }
                    ForEach(tags) { tag in
                        Button(tag.name) { onSetTag(tag, true) }
                    }
                } label: { Label(usesChinese ? "添加标签" : "Add Tag", systemImage: "tag") }

                Menu {
                    if tags.isEmpty { Text(usesChinese ? "暂无标签" : "No Tags") }
                    ForEach(tags) { tag in
                        Button(tag.name) { onSetTag(tag, false) }
                    }
                } label: { Label(usesChinese ? "移除标签" : "Remove Tag", systemImage: "tag.slash") }
            }

            HStack(spacing: 12) {
                Button { onSetFavorite(true) } label: { Label(usesChinese ? "收藏" : "Favorite", systemImage: "star") }
                Button { onSetFavorite(false) } label: { Label(usesChinese ? "取消收藏" : "Unfavorite", systemImage: "star.slash") }
                Spacer()
                Button(role: .destructive, action: onDelete) { Label(usesChinese ? "删除" : "Delete", systemImage: "trash") }
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum AIRewriteGoal: String, CaseIterable, Identifiable {
    case concise, context, structure, tone
    var id: String { rawValue }
    func title(usesChinese: Bool) -> String {
        switch self {
        case .concise: usesChinese ? "精简表达" : "Make Concise"
        case .context: usesChinese ? "补全上下文" : "Add Context"
        case .structure: usesChinese ? "优化结构" : "Improve Structure"
        case .tone: usesChinese ? "调整语气" : "Adjust Tone"
        }
    }
}

struct AIRewriteView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let originalContent: String
    let usesChinese: Bool
    let onAccept: (String) -> Void
    @State private var goal: AIRewriteGoal = .concise
    @State private var additionalInstructions = ""
    @State private var candidate: String?
    @State private var errorMessage: String?
    @State private var task: Task<Void, Never>?
    @State private var isGenerating = false

    private var configuration: AIProviderConfiguration { AppPreferences.aiConfiguration }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(usesChinese ? "AI 改写" : "AI Rewrite").font(.title2.bold())
                    Text(title).foregroundStyle(.secondary)
                }
                Spacer()
                Button(usesChinese ? "完成" : "Done") { dismiss() }
            }

            Picker(usesChinese ? "改写目标" : "Rewrite Goal", selection: $goal) {
                ForEach(AIRewriteGoal.allCases) { Text($0.title(usesChinese: usesChinese)).tag($0) }
            }.pickerStyle(.segmented)

            TextField(usesChinese ? "补充要求（可选）" : "Additional Instructions (Optional)", text: $additionalInstructions, axis: .vertical)

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(configuration.provider.displayName(usesChinese: usesChinese)) · \(configuration.model)", systemImage: "network")
                    Text(usesChinese ? "点击生成后，只会发送下方当前提示词正文和改写要求。不会发送资料库、分类、标签或历史版本。" : "Generate sends only the current prompt below and your rewrite instructions. Your library, categories, tags, and history are not sent.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .top, spacing: 12) {
                rewriteColumn(usesChinese ? "原文" : "Original", text: originalContent, highlightsChanges: false)
                rewriteColumn(usesChinese ? "改写版" : "Rewrite", text: candidate ?? (usesChinese ? "生成后将在此显示结果。" : "The result will appear here."), highlightsChanges: candidate != nil)
            }.frame(maxHeight: .infinity)

            if let errorMessage { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption) }

            HStack {
                if isGenerating { ProgressView().controlSize(.small); Button(usesChinese ? "取消" : "Cancel") { task?.cancel() } }
                Spacer()
                if let candidate {
                    Button(usesChinese ? "复制改写版" : "Copy Rewrite") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(candidate, forType: .string) }
                    Button(usesChinese ? "接受改写" : "Accept Rewrite") { onAccept(candidate) }.buttonStyle(.borderedProminent)
                }
                Button(candidate == nil ? (usesChinese ? "生成改写" : "Generate Rewrite") : (usesChinese ? "重新生成" : "Regenerate"), action: generate)
                    .disabled(isGenerating)
            }
        }
        .padding(24)
        .frame(width: 820, height: 650)
        .onDisappear { task?.cancel() }
    }

    private func rewriteColumn(_ heading: String, text: String, highlightsChanges: Bool) -> some View {
        GroupBox(heading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(text.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                        let originalLines = originalContent.components(separatedBy: .newlines)
                        Text(line.isEmpty ? " " : line)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                            .background(highlightsChanges && (index >= originalLines.count || originalLines[index] != line) ? Color.accentColor.opacity(0.10) : Color.clear)
                    }
                }.textSelection(.enabled)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func generate() {
        task?.cancel(); candidate = nil; errorMessage = nil; isGenerating = true
        task = Task {
            do {
                let key = try AIKeychainStore.load(for: configuration.provider)
                let result = try await AITemplateService().rewritePrompt(content: originalContent, goal: goal, additionalInstructions: additionalInstructions, usesChinese: usesChinese, configuration: configuration, apiKey: key)
                guard !Task.isCancelled else { return }
                candidate = result
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
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
            onRewrite: { _ in },
            onToggleFavorite: { _ in },
            onDelete: { _ in }
        )
        .frame(width: 520, height: 500)
    }
}
