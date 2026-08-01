import SwiftUI

enum TemplateGuideContent {
    static func manual(usesChinese: Bool) -> String {
        if usesChinese {
            return """
            # PromptDock 模板语法手册

            PromptDock 使用双花括号标记需要在复制时填写的内容。

            1. 普通变量
            写法：{{名称}}
            用途：填写一个值。同名变量在提示词中出现多次时，只需填写一次，所有位置都会一起替换。
            示例：请为 {{主题}} 写一篇面向 {{读者}} 的文章。

            2. 可重复变量
            写法：{{名称[]}}
            用途：填写数量不固定的一组值。复制时可使用加号添加项目、使用减号删除项目。
            示例：请批改这些文件：{{文件名[]}}
            每个可重复变量最多可填写 100 项，中文界面使用“、”连接各项。

            3. 显示花括号原文
            如果内容中确实需要显示 {{文字}} 而不是把它作为变量，请在左花括号前添加反斜杠：
            \\{{文字}}

            4. 编写建议
            - 变量名称应简短、明确，例如 {{主题}}、{{语气}}、{{文件名[]}}。
            - 将固定要求直接写在提示词中，只把每次会变化的内容设为变量。
            - 需要多个同类项目时使用可重复变量，不要创建“文件1、文件2、文件3”。
            - 保存后点击复制，填写变量，并在实时预览确认最终内容。
            """
        }

        return """
        # PromptDock Template Syntax Guide

        PromptDock uses double braces to mark content that should be filled in when a prompt is copied.

        1. Single-value variables
        Syntax: {{name}}
        Use: Enter one value. If the same variable appears more than once, it is filled once and replaced everywhere.
        Example: Write an article about {{topic}} for {{audience}}.

        2. Repeatable variables
        Syntax: {{name[]}}
        Use: Enter a variable-length list. Use the Add button to append items and the Remove button to delete them.
        Example: Review these files: {{filename[]}}
        Each repeatable variable supports up to 100 items. The English interface joins items with “, ”.

        3. Showing braces literally
        If {{text}} must appear as ordinary text instead of a variable, add a backslash before the opening braces:
        \\{{text}}

        4. Writing recommendations
        - Keep variable names short and clear, such as {{topic}}, {{tone}}, or {{filename[]}}.
        - Keep fixed instructions in the prompt and make only changing content a variable.
        - Use a repeatable variable for multiple similar items instead of “file1, file2, file3”.
        - After saving, copy the prompt, fill its variables, and verify the live preview.
        """
    }

    static func requestForAI(
        requirement: String,
        usesChinese: Bool
    ) -> String {
        let trimmedRequirement = requirement.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if usesChinese {
            let suppliedRequirement = trimmedRequirement.isEmpty
                ? "（请在这里补充你的提示词需求）"
                : trimmedRequirement

            return """
            你是 PromptDock 模板编写助手。请严格按照下面的语法手册，把“用户需求”整理成一条可以直接保存到 PromptDock 的完整提示词。

            \(manual(usesChinese: true))

            # 输出要求
            - 只输出最终提示词，不要解释，不要使用 Markdown 代码块。
            - 保留用户的固定要求、格式和约束，不要擅自缩短。
            - 每次只填写一个值的内容使用 {{名称}}。
            - 数量可能变化、需要使用加号增加的同类项目使用 {{名称[]}}。
            - 不要虚构用户没有提出的变量或要求。

            # 用户需求
            \(suppliedRequirement)
            """
        }

        let suppliedRequirement = trimmedRequirement.isEmpty
            ? "(Add your prompt requirements here.)"
            : trimmedRequirement

        return """
        You are a PromptDock template-writing assistant. Follow the syntax guide below and turn the user requirement into one complete prompt that can be saved directly in PromptDock.

        \(manual(usesChinese: false))

        # Output rules
        - Return only the final prompt. Do not explain and do not use a Markdown code fence.
        - Preserve the user’s fixed instructions, formatting, and constraints.
        - Use {{name}} for a value entered once.
        - Use {{name[]}} for a variable-length set of similar items added with the Add button.
        - Do not invent variables or requirements the user did not request.

        # User requirement
        \(suppliedRequirement)
        """
    }
}

struct TemplateGuideView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openSettings) private var openSettings

    @AppStorage(AppPreferences.aiTemplateAssistantEnabled)
    private var isAIEnabled = false
    @AppStorage(AppPreferences.aiProvider)
    private var providerRawValue = AIProviderKind.deepSeek.rawValue

    @State private var requirement = ""
    @State private var copyFeedback: CopyFeedback?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var generatedTemplate = ""
    @State private var generationError: String?
    @State private var isGenerating = false
    @State private var isSendConfirmationPresented = false
    @State private var generationTask: Task<Void, Never>?

    private let clipboardService = ClipboardService()

    private var usesChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    private var selectedProvider: AIProviderKind {
        AIProviderKind(rawValue: providerRawValue) ?? .deepSeek
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                syntaxSection
                workflowSection
                aiSection
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(
            usesChinese ? "模板变量操作手册" : "Template Variables Guide"
        )
        .frame(minWidth: 620, minHeight: 640)
        .onDisappear {
            feedbackTask?.cancel()
            generationTask?.cancel()
        }
        .confirmationDialog(
            usesChinese ? "发送给 AI？" : "Send to AI?",
            isPresented: $isSendConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(
                usesChinese
                    ? "发送并生成模板"
                    : "Send and Generate Template"
            ) {
                generateOnline()
            }
            Button(
                usesChinese ? "取消" : "Cancel",
                role: .cancel
            ) {}
        } message: {
            Text(
                usesChinese
                    ? "PromptDock 会把当前需求和模板语法手册发送给 \(selectedProvider.displayName(usesChinese: true))。不会发送已保存的提示词资料库。"
                    : "PromptDock will send this requirement and the template syntax guide to \(selectedProvider.displayName(usesChinese: false)). Your saved prompt library will not be sent."
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "curlybraces.square")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(
                    usesChinese
                        ? "用变量复用一条提示词"
                        : "Reuse one prompt with variables"
                )
                .font(.title2.weight(.semibold))

                Text(
                    usesChinese
                        ? "固定内容只写一次，复制时再填写会变化的部分。填写与复制在此 Mac 上完成；仅当你确认使用在线 AI 时才会发送当前需求。"
                        : "Write fixed content once, then fill changing parts when you copy. Filling and copying stay on this Mac; only confirmed online AI requests send the current requirement."
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private var syntaxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                usesChinese ? "两种变量" : "Two variable types"
            )

            HStack(alignment: .top, spacing: 12) {
                syntaxCard(
                    syntax: "{{名称}}",
                    title: usesChinese ? "普通变量" : "Single value",
                    description: usesChinese
                        ? "填写一个值；同名变量只需填写一次。"
                        : "Enter one value; repeated names are filled once."
                )

                syntaxCard(
                    syntax: "{{文件名[]}}",
                    title: usesChinese ? "可重复变量" : "Repeatable list",
                    description: usesChinese
                        ? "用加号添加，单个变量最多 100 项。"
                        : "Add rows with Plus, up to 100 items per variable."
                )
            }

            Text(
                usesChinese
                    ? "示例：请批改这些文件：{{文件名[]}}"
                    : "Example: Review these files: {{filename[]}}"
            )
            .font(.callout.monospaced())
            .textSelection(.enabled)
        }
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                usesChinese ? "使用步骤" : "How to use templates"
            )

            guideRow(
                number: 1,
                text: usesChinese
                    ? "新建或编辑提示词，在正文中输入变量。"
                    : "Create or edit a prompt and add variables to its content."
            )
            guideRow(
                number: 2,
                text: usesChinese
                    ? "保存提示词，然后像平常一样点击复制。"
                    : "Save it, then use Copy as usual."
            )
            guideRow(
                number: 3,
                text: usesChinese
                    ? "填写变量；可重复变量使用加号添加项目。"
                    : "Fill the fields; add repeatable items with Plus."
            )
            guideRow(
                number: 4,
                text: usesChinese
                    ? "检查实时预览，按 Return 或点击复制。"
                    : "Check the live preview, then press Return or Copy."
            )
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                usesChinese
                    ? "让 AI 帮你编写模板"
                    : "Ask an AI to write the template"
            )

            Text(
                usesChinese
                    ? "输入需求后，可以直接调用已配置的 AI 生成模板，也可以只复制手册，粘贴到其他 AI。"
                    : "Enter a requirement to generate a template with the configured AI, or copy the guide for use in another AI."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Label(
                    isAIEnabled
                        ? (usesChinese
                            ? "在线生成：\(selectedProvider.displayName(usesChinese: true))"
                            : "Online generation: \(selectedProvider.displayName(usesChinese: false))")
                        : (usesChinese
                            ? "在线生成尚未启用"
                            : "Online generation is disabled"),
                    systemImage: isAIEnabled
                        ? "checkmark.circle"
                        : "pause.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(usesChinese ? "AI 设置…" : "AI Settings…") {
                    openSettings()
                }
                .buttonStyle(.link)
            }

            TextField(
                "",
                text: $requirement,
                prompt: Text(
                    usesChinese
                        ? "例如：根据多个学生作文文件生成逐份批改意见……"
                        : "For example: Review a variable number of student essay files…"
                ),
                axis: .vertical
            )
            .font(.body)
            .textFieldStyle(.plain)
            .lineLimit(5...12)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 110, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
            .accessibilityLabel(
                usesChinese ? "提示词需求" : "Prompt requirement"
            )

            if isGenerating {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(
                        usesChinese
                            ? "正在生成模板…"
                            : "Generating template…"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let generationError {
                Label(
                    generationError,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .textSelection(.enabled)
            }

            if !generatedTemplate.isEmpty {
                generatedTemplateEditor
            }

            HStack {
                if let copyFeedback {
                    Label(
                        copyFeedback.message(usesChinese: usesChinese),
                        systemImage: copyFeedback.systemImage
                    )
                    .font(.callout)
                    .foregroundStyle(copyFeedback.color)
                    .transition(.opacity)
                }

                Spacer()

                Button {
                    copyForAI()
                } label: {
                    Label(
                        usesChinese ? "复制给 AI" : "Copy for AI",
                        systemImage: "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(
                    usesChinese
                        ? "复制手册和需求，然后粘贴到 ChatGPT、DeepSeek 或其他 AI"
                        : "Copy the guide and requirement for ChatGPT, DeepSeek, or another AI"
                )

                Button {
                    requestOnlineGeneration()
                } label: {
                    Label(
                        usesChinese ? "使用 AI 生成" : "Generate with AI",
                        systemImage: "sparkles"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isGenerating)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var generatedTemplateEditor: some View {
        let template = PromptTemplate(generatedTemplate)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    usesChinese
                        ? "生成结果"
                        : "Generated Template"
                )
                .font(.subheadline.weight(.semibold))

                if template.hasVariables {
                    Text(
                        usesChinese
                            ? "\(template.fields.count) 个变量"
                            : "\(template.fields.count) variables"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    copyGeneratedTemplate()
                } label: {
                    Label(
                        usesChinese ? "复制结果" : "Copy Result",
                        systemImage: "doc.on.doc"
                    )
                }
            }

            TextEditor(text: $generatedTemplate)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }
                .accessibilityLabel(
                    usesChinese ? "AI 生成的模板" : "AI-generated template"
                )

            Text(
                usesChinese
                    ? "结果不会自动保存。请先检查变量和固定要求，再复制到新提示词中。"
                    : "The result is not saved automatically. Review its variables and fixed instructions before copying it into a new prompt."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func syntaxCard(
        syntax: String,
        title: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(syntax)
                .font(.body.monospaced().weight(.semibold))
                .foregroundStyle(.tint)
                .textSelection(.enabled)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func guideRow(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
        }
        .accessibilityElement(children: .combine)
    }

    private func copyForAI() {
        let content = TemplateGuideContent.requestForAI(
            requirement: requirement,
            usesChinese: usesChinese
        )
        let didCopy = clipboardService.copy(content)
        showCopyFeedback(didCopy)
    }

    private func copyGeneratedTemplate() {
        let didCopy = clipboardService.copy(generatedTemplate)
        showCopyFeedback(didCopy)
    }

    private func requestOnlineGeneration() {
        generationError = nil
        guard !requirement.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            generationError = usesChinese
                ? "请先填写提示词需求。"
                : "Enter a prompt requirement first."
            return
        }
        guard isAIEnabled else {
            generationError = usesChinese
                ? "请先在 AI 设置中启用并配置在线生成。"
                : "Enable and configure online generation in AI Settings first."
            return
        }
        isSendConfirmationPresented = true
    }

    private func generateOnline() {
        generationTask?.cancel()
        generationError = nil
        isGenerating = true

        let request = TemplateGuideContent.requestForAI(
            requirement: requirement,
            usesChinese: usesChinese
        )
        let configuration = AppPreferences.aiConfiguration

        generationTask = Task { @MainActor in
            defer { isGenerating = false }
            do {
                let key = try AIKeychainStore.load(
                    for: configuration.provider
                )
                let generated = try await AITemplateService()
                    .generateTemplate(
                        request: request,
                        configuration: configuration,
                        apiKey: key
                    )
                guard !Task.isCancelled else { return }
                generatedTemplate = generated
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                generationError = error.localizedDescription
            }
        }
    }

    private func showCopyFeedback(_ didCopy: Bool) {
        feedbackTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            copyFeedback = didCopy ? .success : .failure
        }

        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                copyFeedback = nil
            }
        }
    }
}

private enum CopyFeedback {
    case success
    case failure

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failure: .red
        }
    }

    func message(usesChinese: Bool) -> String {
        switch self {
        case .success:
            usesChinese ? "已复制，可以粘贴给 AI" : "Copied — ready to paste into an AI"
        case .failure:
            usesChinese ? "复制失败，请重试" : "Could not copy. Try again."
        }
    }
}
