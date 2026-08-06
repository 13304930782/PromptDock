import XCTest
import SwiftData
import AppKit
import Carbon
@testable import PromptDock

final class PromptDockTests: XCTestCase {
    func testPromptInitializesRequiredFieldsAndDefaults() {
        let prompt = Prompt(
            title: "Explain SwiftData",
            category: "Coding",
            content: "Explain SwiftData with a practical example."
        )

        XCTAssertEqual(prompt.title, "Explain SwiftData")
        XCTAssertEqual(prompt.category, "Coding")
        XCTAssertEqual(
            prompt.content,
            "Explain SwiftData with a practical example."
        )
        XCTAssertEqual(prompt.createdDate, prompt.updatedDate)
        XCTAssertFalse(prompt.isFavorite)
    }

    func testPromptCanBeSavedAndFetched() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let writeContext = ModelContext(container)
        let prompt = Prompt(
            title: "Lesson Plan",
            category: "Teaching",
            content: "Create a 45-minute lesson plan."
        )

        writeContext.insert(prompt)
        try writeContext.save()

        let readContext = ModelContext(container)
        let savedPrompts = try readContext.fetch(FetchDescriptor<Prompt>())

        XCTAssertEqual(savedPrompts.count, 1)
        XCTAssertEqual(savedPrompts.first?.id, prompt.id)
        XCTAssertEqual(savedPrompts.first?.title, "Lesson Plan")
    }

    @MainActor
    func testViewModelFiltersCategoriesAndFavorites() {
        let codingPrompt = Prompt(
            title: "Swift Review",
            category: "coding",
            content: "Review this Swift code."
        )
        let favoritePrompt = Prompt(
            title: "Essay Outline",
            category: "Writing",
            content: "Create an essay outline.",
            isFavorite: true
        )
        let viewModel = PromptViewModel()

        viewModel.selectedSection = .category("Coding")
        XCTAssertEqual(
            viewModel.filteredPrompts(
                from: [codingPrompt, favoritePrompt]
            ).map(\.id),
            [codingPrompt.id]
        )

        viewModel.selectedSection = .favorites
        XCTAssertEqual(
            viewModel.filteredPrompts(
                from: [codingPrompt, favoritePrompt]
            ).map(\.id),
            [favoritePrompt.id]
        )
    }

    @MainActor
    func testNewPromptCategoryFollowsSelectedCategory() {
        let viewModel = PromptViewModel()
        let categories = [
            PromptCategory(name: "Teaching", sortOrder: 0),
            PromptCategory(name: "Coding", sortOrder: 1)
        ]

        viewModel.selectedSection = .category("Coding")
        XCTAssertEqual(
            viewModel.preferredNewPromptCategory(from: categories),
            "Coding"
        )

        viewModel.selectedSection = .favorites
        XCTAssertEqual(
            viewModel.preferredNewPromptCategory(from: categories),
            "Teaching"
        )
    }

    @MainActor
    func testViewModelReconcilesSelectionWithVisiblePrompts() {
        let teachingPrompt = Prompt(
            title: "Lesson Plan",
            category: "Teaching",
            content: "Create a lesson plan."
        )
        let codingPrompt = Prompt(
            title: "Code Review",
            category: "Coding",
            content: "Review this code."
        )
        let viewModel = PromptViewModel()

        viewModel.selectedPromptID = codingPrompt.id
        viewModel.selectedSection = .category("Teaching")
        viewModel.reconcileSelection(
            in: [teachingPrompt, codingPrompt]
        )

        XCTAssertEqual(viewModel.selectedPromptID, teachingPrompt.id)
    }

    @MainActor
    func testViewModelPerformsCRUDAndFavoriteOperations() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        let viewModel = PromptViewModel()
        let createdPrompt = try viewModel.createPrompt(
            from: PromptDraft(
                title: "  Initial Title  ",
                category: "Coding",
                content: "  Initial content.  "
            ),
            in: context
        )

        var savedPrompts = try context.fetch(FetchDescriptor<Prompt>())
        XCTAssertEqual(savedPrompts.count, 1)
        XCTAssertEqual(createdPrompt.title, "Initial Title")
        XCTAssertEqual(createdPrompt.content, "Initial content.")

        createdPrompt.updatedDate = .distantPast
        try context.save()
        try viewModel.updatePrompt(
            createdPrompt,
            from: PromptDraft(
                title: "Updated Title",
                category: "AI",
                content: "Updated content."
            ),
            in: context
        )

        XCTAssertEqual(createdPrompt.title, "Updated Title")
        XCTAssertEqual(createdPrompt.category, "AI")
        XCTAssertGreaterThan(createdPrompt.updatedDate, .distantPast)

        try viewModel.toggleFavorite(
            for: createdPrompt,
            in: context
        )
        XCTAssertTrue(createdPrompt.isFavorite)

        try viewModel.deletePrompt(createdPrompt, in: context)
        savedPrompts = try context.fetch(FetchDescriptor<Prompt>())
        XCTAssertTrue(savedPrompts.isEmpty)
    }

    @MainActor
    func testViewModelSearchesTitleContentAndCategory() {
        let titleMatch = Prompt(
            title: "React Architecture",
            category: "Coding",
            content: "Design a frontend application."
        )
        let contentMatch = Prompt(
            title: "Code Review",
            category: "Coding",
            content: "Review this React component."
        )
        let categoryMatch = Prompt(
            title: "Lesson Plan",
            category: "React Teaching",
            content: "Create a class activity."
        )
        let noMatch = Prompt(
            title: "Essay Outline",
            category: "Writing",
            content: "Draft a history essay."
        )
        let viewModel = PromptViewModel()

        viewModel.searchText = "react"
        let results = viewModel.filteredPrompts(
            from: [titleMatch, contentMatch, categoryMatch, noMatch]
        )

        XCTAssertEqual(Set(results.map(\.id)), Set([
            titleMatch.id,
            contentMatch.id,
            categoryMatch.id
        ]))
    }

    @MainActor
    func testSearchCombinesWithSelectedSidebarSection() {
        let codingPrompt = Prompt(
            title: "Swift Concurrency",
            category: "Coding",
            content: "Explain actors."
        )
        let teachingPrompt = Prompt(
            title: "Swift Lesson",
            category: "Teaching",
            content: "Teach basic syntax."
        )
        let viewModel = PromptViewModel()

        viewModel.selectedSection = .category("Coding")
        viewModel.searchText = "swift"

        XCTAssertEqual(
            viewModel.filteredPrompts(
                from: [codingPrompt, teachingPrompt]
            ).map(\.id),
            [codingPrompt.id]
        )
    }

    func testSearchHighlighterCountsCaseAndDiacriticInsensitiveMatches() {
        XCTAssertEqual(
            SearchHighlighter.matchCount(
                in: "React, react, and Réact",
                query: "react"
            ),
            3
        )
        XCTAssertEqual(
            SearchHighlighter.matchCount(
                in: "No query should match here.",
                query: "   "
            ),
            0
        )
    }

    func testPromptSearchUsesDeterministicAccuracyRanking() {
        let now = Date.now
        let exact = Prompt(
            title: "Swift",
            category: "Coding",
            content: "Exact title",
            updatedDate: now.addingTimeInterval(-100)
        )
        let prefix = Prompt(
            title: "Swift Concurrency",
            category: "Coding",
            content: "Prefix title",
            updatedDate: now
        )
        let titleContains = Prompt(
            title: "Modern Swift Patterns",
            category: "Coding",
            content: "Title contains",
            updatedDate: now
        )
        let category = Prompt(
            title: "Language Notes",
            category: "Swift",
            content: "Category match",
            updatedDate: now
        )
        let content = Prompt(
            title: "Code Review",
            category: "Coding",
            content: "Review this Swift implementation.",
            updatedDate: now
        )

        XCTAssertEqual(
            PromptSearchService.results(
                in: [content, category, titleContains, prefix, exact],
                query: "swift"
            ).map(\.id),
            [exact.id, prefix.id, titleContains.id, category.id, content.id]
        )
        XCTAssertTrue(
            PromptSearchService.results(in: [exact], query: "   ").isEmpty
        )
    }

    func testPromptSearchPrefersFavoritesWithinTheSameRank() {
        let regular = Prompt(
            title: "Swift First",
            category: "Coding",
            content: "Regular",
            updatedDate: .now
        )
        let favorite = Prompt(
            title: "Swift Second",
            category: "Coding",
            content: "Favorite",
            updatedDate: .distantPast,
            isFavorite: true
        )

        XCTAssertEqual(
            PromptSearchService.results(
                in: [regular, favorite],
                query: "swift"
            ).map(\.id),
            [favorite.id, regular.id]
        )
    }

    func testHotKeyCombinationValidationAndSerialization() throws {
        let combination = HotKeyCombination.defaultQuickSearch
        XCTAssertTrue(combination.isValid)
        XCTAssertEqual(combination.displayText, "⇧⌘P")

        let encoded = try JSONEncoder().encode(combination)
        XCTAssertEqual(
            try JSONDecoder().decode(
                HotKeyCombination.self,
                from: encoded
            ),
            combination
        )
        XCTAssertFalse(
            HotKeyCombination(keyCode: combination.keyCode, modifiers: 0)
                .isValid
        )
    }

    @MainActor
    func testSearchNavigationMovesAndWrapsBetweenPrompts() {
        let firstPrompt = Prompt(
            title: "First",
            category: "Coding",
            content: "First result"
        )
        let secondPrompt = Prompt(
            title: "Second",
            category: "Coding",
            content: "Second result"
        )
        let viewModel = PromptViewModel()
        let results = [firstPrompt, secondPrompt]

        viewModel.selectedPromptID = firstPrompt.id
        XCTAssertEqual(
            viewModel.searchResultPosition(in: results),
            "1 of 2"
        )

        viewModel.selectNextSearchResult(in: results)
        XCTAssertEqual(viewModel.selectedPromptID, secondPrompt.id)

        viewModel.selectNextSearchResult(in: results)
        XCTAssertEqual(viewModel.selectedPromptID, firstPrompt.id)

        viewModel.selectPreviousSearchResult(in: results)
        XCTAssertEqual(viewModel.selectedPromptID, secondPrompt.id)
    }

    func testClipboardServiceCopiesPromptContent() {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name(
                "PromptDockTests.\(UUID().uuidString)"
            )
        )
        let service = ClipboardService(pasteboard: pasteboard)

        XCTAssertTrue(service.copy("Reusable prompt content"))
        XCTAssertEqual(
            pasteboard.string(forType: .string),
            "Reusable prompt content"
        )
    }

    func testPromptTemplateFindsVariablesInFirstAppearanceOrder() {
        let template = PromptTemplate(
            "Write about {{ topic }} for {{audience}}. Reuse {{topic}}."
        )

        XCTAssertEqual(template.variables, ["topic", "audience"])
        XCTAssertTrue(template.hasVariables)
    }

    func testPromptTemplateRendersRepeatedVariables() {
        let template = PromptTemplate(
            "{{greeting}}, {{name}}! {{greeting}} again."
        )

        XCTAssertEqual(
            template.render(
                values: [
                    "greeting": "Hello",
                    "name": "Taylor"
                ]
            ),
            "Hello, Taylor! Hello again."
        )
        XCTAssertTrue(
            template.unresolvedVariables(
                values: ["greeting": "Hello", "name": " "]
            ) == ["name"]
        )
    }

    func testPromptTemplateFindsAndRendersRepeatableListVariables() {
        let template = PromptTemplate(
            "Review {{file[]}} for {{teacher}}. Files: {{file[]}}."
        )

        XCTAssertEqual(template.variables, ["file", "teacher"])
        XCTAssertEqual(template.repeatableVariables, ["file"])
        XCTAssertEqual(
            template.render(
                values: ["teacher": "Morgan"],
                repeatableValues: [
                    "file": ["Essay A.docx", "Essay B.docx"]
                ],
                listSeparator: "、"
            ),
            "Review Essay A.docx、Essay B.docx for Morgan. "
                + "Files: Essay A.docx、Essay B.docx."
        )
    }

    func testPromptTemplateRequiresEveryAddedRepeatableValue() {
        let template = PromptTemplate(
            "批改标题：{{文件名[]}}"
        )

        XCTAssertEqual(
            template.unresolvedFields(
                values: [:],
                repeatableValues: [
                    "文件名": ["张三.docx", " "]
                ]
            ),
            [
                PromptTemplateVariable(
                    name: "文件名",
                    kind: .list
                )
            ]
        )
        XCTAssertTrue(
            template.unresolvedFields(
                values: [:],
                repeatableValues: [
                    "文件名": ["张三.docx", "李四.docx"]
                ]
            ).isEmpty
        )
        XCTAssertEqual(
            PromptTemplate.maximumRepeatableValueCount,
            100
        )
    }

    func testPromptTemplateIgnoresMalformedAndEscapedPlaceholders() {
        let template = PromptTemplate(
            #"Keep \{{literal}}, \{{files[]}}, and {{ }} unchanged; fill {{valid}}."#
        )

        XCTAssertEqual(template.variables, ["valid"])
        XCTAssertEqual(
            template.render(values: ["valid": "done"]),
            "Keep {{literal}}, {{files[]}}, and {{ }} unchanged; fill done."
        )
    }

    func testPromptWithoutVariablesKeepsImmediateCopyBehavior() {
        let template = PromptTemplate("A regular reusable prompt.")

        XCTAssertFalse(template.hasVariables)
        XCTAssertEqual(
            template.render(values: [:]),
            "A regular reusable prompt."
        )
    }

    func testTemplateGuideAIRequestIncludesSyntaxAndRequirement() {
        let request = TemplateGuideContent.requestForAI(
            requirement: "批改数量不固定的作文文件",
            usesChinese: true
        )

        XCTAssertTrue(request.contains("{{名称}}"))
        XCTAssertTrue(request.contains("{{名称[]}}"))
        XCTAssertTrue(request.contains("PromptDock 模板语法手册"))
        XCTAssertTrue(request.contains("可重复变量"))
        XCTAssertTrue(request.contains("批改数量不固定的作文文件"))
        XCTAssertTrue(request.contains("只输出最终提示词"))
    }

    func testTemplateGuideAIRequestProvidesPlaceholderWhenEmpty() {
        let request = TemplateGuideContent.requestForAI(
            requirement: "  ",
            usesChinese: false
        )

        XCTAssertTrue(request.contains("{{name}}"))
        XCTAssertTrue(request.contains("{{name[]}}"))
        XCTAssertTrue(
            request.contains("(Add your prompt requirements here.)")
        )
    }

    func testAIProviderBuildsCompatibleChatCompletionURLs() throws {
        let deepSeek = AIProviderConfiguration(
            provider: .deepSeek,
            baseURL: "https://api.deepseek.com",
            model: "deepseek-v4-flash"
        )
        XCTAssertEqual(
            try deepSeek.chatCompletionsURL().absoluteString,
            "https://api.deepseek.com/chat/completions"
        )

        let custom = AIProviderConfiguration(
            provider: .custom,
            baseURL: "https://example.com/v1/",
            model: "custom-model"
        )
        XCTAssertEqual(
            try custom.chatCompletionsURL().absoluteString,
            "https://example.com/v1/chat/completions"
        )

        let fullEndpoint = AIProviderConfiguration(
            provider: .custom,
            baseURL: "https://example.com/api/chat/completions",
            model: "custom-model"
        )
        XCTAssertEqual(
            try fullEndpoint.chatCompletionsURL().absoluteString,
            "https://example.com/api/chat/completions"
        )
    }

    func testAIProviderRejectsRemotePlainHTTPButAllowsLocalhost() throws {
        let remote = AIProviderConfiguration(
            provider: .custom,
            baseURL: "http://example.com/v1",
            model: "model"
        )
        XCTAssertThrowsError(try remote.chatCompletionsURL()) { error in
            XCTAssertEqual(error as? AIServiceError, .insecureBaseURL)
        }

        let local = AIProviderConfiguration(
            provider: .custom,
            baseURL: "http://localhost:11434/v1",
            model: "model"
        )
        XCTAssertEqual(
            try local.chatCompletionsURL().absoluteString,
            "http://localhost:11434/v1/chat/completions"
        )

        let embeddedCredentials = AIProviderConfiguration(
            provider: .custom,
            baseURL: "https://user:secret@example.com/v1",
            model: "model"
        )
        XCTAssertThrowsError(try embeddedCredentials.chatCompletionsURL()) {
            error in
            XCTAssertEqual(error as? AIServiceError, .invalidBaseURL)
        }
    }

    func testAIServiceCleansMarkdownCodeFence() {
        XCTAssertEqual(
            AITemplateService.cleanGeneratedTemplate(
                "```text\nWrite about {{topic}}.\n```"
            ),
            "Write about {{topic}}."
        )
        XCTAssertEqual(
            AITemplateService.cleanGeneratedTemplate(
                "Write about {{topic}}."
            ),
            "Write about {{topic}}."
        )
    }

    func testAIServiceSendsOnlyExplicitRequestAndAuthorization() async throws {
        let session = makeAIStubSession()
        defer { session.invalidateAndCancel() }
        AIStubURLProtocol.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://api.deepseek.com/chat/completions"
            )
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-key"
            )

            return .init(
                statusCode: 200,
                data: Data(
                    #"{"choices":[{"message":{"content":"Write {{topic}}."}}]}"#
                        .utf8
                )
            )
        }
        defer { AIStubURLProtocol.requestHandler = nil }

        let service = AITemplateService(session: session)
        let configuration = AIProviderConfiguration(
            provider: .deepSeek,
            baseURL: AIProviderConfiguration.deepSeekBaseURL,
            model: AIProviderConfiguration.defaultDeepSeekModel
        )
        let builtRequest = try service.makeRequest(
            request: "CURRENT REQUIREMENT",
            configuration: configuration,
            apiKey: "test-key"
        )
        let body = try XCTUnwrap(builtRequest.httpBody)
        let bodyText = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(bodyText.contains("CURRENT REQUIREMENT"))
        XCTAssertFalse(bodyText.contains("PRIVATE SAVED PROMPT"))
        XCTAssertFalse(bodyText.contains("test-key"))

        let result = try await service.generateTemplate(
            request: "CURRENT REQUIREMENT",
            configuration: configuration,
            apiKey: "test-key"
        )

        XCTAssertEqual(result, "Write {{topic}}.")
    }

    func testAIServiceRejectsMissingDeepSeekKeyBeforeNetwork() async {
        let session = makeAIStubSession()
        defer { session.invalidateAndCancel() }
        AIStubURLProtocol.requestHandler = { _ in
            XCTFail("A request must not start without a DeepSeek API key.")
            return .init(statusCode: 200, data: Data())
        }
        defer { AIStubURLProtocol.requestHandler = nil }

        do {
            _ = try await AITemplateService(session: session)
                .generateTemplate(
                    request: "Requirement",
                    configuration: .init(
                        provider: .deepSeek,
                        baseURL: AIProviderConfiguration.deepSeekBaseURL,
                        model: AIProviderConfiguration.defaultDeepSeekModel
                    ),
                    apiKey: nil
                )
            XCTFail("Expected a missing API key error.")
        } catch {
            XCTAssertEqual(error as? AIServiceError, .missingAPIKey)
        }
    }

    func testAIServiceRejectsLineBreakInAPIKey() throws {
        let service = AITemplateService()
        XCTAssertThrowsError(
            try service.makeRequest(
                request: "Requirement",
                configuration: .init(
                    provider: .deepSeek,
                    baseURL: AIProviderConfiguration.deepSeekBaseURL,
                    model: AIProviderConfiguration.defaultDeepSeekModel
                ),
                apiKey: "valid-prefix\r\nInjected: value"
            )
        ) { error in
            XCTAssertEqual(error as? AIServiceError, .invalidAPIKey)
        }
    }

    func testAIServiceReportsHTTPFailureAndOversizedResponse() async throws {
        let session = makeAIStubSession()
        defer { session.invalidateAndCancel() }
        let configuration = AIProviderConfiguration(
            provider: .deepSeek,
            baseURL: AIProviderConfiguration.deepSeekBaseURL,
            model: AIProviderConfiguration.defaultDeepSeekModel
        )
        let service = AITemplateService(session: session)

        AIStubURLProtocol.requestHandler = { _ in
            .init(
                statusCode: 401,
                data: Data(#"{"error":{"message":"Invalid key"}}"#.utf8)
            )
        }
        do {
            _ = try await service.generateTemplate(
                request: "Requirement",
                configuration: configuration,
                apiKey: "bad-key"
            )
            XCTFail("Expected an HTTP error.")
        } catch {
            XCTAssertEqual(
                error as? AIServiceError,
                .http(statusCode: 401, message: "Invalid key")
            )
        }

        AIStubURLProtocol.requestHandler = { _ in
            .init(
                statusCode: 200,
                data: Data(
                    repeating: 0,
                    count: AITemplateService.maximumResponseByteCount + 1
                )
            )
        }
        do {
            _ = try await service.generateTemplate(
                request: "Requirement",
                configuration: configuration,
                apiKey: "test-key"
            )
            XCTFail("Expected an oversized response error.")
        } catch {
            XCTAssertEqual(error as? AIServiceError, .responseTooLarge)
        }
        AIStubURLProtocol.requestHandler = nil
    }

    func testAIServicePreservesTaskCancellation() async throws {
        let session = makeAIStubSession()
        defer { session.invalidateAndCancel() }
        AIStubURLProtocol.requestHandler = { _ in
            .init(
                statusCode: 200,
                data: Data(
                    #"{"choices":[{"message":{"content":"Late"}}]}"#.utf8
                ),
                delay: 5
            )
        }
        defer { AIStubURLProtocol.requestHandler = nil }

        let task = Task {
            try await AITemplateService(session: session).generateTemplate(
                request: "Requirement",
                configuration: .init(
                    provider: .deepSeek,
                    baseURL: AIProviderConfiguration.deepSeekBaseURL,
                    model: AIProviderConfiguration.defaultDeepSeekModel
                ),
                apiKey: "test-key"
            )
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, received: \(error)")
        }
    }

    private func makeAIStubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func testLanguageDefaultsAndManualSelection() {
        XCTAssertEqual(AppLanguage.english.locale.identifier, "en")
        XCTAssertTrue(AppLanguage.simplifiedChinese.usesChinese)
        XCTAssertEqual(
            AppLanguage.simplifiedChinese.text(
                english: "Language",
                chinese: "语言"
            ),
            "语言"
        )
    }

    func testCategoryNameIdentityIsStableAcrossCaseAndDiacritics() {
        XCTAssertEqual(
            CategoryNameIdentity.normalized("  Résumé  "),
            CategoryNameIdentity.normalized("resume")
        )
        XCTAssertEqual(
            CategoryNameIdentity.normalized("编程"),
            "编程"
        )
        XCTAssertNotEqual(
            CategoryNameIdentity.normalized("I"),
            CategoryNameIdentity.normalized("ı")
        )
    }

    func testBoundedFileReaderAcceptsLimitAndRejectsOneExtraByte() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("input.bin")

        let accepted = Data(repeating: 7, count: 128)
        try accepted.write(to: fileURL)
        XCTAssertEqual(
            try BoundedFileReader.read(
                url: fileURL,
                maximumByteCount: 128
            ),
            accepted
        )

        try Data(repeating: 8, count: 129).write(to: fileURL)
        XCTAssertThrowsError(
            try BoundedFileReader.read(
                url: fileURL,
                maximumByteCount: 128
            )
        ) { error in
            XCTAssertEqual(
                error as? BoundedFileReaderError,
                .fileTooLarge(maximumByteCount: 128)
            )
        }
    }

    func testBoundedFileReaderUsesAlreadyOpenedFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("input.bin")
        let original = Data("original".utf8)
        try original.write(to: fileURL)

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        try Data("replacement".utf8).write(to: fileURL, options: .atomic)

        XCTAssertEqual(
            try BoundedFileReader.read(
                fileHandle: handle,
                maximumByteCount: 32
            ),
            original
        )
    }

    func testWidgetSnapshotsRoundTripThroughSharedStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(
            fileURL: directory.appendingPathComponent("prompts.json")
        )

        let snapshot = WidgetPromptSnapshot(
            id: UUID(),
            title: "Widget Prompt",
            category: "AI",
            content: "Summarize this document.",
            updatedDate: .now,
            isFavorite: true
        )

        try store.save([snapshot])
        XCTAssertEqual(try store.load(), [snapshot])

        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load())
    }

    func testBuiltInCategoryLocalizationAndLocalizedSearch() {
        let chinese = Locale(identifier: "zh-Hans")
        XCTAssertEqual(
            BuiltInCategoryPresentation.displayName(
                for: "Coding",
                locale: chinese
            ),
            "编程"
        )
        XCTAssertEqual(
            BuiltInCategoryPresentation.displayName(
                for: "My Category",
                locale: chinese
            ),
            "My Category"
        )

        let prompt = Prompt(
            title: "Swift",
            category: "Coding",
            content: "Actors"
        )
        XCTAssertEqual(
            PromptSearchService.results(
                in: [prompt],
                query: "编程",
                locale: chinese
            ).map(\.id),
            [prompt.id]
        )
    }

    func testLimitedSearchMatchesFullSearchPrefix() {
        let prompts = (0..<10_000).map { index in
            Prompt(
                title: "Swift Result \(index)",
                category: index.isMultiple(of: 2) ? "Coding" : "Teaching",
                content: "A deterministic search result \(index)",
                updatedDate: Date(timeIntervalSince1970: TimeInterval(index)),
                isFavorite: index.isMultiple(of: 17)
            )
        }
        let full = PromptSearchService.results(
            in: prompts,
            query: "Swift",
            locale: Locale(identifier: "en")
        )
        let limited = PromptSearchService.results(
            in: prompts,
            query: "Swift",
            locale: Locale(identifier: "en"),
            limit: 12
        )
        XCTAssertEqual(limited.map(\.id), full.prefix(12).map(\.id))
    }

    @MainActor
    func testHotKeyRegistrationFailureRestoresPreviousCombination() {
        let registrar = FakeGlobalHotKeyRegistrar()
        let service = GlobalHotKeyService(registrar: registrar)
        service.setEnabled(true)
        let previous = service.combination

        registrar.nextStatus = -1
        let candidate = HotKeyCombination(
            keyCode: 40,
            modifiers: UInt32(cmdKey | shiftKey)
        )
        XCTAssertFalse(service.apply(candidate))
        XCTAssertEqual(service.combination, previous)
        XCTAssertEqual(registrar.registered.last, previous)
        guard case .registrationFailed(-1) = service.conflictStatus else {
            XCTFail("Expected registration failure status")
            return
        }
    }

    @MainActor
    func testBootstrapReportsModelContainerFailure() async {
        struct TestFailure: Error {}
        let bootstrap = AppBootstrapController {
            throw TestFailure()
        }

        for _ in 0..<100 {
            if case .failed = bootstrap.state { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        guard case .failed(let failure) = bootstrap.state else {
            XCTFail("Expected bootstrap failure")
            return
        }
        XCTAssertFalse(failure.diagnosticDetails.isEmpty)
    }

    @MainActor
    func testCategoryServiceSeedsDefaultsAndExistingPromptCategories() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        let prompt = Prompt(
            title: "Research Notes",
            category: "Research",
            content: "Organize these research notes."
        )
        context.insert(prompt)
        try context.save()

        try CategoryService.ensureCategories(
            for: [prompt],
            in: context
        )

        let categories = try context.fetch(
            FetchDescriptor<PromptCategory>(
                sortBy: [SortDescriptor(\PromptCategory.sortOrder)]
            )
        )
        XCTAssertEqual(
            categories.map(\.name),
            ["Teaching", "Coding", "AI", "Writing", "Research"]
        )
    }

    @MainActor
    func testCategoryServiceCreatesRejectsDuplicatesAndReorders() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        try CategoryService.ensureCategories(for: [], in: context)
        let research = try CategoryService.createCategory(
            named: "  Research  ",
            in: context
        )
        XCTAssertEqual(research.name, "Research")

        XCTAssertThrowsError(
            try CategoryService.createCategory(
                named: "research",
                in: context
            )
        ) { error in
            guard case CategoryValidationError.duplicateName = error else {
                XCTFail("Expected duplicate category error")
                return
            }
        }

        var categories = try context.fetch(
            FetchDescriptor<PromptCategory>(
                sortBy: [SortDescriptor(\PromptCategory.sortOrder)]
            )
        )
        try CategoryService.moveCategories(
            categories,
            from: IndexSet(integer: categories.count - 1),
            to: 0,
            in: context
        )

        categories = try context.fetch(
            FetchDescriptor<PromptCategory>(
                sortBy: [SortDescriptor(\PromptCategory.sortOrder)]
            )
        )
        XCTAssertEqual(categories.first?.name, "Research")
    }

    @MainActor
    func testCustomCategoryIconPersistsAndCanBeReplaced() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        let category = try CategoryService.createCategory(
            named: "Travel",
            icon: CategoryIconDraft(kind: .emoji, emoji: "🧳"),
            in: context
        )

        XCTAssertEqual(category.iconKind, .emoji)
        XCTAssertEqual(category.iconEmoji, "🧳")

        let imageData = try makeProcessedTestImage()
        try CategoryService.renameCategory(
            category,
            to: "Trips",
            icon: CategoryIconDraft(
                kind: .localImage,
                imageData: imageData
            ),
            prompts: [],
            in: context
        )

        let saved = try XCTUnwrap(
            try ModelContext(container)
                .fetch(FetchDescriptor<PromptCategory>())
                .first
        )
        XCTAssertEqual(saved.name, "Trips")
        XCTAssertEqual(saved.iconKind, .localImage)
        XCTAssertEqual(saved.iconImageData, imageData)
        XCTAssertNil(saved.iconEmoji)
    }

    func testCategoryImageProcessorNormalizesAndRejectsInvalidInput() throws {
        let output = try makeProcessedTestImage()
        let representation = try XCTUnwrap(NSBitmapImageRep(data: output))
        XCTAssertEqual(representation.pixelsWide, 128)
        XCTAssertEqual(representation.pixelsHigh, 128)

        XCTAssertThrowsError(try CategoryImageProcessor.process(Data()))
        XCTAssertThrowsError(
            try CategoryImageProcessor.process(
                Data(
                    repeating: 0,
                    count: CategoryImageProcessor.maximumSourceByteCount + 1
                )
            )
        ) { error in
            guard case CategoryImageError.fileTooLarge = error else {
                XCTFail("Expected the image size limit error")
                return
            }
        }
    }

    private func makeProcessedTestImage() throws -> Data {
        let image = NSImage(size: NSSize(width: 240, height: 120))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 240, height: 120).fill()
        image.unlockFocus()
        return try CategoryImageProcessor.process(
            try XCTUnwrap(image.tiffRepresentation)
        )
    }

    @MainActor
    func testCategoryServiceRenamesCategoryAndItsPrompts() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        try CategoryService.ensureCategories(for: [], in: context)
        let research = try CategoryService.createCategory(
            named: "Research",
            in: context
        )
        let prompt = Prompt(
            title: "Research Notes",
            category: "Research",
            content: "Organize these notes."
        )
        context.insert(prompt)
        try context.save()

        let renamedName = try CategoryService.renameCategory(
            research,
            to: "References",
            prompts: [prompt],
            in: context
        )

        XCTAssertEqual(renamedName, "References")
        XCTAssertEqual(research.name, "References")
        XCTAssertEqual(prompt.category, "References")

        XCTAssertThrowsError(
            try CategoryService.renameCategory(
                research,
                to: "Coding",
                prompts: [prompt],
                in: context
            )
        ) { error in
            guard case CategoryValidationError.duplicateName = error else {
                XCTFail("Expected duplicate category error")
                return
            }
        }
    }

    @MainActor
    func testCategoryServiceDeletesCategoryWithoutDeletingPrompts() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        try CategoryService.ensureCategories(for: [], in: context)
        let research = try CategoryService.createCategory(
            named: "Research",
            in: context
        )
        let prompt = Prompt(
            title: "Research Notes",
            category: "Research",
            content: "Organize these notes."
        )
        context.insert(prompt)
        try context.save()

        let destination = try CategoryService.deleteCategory(
            research,
            categories: try context.fetch(
                FetchDescriptor<PromptCategory>(
                    sortBy: [SortDescriptor(\PromptCategory.sortOrder)]
                )
            ),
            prompts: [prompt],
            in: context
        )

        let savedPrompts = try context.fetch(FetchDescriptor<Prompt>())
        let savedCategories = try context.fetch(
            FetchDescriptor<PromptCategory>()
        )
        XCTAssertEqual(destination, "Teaching")
        XCTAssertEqual(savedPrompts.map(\.id), [prompt.id])
        XCTAssertEqual(prompt.category, "Teaching")
        XCTAssertFalse(savedCategories.contains { $0.id == research.id })
    }

    @MainActor
    func testCategoryServiceProtectsBuiltInCategories() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        try CategoryService.ensureCategories(for: [], in: context)
        let categories = try context.fetch(FetchDescriptor<PromptCategory>())
        let builtIn = try XCTUnwrap(categories.first { $0.isBuiltIn })

        XCTAssertThrowsError(
            try CategoryService.renameCategory(
                builtIn,
                to: "Lessons",
                prompts: [],
                in: context
            )
        ) { error in
            guard case CategoryValidationError.builtInCategory = error else {
                XCTFail("Expected built-in category error")
                return
            }
        }
    }

    @MainActor
    func testBackupRoundTripPreservesPromptsCategoriesAndImages() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        let imageData = try makeProcessedTestImage()
        let category = PromptCategory(
            name: "Reference",
            sortOrder: 0,
            iconKind: .localImage,
            iconImageData: imageData
        )
        let prompt = Prompt(
            title: "Review Notes",
            category: "Reference",
            content: "Summarize these notes.",
            isFavorite: true
        )
        context.insert(category)
        context.insert(prompt)
        try context.save()

        let backup = try BackupService.makeBackup(in: context)
        let decoded = try BackupService.decode(
            BackupService.encode(backup)
        )

        XCTAssertEqual(decoded.formatVersion, backup.formatVersion)
        XCTAssertEqual(decoded.appVersion, backup.appVersion)
        XCTAssertEqual(decoded.prompts.map(\.id), backup.prompts.map(\.id))
        XCTAssertEqual(decoded.prompts.map(\.title), backup.prompts.map(\.title))
        XCTAssertEqual(decoded.prompts.map(\.content), backup.prompts.map(\.content))
        XCTAssertEqual(decoded.categories.map(\.id), backup.categories.map(\.id))
        XCTAssertEqual(decoded.categories.map(\.name), backup.categories.map(\.name))
        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            backup.createdAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(decoded.prompts.first?.id, prompt.id)
        XCTAssertEqual(decoded.categories.first?.iconImageData, imageData)
    }

    func testBackupValidationRejectsDuplicateCategoryNames() {
        let first = PromptDockBackup.CategoryRecord(
            id: UUID(),
            name: "Research",
            systemImage: "folder",
            sortOrder: 0,
            createdDate: .now,
            isBuiltIn: false,
            iconKind: .emoji,
            iconEmoji: "📁",
            iconImageData: nil
        )
        var duplicate = first
        duplicate.id = UUID()
        duplicate.name = " research "
        let backup = PromptDockBackup(
            formatVersion: PromptDockBackup.currentFormatVersion,
            createdAt: .now,
            appVersion: "Test",
            prompts: [],
            categories: [first, duplicate]
        )

        XCTAssertThrowsError(try BackupService.validate(backup)) { error in
            guard case BackupError.duplicateCategoryName = error else {
                XCTFail("Expected duplicate category name error")
                return
            }
        }
    }

    @MainActor
    func testBackupMergeUpdatesMatchingPromptAndAddsNewData() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        let existing = Prompt(
            title: "Old Title",
            category: "Coding",
            content: "Old content"
        )
        context.insert(existing)
        try context.save()

        let newPromptID = UUID()
        let backup = PromptDockBackup(
            formatVersion: PromptDockBackup.currentFormatVersion,
            createdAt: .now,
            appVersion: "Test",
            prompts: [
                PromptDockBackup.PromptRecord(
                    id: existing.id,
                    title: "Updated Title",
                    category: " coding ",
                    content: "Updated content",
                    createdDate: existing.createdDate,
                    updatedDate: .now,
                    isFavorite: true
                ),
                PromptDockBackup.PromptRecord(
                    id: newPromptID,
                    title: "New Prompt",
                    category: "Research",
                    content: "New content",
                    createdDate: .now,
                    updatedDate: .now,
                    isFavorite: false
                )
            ],
            categories: [
                PromptDockBackup.CategoryRecord(
                    id: UUID(),
                    name: "Coding",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    sortOrder: 0,
                    createdDate: .now,
                    isBuiltIn: true,
                    iconKind: .sfSymbol,
                    iconEmoji: nil,
                    iconImageData: nil
                )
            ]
        )

        _ = try BackupService.importBackup(
            backup,
            mode: .merge,
            in: context,
            createsSafetyBackup: false
        )

        let prompts = try context.fetch(FetchDescriptor<Prompt>())
        let categories = try context.fetch(FetchDescriptor<PromptCategory>())
        XCTAssertEqual(prompts.count, 2)
        XCTAssertEqual(
            prompts.first { $0.id == existing.id }?.title,
            "Updated Title"
        )
        XCTAssertTrue(prompts.first { $0.id == existing.id }?.isFavorite == true)
        XCTAssertEqual(
            prompts.first { $0.id == existing.id }?.category,
            "Coding"
        )
        XCTAssertTrue(categories.contains { $0.name == "Research" })
        XCTAssertTrue(categories.contains { $0.name == "Coding" })
    }

    @MainActor
    func testBackupReplaceRemovesOldData() throws {
        let container = try DataService.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = ModelContext(container)
        let existing = Prompt(
            title: "Remove Me",
            category: "Old",
            content: "Old content"
        )
        context.insert(existing)
        try context.save()

        let replacement = PromptDockBackup.PromptRecord(
            id: existing.id,
            title: "Keep Me",
            category: "Writing",
            content: "New content",
            createdDate: .now,
            updatedDate: .now,
            isFavorite: false
        )
        let backup = PromptDockBackup(
            formatVersion: PromptDockBackup.currentFormatVersion,
            createdAt: .now,
            appVersion: "Test",
            prompts: [replacement],
            categories: []
        )

        _ = try BackupService.importBackup(
            backup,
            mode: .replace,
            in: context,
            createsSafetyBackup: false
        )

        let prompts = try context.fetch(FetchDescriptor<Prompt>())
        XCTAssertEqual(prompts.map(\.id), [replacement.id])
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<PromptCategory>())
                .contains { $0.name == "Writing" }
        )
    }

    @MainActor
    func testVersionedContainerOpensExistingVersionOneStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("PromptDock.store")

        var legacyContainer: ModelContainer? = try ModelContainer(
            for: Schema([Prompt.self, PromptCategory.self]),
            configurations: [
                ModelConfiguration(
                    "Legacy",
                    schema: Schema([Prompt.self, PromptCategory.self]),
                    url: storeURL
                )
            ]
        )
        let legacyContext = ModelContext(try XCTUnwrap(legacyContainer))
        let promptID = UUID()
        legacyContext.insert(
            Prompt(
                id: promptID,
                title: "Existing Prompt",
                category: "Coding",
                content: "Keep this data."
            )
        )
        try legacyContext.save()
        legacyContainer = nil

        let migratedContainer = try DataService.makeModelContainer(
            storeURL: storeURL
        )
        let migratedPrompts = try ModelContext(migratedContainer).fetch(
            FetchDescriptor<Prompt>()
        )
        XCTAssertEqual(migratedPrompts.map(\.id), [promptID])
    }
    @MainActor
    func testPhase1HistoryCapturesAndRestores() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let prompt = Prompt(title: "First", category: "Coding", content: "one")
        context.insert(prompt)
        try context.save()

        try Phase1Service.captureVersionIfChanged(
            for: prompt,
            title: "Second",
            category: "Coding",
            content: "two",
            in: context
        )
        prompt.title = "Second"
        prompt.content = "two"
        try context.save()

        let versions = try context.fetch(FetchDescriptor<PromptVersion>())
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions[0].title, "First")

        try Phase1Service.restore(versions[0], to: prompt, in: context)
        XCTAssertEqual(prompt.title, "First")
        XCTAssertEqual(prompt.content, "one")
        XCTAssertEqual(try context.fetch(FetchDescriptor<PromptVersion>()).count, 2)
    }

    @MainActor
    func testSmartCollectionMatchesFavoriteAndTags() {
        let prompt = Prompt(title: "Swift", category: "Coding", content: "Actors")
        prompt.isFavorite = true
        let tag = PromptTag(name: "Release", color: .blue, promptIDs: [prompt.id])
        let collection = SmartCollection(
            name: "Favorite releases",
            query: "swift",
            tagIDs: [tag.id],
            favoriteOnly: true
        )

        XCTAssertTrue(Phase1Service.matches(prompt, collection: collection, tags: [tag]))
        prompt.isFavorite = false
        XCTAssertFalse(Phase1Service.matches(prompt, collection: collection, tags: [tag]))
    }

    @MainActor
    func testSmartCollectionCanMatchAnyCondition() {
        let prompt = Prompt(title: "Swift", category: "Coding", content: "Actors")
        let collection = SmartCollection(
            name: "Broad",
            query: "missing",
            category: "coding",
            matchAll: false
        )

        XCTAssertTrue(Phase1Service.matches(prompt, collection: collection, tags: []))
        collection.matchAll = true
        XCTAssertFalse(Phase1Service.matches(prompt, collection: collection, tags: []))
    }

    @MainActor
    func testBulkOrganizationUpdatesPromptsAndTags() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let first = Prompt(title: "One", category: "Writing", content: "First")
        let second = Prompt(title: "Two", category: "Writing", content: "Second")
        let tag = PromptTag(name: "Important", color: .red)
        [first, second].forEach(context.insert)
        context.insert(tag)
        try context.save()

        try Phase1Service.move(prompts: [first, second], to: "Coding", in: context)
        try Phase1Service.setTag(tag, for: [first, second], isIncluded: true, in: context)
        try Phase1Service.setFavorite(true, for: [first, second], in: context)

        XCTAssertEqual(first.category, "Coding")
        XCTAssertEqual(second.category, "Coding")
        XCTAssertTrue(first.isFavorite && second.isFavorite)
        XCTAssertEqual(Set(tag.promptIDs), Set([first.id, second.id]))

        try Phase1Service.setTag(tag, for: [first], isIncluded: false, in: context)
        XCTAssertEqual(tag.promptIDs, [second.id])
    }

    @MainActor
    func testVariableDefinitionsUseDraftMetadataAndRemoveOrphans() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let prompt = Prompt(
            title: "Template",
            category: "Writing",
            content: "Review {{file[]}} for {{audience}}"
        )
        context.insert(prompt)
        try context.save()

        try Phase1Service.syncVariableDefinitions(
            promptID: prompt.id,
            drafts: [
                TemplateVariableDraft(
                    name: "audience",
                    label: "Reader",
                    defaultValue: "Students",
                    order: 0
                ),
                TemplateVariableDraft(
                    name: "file",
                    label: "Document",
                    order: 1,
                    isRepeatable: true
                )
            ],
            content: prompt.content,
            in: context
        )
        try context.save()

        var definitions = try context.fetch(FetchDescriptor<TemplateVariableDefinition>())
        XCTAssertEqual(definitions.count, 2)
        XCTAssertEqual(definitions.first(where: { $0.name == "audience" })?.label, "Reader")
        XCTAssertEqual(definitions.first(where: { $0.name == "audience" })?.defaultValue, "Students")
        XCTAssertEqual(definitions.first(where: { $0.name == "file" })?.isRepeatable, true)

        try Phase1Service.syncVariableDefinitions(
            promptID: prompt.id,
            drafts: [],
            content: "Review {{file[]}}",
            in: context
        )
        try context.save()

        definitions = try context.fetch(FetchDescriptor<TemplateVariableDefinition>())
        XCTAssertEqual(definitions.map(\.name), ["file"])
    }

    @MainActor
    func testTagFilterAndRecentSectionUseExistingData() {
        let tagged = Prompt(title: "Tagged", category: "AI", content: "One")
        let other = Prompt(title: "Other", category: "AI", content: "Two")
        let tag = PromptTag(name: "Release", promptIDs: [tagged.id])
        let viewModel = PromptViewModel()

        viewModel.selectedSection = .tag(tag.id, tag.name)
        XCTAssertEqual(
            viewModel.filteredPrompts(from: [tagged, other], tags: [tag]).map(\.id),
            [tagged.id]
        )

        let prompts = (0..<25).map { index in
            Prompt(title: "Prompt \(index)", category: "AI", content: "Content")
        }
        viewModel.selectedSection = .recent
        XCTAssertEqual(viewModel.filteredPrompts(from: prompts).count, 20)
    }

    @MainActor
    func testBackupV2RoundTripPreservesPhase1Records() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let prompt = Prompt(title: "Template", category: "AI", content: "Hello {{name}}")
        let tag = PromptTag(name: "Reusable", color: .blue, promptIDs: [prompt.id])
        let collection = SmartCollection(name: "AI templates", query: "template")
        let definition = TemplateVariableDefinition(promptID: prompt.id, name: "name", order: 0)
        context.insert(prompt)
        context.insert(tag)
        context.insert(collection)
        context.insert(definition)
        try context.save()

        let backup = try BackupService.makeBackup(in: context)
        XCTAssertEqual(backup.formatVersion, PromptDockBackup.currentFormatVersion)
        XCTAssertEqual(backup.tags.first?.name, "Reusable")
        XCTAssertEqual(backup.smartCollections.first?.name, "AI templates")
        XCTAssertEqual(backup.variableDefinitions.first?.name, "name")

        try BackupService.importBackup(backup, mode: .replace, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PromptTag>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SmartCollection>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TemplateVariableDefinition>()).count, 1)
    }
}

@MainActor
private final class FakeGlobalHotKeyRegistrar: GlobalHotKeyRegistering {
    var onTrigger: (() -> Void)?
    var nextStatus: OSStatus = noErr
    private(set) var registered: [HotKeyCombination] = []

    func register(_ combination: HotKeyCombination) -> OSStatus {
        registered.append(combination)
        let status = nextStatus
        nextStatus = noErr
        return status
    }

    func unregister() {}
}

private final class AIStubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
        let delay: TimeInterval

        init(
            statusCode: Int,
            data: Data,
            delay: TimeInterval = 0
        ) {
            self.statusCode = statusCode
            self.data = data
            self.delay = delay
        }
    }

    static var requestHandler: ((URLRequest) throws -> Stub)?

    private var delivery: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.resourceUnavailable)
            )
            return
        }

        do {
            let stub = try requestHandler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: stub.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                  )
            else {
                throw URLError(.badServerResponse)
            }

            let delivery = DispatchWorkItem { [weak self] in
                guard let self, self.delivery?.isCancelled == false else {
                    return
                }
                self.client?.urlProtocol(
                    self,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
                self.client?.urlProtocol(self, didLoad: stub.data)
                self.client?.urlProtocolDidFinishLoading(self)
            }
            self.delivery = delivery
            if stub.delay > 0 {
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + stub.delay,
                    execute: delivery
                )
            } else {
                delivery.perform()
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        delivery?.cancel()
        delivery = nil
    }
}
