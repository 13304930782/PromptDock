import AppKit
import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openWindow) private var openWindow

    private let prompt: Prompt?
    private let categories: [PromptCategory]
    private let tags: [PromptTag]
    private let onSave: (PromptDraft) throws -> Void
    private let usesChinese: Bool

    @State private var title: String
    @State private var category: String
    @State private var content: String
    @State private var isFavorite: Bool
    @State private var selectedTagIDs: Set<UUID>
    @State private var variableDrafts: [TemplateVariableDraft]
    @State private var newTagName = ""
    @State private var newTagNames: [String] = []
    @State private var selectedVariableToken: String?
    @State private var errorMessage: String?
    @State private var isRewritePresented = false

    init(
        prompt: Prompt?,
        categories: [PromptCategory],
        tags: [PromptTag] = [],
        selectedTagIDs: Set<UUID> = [],
        variableDefinitions: [TemplateVariableDefinition] = [],
        initialCategory: String = "Teaching",
        usesChinese: Bool? = nil,
        onSave: @escaping (PromptDraft) throws -> Void
    ) {
        self.prompt = prompt
        self.categories = categories
        self.tags = tags
        self.usesChinese = usesChinese ?? false
        self.onSave = onSave
        let base = prompt.map(PromptDraft.init(prompt:)) ?? PromptDraft(category: initialCategory)
        _title = State(initialValue: base.title)
        _category = State(initialValue: base.category)
        _content = State(initialValue: base.content)
        _isFavorite = State(initialValue: base.isFavorite)
        _selectedTagIDs = State(initialValue: selectedTagIDs)
        _variableDrafts = State(initialValue: variableDefinitions.map(TemplateVariableDraft.init).sorted { $0.order < $1.order })
    }

    private var draft: PromptDraft {
        PromptDraft(title: title, category: category, content: content, isFavorite: isFavorite, tagIDs: selectedTagIDs, variableDefinitions: variableDrafts, newTagNames: newTagNames)
    }
    private var promptTemplate: PromptTemplate { PromptTemplate(content) }

    var body: some View {
        NavigationStack {
            Form {
                Section(usesChinese ? "提示词" : "Prompt") {
                    TextField(usesChinese ? "标题" : "Title", text: $title)
                    Picker(usesChinese ? "分类" : "Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { name in
                            Text(BuiltInCategoryPresentation.displayName(for: name, locale: locale)).tag(name)
                        }
                    }
                }

                Section(usesChinese ? "内容" : "Content") {
                    SelectablePromptTextEditor(text: $content, selectionToken: $selectedVariableToken)
                        .frame(minHeight: 220)
                        .accessibilityLabel(usesChinese ? "提示词内容" : "Prompt Content")
                    HStack {
                        Label(promptTemplate.hasVariables ? (usesChinese ? "已识别 \(promptTemplate.fields.count) 个变量" : "\(promptTemplate.fields.count) variables detected") : (usesChinese ? "使用 {{名称}} 或 {{名称[]}} 插入变量" : "Use {{name}} or {{name[]}} to insert variables"), systemImage: "curlybraces")
                        Spacer()
                        Button(usesChinese ? "操作手册" : "Guide") { openWindow(id: "template-guide") }.buttonStyle(.link)
                        Button(usesChinese ? "AI 改写" : "AI Rewrite") { isRewritePresented = true }.buttonStyle(.link).disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.font(.caption).foregroundStyle(.secondary)
                }

                Section(usesChinese ? "组织" : "Organization") {
                    if tags.isEmpty && newTagNames.isEmpty {
                        Text(usesChinese ? "暂无标签" : "No Tags").foregroundStyle(.secondary)
                    }
                    ForEach(tags) { tag in
                        Toggle(tag.name, isOn: Binding(get: { selectedTagIDs.contains(tag.id) }, set: { if $0 { selectedTagIDs.insert(tag.id) } else { selectedTagIDs.remove(tag.id) } }))
                    }
                    ForEach(newTagNames, id: \.self) { name in
                        HStack { Label(name, systemImage: "tag.fill"); Spacer(); Button(role: .destructive) { newTagNames.removeAll { $0 == name } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless) }
                    }
                    HStack {
                        TextField(usesChinese ? "新标签" : "New Tag", text: $newTagName)
                        Button(usesChinese ? "添加" : "Add") { addTagName() }.disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !variableDrafts.isEmpty {
                    Section(usesChinese ? "变量" : "Variables") {
                        ForEach($variableDrafts) { $variable in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button { selectedVariableToken = variable.isRepeatable ? "{{\(variable.name)[]}}" : "{{\(variable.name)}}" } label: { Label(variable.name, systemImage: "scope") }.buttonStyle(.plain)
                                    Spacer()
                                    Toggle(usesChinese ? "可重复" : "Repeatable", isOn: Binding(get: { variable.isRepeatable }, set: { setRepeatable($0, for: variable.name) }))
                                        .toggleStyle(.switch).controlSize(.small)
                                }
                                TextField(usesChinese ? "显示标签" : "Display Label", text: $variable.label)
                                TextField(usesChinese ? "默认值" : "Default Value", text: $variable.defaultValue)
                            }.padding(.vertical, 4)
                        }.onMove(perform: moveVariables)
                    }
                }

                Section(usesChinese ? "选项" : "Options") { Toggle(usesChinese ? "收藏" : "Favorite", isOn: $isFavorite) }
            }
            .formStyle(.grouped)
            .navigationTitle(prompt == nil ? (usesChinese ? "新建提示词" : "New Prompt") : (usesChinese ? "编辑提示词" : "Edit Prompt"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(usesChinese ? "取消" : "Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
                ToolbarItem(placement: .confirmationAction) { Button(usesChinese ? "保存" : "Save", action: save).keyboardShortcut(.defaultAction).disabled(!draft.isValid) }
            }
        }
        .frame(minWidth: 600, minHeight: 620)
        .onAppear(perform: synchronizeVariables)
        .onChange(of: content) { synchronizeVariables() }
        .sheet(isPresented: $isRewritePresented) {
            AIRewriteView(title: title, originalContent: content, usesChinese: usesChinese) { content = $0; isRewritePresented = false }
        }
        .alert(usesChinese ? "无法保存提示词" : "Unable to Save Prompt", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var categoryOptions: [String] {
        var names = categories.map(\.name)
        if !category.isEmpty && !names.contains(where: { CategoryNameIdentity.normalized($0) == CategoryNameIdentity.normalized(category) }) { names.append(category) }
        return names.isEmpty ? ["Teaching"] : names
    }
    private func addTagName() {
        let value = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if let existing = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }) { selectedTagIDs.insert(existing.id) }
        else if !newTagNames.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) { newTagNames.append(value) }
        newTagName = ""
    }
    private func synchronizeVariables() {
        let fields = promptTemplate.fields
        let old = Dictionary(uniqueKeysWithValues: variableDrafts.map { ($0.name, $0) })
        variableDrafts = fields.enumerated().map { index, field in
            var value = old[field.name] ?? TemplateVariableDraft(name: field.name, order: index, isRepeatable: field.isRepeatable)
            value.isRepeatable = field.isRepeatable
            if old[field.name] == nil { value.order = index }
            return value
        }.sorted { $0.order < $1.order }
        normalizeOrders()
    }
    private func moveVariables(from source: IndexSet, to destination: Int) { variableDrafts.move(fromOffsets: source, toOffset: destination); normalizeOrders() }
    private func normalizeOrders() { for index in variableDrafts.indices { variableDrafts[index].order = index } }
    private func setRepeatable(_ repeatable: Bool, for name: String) {
        let old = repeatable ? "{{\(name)}}" : "{{\(name)[]}}"
        let new = repeatable ? "{{\(name)[]}}" : "{{\(name)}}"
        content = content.replacingOccurrences(of: old, with: new)
    }
    private func save() { do { try onSave(draft); dismiss() } catch { errorMessage = error.localizedDescription } }
}

private struct SelectablePromptTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionToken: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = textView
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            let location = min(selection.location, length)
            textView.setSelectedRange(NSRange(
                location: location,
                length: min(selection.length, length - location)
            ))
        }
        if let token = selectionToken, let range = textView.string.range(of: token) {
            let nsRange = NSRange(range, in: textView.string)
            textView.setSelectedRange(nsRange); textView.scrollRangeToVisible(nsRange)
            DispatchQueue.main.async { selectionToken = nil; textView.window?.makeFirstResponder(textView) }
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectablePromptTextEditor
        init(_ parent: SelectablePromptTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) { if let view = notification.object as? NSTextView { parent.text = view.string } }
    }
}

private struct EditorView_Previews: PreviewProvider {
    static var previews: some View { EditorView(prompt: nil, categories: [PromptCategory(name: "Teaching", sortOrder: 0)], usesChinese: false) { _ in } }
}
