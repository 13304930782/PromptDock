import SwiftData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
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
                GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SearchHighlightedText(
                            text: prompt.title,
                            query: searchText
                        )
                            .font(.system(size: 24, weight: .semibold))
                            .textSelection(.enabled)

                        PromptMetadataLayout(spacing: 12) {
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

                        ViewThatFits(in: .horizontal) {
                            if geometry.size.width >= 460 {
                                actionPlate(for: prompt, template: template, expanded: true)
                            }
                            actionPlate(for: prompt, template: template, expanded: false)
                        }

                        Divider()

                        SearchHighlightedText(
                            text: prompt.content,
                            query: searchText
                        )
                            .font(.system(size: 15))
                            .lineSpacing(6)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func actionPlate(for prompt: Prompt, template: PromptTemplate, expanded: Bool) -> some View {
        HStack(spacing: 8) {
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
                    .frame(minWidth: template.hasVariables ? 96 : 52)
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
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .foregroundStyle(colorScheme == .dark ? Color(red: 0.098, green: 0.106, blue: 0.125) : .white)
            .background(colorScheme == .dark
                ? Color(red: 0.459, green: 0.667, blue: 1)
                : Color(red: 0.141, green: 0.388, blue: 0.831), in: Capsule())
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

            Button { onEdit(prompt) } label: {
                Label("Edit", systemImage: "pencil")
                    .padding(.horizontal, 8)
                    .frame(minHeight: 32)
            }
            .help("Edit Prompt (Command-E)")

            if expanded {
                favoriteButton(for: prompt).labelStyle(.iconOnly)
                historyButton(for: prompt).labelStyle(.iconOnly)
            }

            Menu {
                if !expanded {
                    favoriteButton(for: prompt)
                    historyButton(for: prompt)
                    Divider()
                }
                Button(role: .destructive) { onDelete(prompt) } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 32)
            }
            .menuIndicator(.hidden)
            .accessibilityLabel(usesChinese ? "更多提示词操作" : "More Prompt Actions")
        }
        .buttonStyle(.plain)
        .padding(6)
        .modifier(PromptActionSurface())
    }

    private func favoriteButton(for prompt: Prompt) -> some View {
        Button { onToggleFavorite(prompt) } label: {
            Label(prompt.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: prompt.isFavorite ? "star.fill" : "star")
                .frame(minWidth: 32, minHeight: 32)
        }
        .accessibilityValue(prompt.isFavorite ? Text("Favorite") : Text("Unfavorite"))
        .help("Add or Remove from Favorites (Shift-Command-F)")
    }

    private func historyButton(for prompt: Prompt) -> some View {
        Button { loadHistory(for: prompt) } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
                .frame(minWidth: 32, minHeight: 32)
        }
        .help("View Prompt History")
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
                List(versions, selection: Binding<UUID?>(
                    get: { selectedVersion?.id },
                    set: { id in selectedVersion = versions.first { $0.id == id } }
                )) { version in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(version.title).font(.headline)
                        Text(version.createdAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(version.content)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .tag(version.id)

                }
                .frame(minHeight: 260)

                if let selectedVersion {
                    GroupBox("Preview") {
                        ScrollView {
                            Text(selectedVersion.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(minHeight: 120)
                        .background(Color(nsColor: .textBackgroundColor))
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
        .padding(16)
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

// One operation surface only; content and inner controls never receive glass.
private struct PromptActionSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        surface(content)
            .overlay {
                if contrast == .increased || reduceTransparency {
                    Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private func surface(_ content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: Capsule())
            } else {
                content.background(.regularMaterial, in: Capsule())
            }
            #else
            content.background(.regularMaterial, in: Capsule())
            #endif
        }
    }
}

// Measures the actual detail column, allowing translated metadata to wrap.
private struct PromptMetadataLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 720).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews, width: bounds.width)
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + result.points[index].x,
                                   y: bounds.minY + result.points[index].y),
                       proposal: ProposedViewSize(width: min(view.sizeThatFits(.unspecified).width, bounds.width), height: nil))
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let naturalWidth = min(view.sizeThatFits(.unspecified).width, width)
            let size = view.sizeThatFits(ProposedViewSize(width: naturalWidth, height: nil))
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
