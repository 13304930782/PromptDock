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
        XCTAssertEqual(savedPrompts.count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrashEntry>()).map(\.promptID), [createdPrompt.id])
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

    func testPromptTemplateTreatsMixedSyntaxForOneNameAsRepeatable() {
        let template = PromptTemplate(
            "Primary: {{file}}; all files: {{file[]}}."
        )

        XCTAssertEqual(
            template.fields,
            [PromptTemplateVariable(name: "file", kind: .list)]
        )
        XCTAssertEqual(
            template.render(
                values: [:],
                repeatableValues: ["file": ["A.docx", "B.docx"]],
                listSeparator: ", "
            ),
            "Primary: A.docx, B.docx; all files: A.docx, B.docx."
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
    func testDeletingPromptsRemovesTagsHistoryAndVariableDefinitions() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let first = Prompt(title: "One", category: "AI", content: "Hello {{name}}")
        let second = Prompt(title: "Two", category: "AI", content: "Keep")
        let tag = PromptTag(name: "Release", promptIDs: [first.id, second.id])
        context.insert(first)
        context.insert(second)
        context.insert(tag)
        context.insert(PromptVersion(
            promptID: first.id,
            title: first.title,
            category: first.category,
            content: first.content
        ))
        context.insert(TemplateVariableDefinition(promptID: first.id, name: "name"))
        try context.save()

        try Phase1Service.permanentlyDelete(prompts: [first], tags: [tag], in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Prompt>()).map(\.id), [second.id])
        XCTAssertEqual(tag.promptIDs, [second.id])
        XCTAssertTrue(try context.fetch(FetchDescriptor<PromptVersion>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TemplateVariableDefinition>()).isEmpty)
    }

    @MainActor
    func testUpdatingPromptPreservesSubmittedTagsAndVariableMetadata() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let prompt = Prompt(title: "Template", category: "AI", content: "Hello {{name}}")
        let tag = PromptTag(name: "Reusable", promptIDs: [prompt.id])
        let definition = TemplateVariableDefinition(
            promptID: prompt.id,
            name: "name",
            label: "Recipient",
            defaultValue: "World",
            order: 0
        )
        context.insert(prompt)
        context.insert(tag)
        context.insert(definition)
        try context.save()

        try PromptViewModel().updatePrompt(
            prompt,
            from: PromptDraft(
                title: "Updated Template",
                category: "AI",
                content: "Welcome {{name}}",
                tagIDs: [tag.id],
                variableDefinitions: [TemplateVariableDraft(definition)]
            ),
            tags: [tag],
            in: context
        )

        let savedDefinition = try XCTUnwrap(
            context.fetch(FetchDescriptor<TemplateVariableDefinition>()).first
        )
        XCTAssertEqual(tag.promptIDs, [prompt.id])
        XCTAssertEqual(savedDefinition.label, "Recipient")
        XCTAssertEqual(savedDefinition.defaultValue, "World")
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
    func testVariableDefinitionsCollapseMixedSyntaxAndDuplicateDrafts() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let promptID = UUID()
        context.insert(TemplateVariableDefinition(promptID: promptID, name: "file"))
        context.insert(TemplateVariableDefinition(promptID: promptID, name: "file"))
        try context.save()

        try Phase1Service.syncVariableDefinitions(
            promptID: promptID,
            drafts: [
                TemplateVariableDraft(name: "file", label: "First", order: 0),
                TemplateVariableDraft(name: "file", label: "Documents", order: 1, isRepeatable: true)
            ],
            content: "Primary: {{file}}; all files: {{file[]}}",
            in: context
        )
        try context.save()

        let definitions = try context.fetch(FetchDescriptor<TemplateVariableDefinition>())
        XCTAssertEqual(definitions.count, 1)
        XCTAssertEqual(definitions.first?.label, "Documents")
        XCTAssertEqual(definitions.first?.isRepeatable, true)
    }

    @MainActor
    func testSelectionFallbackUsesVisiblePromptOrder() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let viewModel = PromptViewModel()
        viewModel.selectedPromptIDs = [first, second, third]
        viewModel.selectedPromptID = first

        viewModel.updateSelection([second, third], orderedBy: [first, second, third])

        XCTAssertEqual(viewModel.selectedPromptID, second)
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
            Prompt(
                title: "Prompt \(index)",
                category: "AI",
                content: "Content",
                updatedDate: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        viewModel.selectedSection = .recent
        let recent = viewModel.filteredPrompts(from: prompts)
        XCTAssertEqual(recent.count, 20)
        XCTAssertEqual(recent.first?.title, "Prompt 24")
        XCTAssertEqual(recent.last?.title, "Prompt 5")
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


extension PromptDockTests {
    func testTestEnvironmentDetectionDoesNotDependOnDebugBuild() {
        XCTAssertTrue(AppEnvironment.isTesting(environment: ["PROMPTDOCK_TESTING": "1"]))
        XCTAssertTrue(AppEnvironment.isTesting(environment: ["XCTestConfigurationFilePath": "/tmp/tests"]))
        XCTAssertFalse(AppEnvironment.isTesting(environment: [:]))
    }

    @MainActor
    func testTestHostNeverResolvesSharedContainer() throws {
        XCTAssertTrue(AppEnvironment.isTesting)
        XCTAssertNil(DataService.dataDirectoryURLIfAvailable())
        let first = try DataService.makeModelContainer()
        first.mainContext.insert(Prompt(title: "Test only", category: "Coding", content: "Private"))
        try first.mainContext.save()
        let second = try DataService.makeModelContainer()
        XCTAssertTrue(try second.mainContext.fetch(FetchDescriptor<Prompt>()).isEmpty)
        XCTAssertTrue(try WidgetSharedStore.load().isEmpty)
    }

    @MainActor
    func testDisabledBootstrapDoesNotCallStorageFactory() async {
        var attempts = 0
        let bootstrap = AppBootstrapController(automaticallyStart: false) {
            attempts += 1
            throw CocoaError(.fileReadNoPermission)
        }
        await Task.yield()
        XCTAssertEqual(attempts, 0)
        bootstrap.retry()
        for _ in 0..<100 {
            if case .failed = bootstrap.state { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(attempts, 1)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(attempts, 1, "Permission denial must not trigger automatic retries")
    }
}

extension PromptDockTests {
    @MainActor
    func testTrashRestorePreservesIdentityAndAssociatedRecords() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let prompt = Prompt(title: "Keep", category: "AI", content: "Hello {{name}}")
        let tag = PromptTag(name: "Tag", promptIDs: [prompt.id])
        context.insert(prompt)
        context.insert(tag)
        context.insert(PromptVersion(promptID: prompt.id, title: "Before", category: "AI", content: "Before"))
        context.insert(TemplateVariableDefinition(promptID: prompt.id, name: "name", defaultValue: "World"))
        try context.save()
        try TrashService.move([prompt], in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrashEntry>()).count, 1)
        try TrashService.restore([prompt.id], in: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TrashEntry>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Prompt>()).first?.id, prompt.id)
        XCTAssertEqual(tag.promptIDs, [prompt.id])
        XCTAssertEqual(try context.fetch(FetchDescriptor<PromptVersion>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TemplateVariableDefinition>()).first?.defaultValue, "World")
    }

    @MainActor
    func testTrashExpiresOnlyAfterThirtyDays() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let prompt = Prompt(title: "Expire", category: "AI", content: "Content")
        context.insert(prompt)
        try context.save()
        let now = Date(timeIntervalSince1970: 1_000_000)
        try TrashService.move([prompt], in: context, now: now)
        try TrashService.purgeExpired(in: context, now: now.addingTimeInterval(29 * 86400))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Prompt>()).count, 1)
        try TrashService.purgeExpired(in: context, now: now.addingTimeInterval(30 * 86400))
        XCTAssertTrue(try context.fetch(FetchDescriptor<Prompt>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TrashEntry>()).isEmpty)
    }

    @MainActor
    func testV1BackupWithoutNewFieldsStillDecodes() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: BackupService.encode(BackupService.makeBackup(in: context))) as? [String: Any])
        object["formatVersion"] = 1
        for key in ["versions", "tags", "smartCollections", "variableDefinitions", "trash"] { object.removeValue(forKey: key) }
        let decoded = try BackupService.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(decoded.trash.isEmpty)
        XCTAssertTrue(decoded.variableDefinitions.isEmpty)
    }

    @MainActor
    func testV3BackupRoundTripIncludesTrashAndWhitespace() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let prompt = Prompt(title: "Whitespace", category: "AI", content: "\n  keep indentation  \n")
        context.insert(prompt)
        try context.save()
        try TrashService.move([prompt], in: context)
        let backup = try BackupService.makeBackup(in: context)
        let restoredContainer = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        defer { withExtendedLifetime(restoredContainer) {} }
        let restored = restoredContainer.mainContext
        _ = try BackupService.importBackup(BackupService.decode(BackupService.encode(backup)), mode: .replace, in: restored, createsSafetyBackup: false)
        XCTAssertEqual(try restored.fetch(FetchDescriptor<Prompt>()).first?.content, prompt.content)
        XCTAssertEqual(try restored.fetch(FetchDescriptor<TrashEntry>()).first?.promptID, prompt.id)
    }

    @MainActor
    func testAutomaticBackupRetainsSevenAndPausesAfterFailure() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: folder); defaults.removePersistentDomain(forName: suite) }
        let service = AutomaticBackupService(directory: folder, defaults: defaults)
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        for index in 0..<9 {
            try service.backupNow(container: container, now: Date(timeIntervalSince1970: Double(1_000_000 + index * 86400)))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).count, 7)
        let invalid = folder.appendingPathComponent("file")
        try Data().write(to: invalid)
        let failing = AutomaticBackupService(directory: invalid, defaults: defaults)
        failing.beforeSave(container: container)
        XCTAssertNotNil(failing.lastError)
        try FileManager.default.removeItem(at: invalid)
        failing.beforeSave(container: container)
        XCTAssertFalse(FileManager.default.fileExists(atPath: invalid.path), "Failure must pause automatic retry")
        try failing.backupNow(container: container)
        XCTAssertNil(failing.lastError)
    }
}

extension PromptDockTests {
    @MainActor
    func testCSVMultilineQuotesAndUnicodeRoundTrip() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let prompt = Prompt(title: "中文, \"quotes\"", category: "Writing", content: "line 1\r\nline 2, \"quoted\"")
        context.insert(prompt)
        context.insert(PromptTag(name: "标签,一", promptIDs: [prompt.id]))
        try context.save()
        let backup = try BackupService.makeBackup(in: context)
        let batch = TransferService.parse([(name: "test.csv", data: try TransferService.csv(backup))])
        XCTAssertTrue(batch.errors.isEmpty, batch.errors.joined(separator: "\n"))
        XCTAssertEqual(batch.items.first?.record.content, prompt.content)
        XCTAssertEqual(batch.items.first?.record.title, prompt.title)
        XCTAssertEqual(batch.items.first?.tagNames, ["标签,一"])
        XCTAssertThrowsError(try TransferService.parseCSV("title,\"unclosed"))
    }

    @MainActor
    func testMarkdownMetadataRoundTripAndPlainFilenameTitle() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let prompt = Prompt(title: "Original title", category: "Coding", content: "\n# Body\n{{value}}\n", isFavorite: true)
        context.insert(prompt)
        context.insert(TemplateVariableDefinition(promptID: prompt.id, name: "value", defaultValue: "Default"))
        try context.save()
        let files = try TransferService.markdownFiles(BackupService.makeBackup(in: context))
        let batch = TransferService.parse(files.map { (name: $0.0, data: $0.1) })
        XCTAssertTrue(batch.errors.isEmpty)
        XCTAssertEqual(batch.items.first?.record.content, prompt.content)
        XCTAssertEqual(batch.items.first?.record.title, prompt.title)
        XCTAssertEqual(batch.items.first?.definitions.first?.defaultValue, "Default")
        let plain = TransferService.parse([(name: "File title.md", data: Data("# Heading\nText".utf8))])
        XCTAssertEqual(plain.items.first?.record.title, "File title")
        XCTAssertFalse(plain.items[0].hasIdentity)
    }

    @MainActor
    func testImportPreviewConflictsAndStaleLibraryProtection() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let prompt = Prompt(title: "Local", category: "AI", content: "Local body")
        context.insert(prompt); try context.save()
        let local = try BackupService.makeBackup(in: context)
        var incoming = local.prompts[0]; incoming.content = "Incoming"
        let batch = TransferBatch(items: [TransferItem(record: incoming, hasIdentity: true)])
        let keep = try TransferService.preview(batch, local: local, conflict: .keepLocal, validOnly: false, replace: false)
        XCTAssertEqual(keep.skipped, 1)
        XCTAssertEqual(keep.result.prompts.first?.content, "Local body")
        let copy = try TransferService.preview(batch, local: local, conflict: .copy, validOnly: false, replace: false)
        XCTAssertEqual(copy.added, 1); XCTAssertEqual(copy.result.prompts.count, 2)
        let update = try TransferService.preview(batch, local: local, conflict: .update, validOnly: false, replace: false)
        XCTAssertEqual(update.updated, 1)
        prompt.content = "Changed after preview"; try context.save()
        XCTAssertThrowsError(try TransferService.apply(update, in: context))
        XCTAssertEqual(prompt.content, "Changed after preview")
        XCTAssertThrowsError(try TransferService.preview(batch, local: local, conflict: .keepLocal, validOnly: false, replace: true))
    }

    @MainActor
    func testImportInvalidRowsRequireExplicitConsentAndNoIDDuplicatesSkip() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let local = try BackupService.makeBackup(in: container.mainContext)
        let csv = "title,content,category,tags,favorite\nValid,Body,AI,[],true\n,Invalid,AI,[],false\n"
        let batch = TransferService.parse([(name: "input.csv", data: Data(csv.utf8))])
        XCTAssertEqual(batch.items.count, 1); XCTAssertEqual(batch.errors.count, 1)
        XCTAssertThrowsError(try TransferService.preview(batch, local: local, conflict: .keepLocal, validOnly: false, replace: false))
        let preview = try TransferService.preview(batch, local: local, conflict: .keepLocal, validOnly: true, replace: false)
        let repeated = try TransferService.preview(batch, local: preview.result, conflict: .update, validOnly: true, replace: false)
        XCTAssertEqual(repeated.skipped, 1)
    }
}

extension PromptDockTests {
    func testSearchIncludesTagsWhileKeepingTitlePriority() {
        let tagged = Prompt(title: "Unrelated", category: "Writing", content: "Body")
        let title = Prompt(title: "Research", category: "Writing", content: "Body")
        let tag = PromptTag(name: "Research", promptIDs: [tagged.id])
        let results = PromptSearchService.results(in: [tagged, title], query: "research", locale: Locale(identifier: "en"), tags: [tag])
        XCTAssertEqual(results.map(\.id), [title.id, tagged.id])
    }

    @MainActor
    func testNewSearchSupersedesOlderResults() async {
        let controller = PromptSearchController()
        let first = Prompt(title: "First", category: "AI", content: "A")
        let second = Prompt(title: "Second", category: "AI", content: "B")
        let snapshots = PromptSearchService.snapshots([first, second], locale: Locale(identifier: "en"))
        let old = Task { await controller.search(.init(snapshots: snapshots, query: "First", localeIdentifier: "en")) }
        await Task.yield()
        await controller.search(.init(snapshots: snapshots, query: "Second", localeIdentifier: "en"))
        await old.value
        XCTAssertEqual(controller.ids, [second.id])
    }

    func testListPasteKeepsLinesAndRejectsOverLimit() throws {
        XCTAssertEqual(try PromptTemplate.pastedList("First\r\nSecond\n\n第三"), ["First", "Second", "第三"])
        XCTAssertEqual(try PromptTemplate.pastedList(Array(repeating: "Item", count: 100).joined(separator: "\n")).count, 100)
        XCTAssertThrowsError(try PromptTemplate.pastedList(Array(repeating: "Item", count: 101).joined(separator: "\n")))
    }

    func testSearchTenThousandLatencyAndHundredThousandStress() {
        func snapshots(_ count: Int) -> [PromptSearchSnapshot] {
            (0..<count).map { index in
                PromptSearchSnapshot(id: UUID(), title: "Prompt \(index)", category: "Coding", displayedCategory: "Coding", content: "Explain practical Swift examples and tests for item \(index).", isFavorite: false, updatedDate: Date(timeIntervalSince1970: Double(index)), tags: ["Development"])
            }
        }
        let everyday = snapshots(10_000)
        var durations: [Double] = []
        for _ in 0..<20 {
            let start = Date()
            let ids = PromptSearchService.search(.init(snapshots: everyday, query: "Swift", localeIdentifier: "en", limit: 12))
            durations.append(Date().timeIntervalSince(start) * 1000)
            XCTAssertEqual(ids.count, 12)
        }
        durations.sort()
        print("PromptDock search 10k P95 milliseconds: \(durations[18]); CI timing is observational, not fixed-machine acceptance.")
        XCTAssertEqual(PromptSearchService.search(.init(snapshots: snapshots(100_000), query: "Development", localeIdentifier: "en", limit: 12)).count, 12)
    }

    @MainActor
    func testV2StoreMigratesWithoutLosingPromptIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.store")
        let id = UUID()
        func writeV2() throws {
            let schema = Schema(versionedSchema: PromptDockSchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            container.mainContext.insert(Prompt(id: id, title: "Existing", category: "Coding", content: "Preserve {{name}}"))
            container.mainContext.insert(PromptTag(name: "Migrated", promptIDs: [id]))
            container.mainContext.insert(PromptVersion(promptID: id, title: "Before", category: "Coding", content: "History"))
            container.mainContext.insert(TemplateVariableDefinition(promptID: id, name: "name", defaultValue: "World"))
            container.mainContext.insert(SmartCollection(name: "Collection", favoriteOnly: true))
            try container.mainContext.save()
        }
        try writeV2()
        let upgraded = try DataService.makeModelContainer(storeURL: url)
        XCTAssertEqual(try upgraded.mainContext.fetch(FetchDescriptor<Prompt>()).first?.id, id)
        XCTAssertTrue(try upgraded.mainContext.fetch(FetchDescriptor<TrashEntry>()).isEmpty)
        XCTAssertEqual(try upgraded.mainContext.fetch(FetchDescriptor<PromptTag>()).first?.promptIDs, [id])
        XCTAssertEqual(try upgraded.mainContext.fetch(FetchDescriptor<PromptVersion>()).first?.content, "History")
        XCTAssertEqual(try upgraded.mainContext.fetch(FetchDescriptor<TemplateVariableDefinition>()).first?.defaultValue, "World")
        XCTAssertEqual(try upgraded.mainContext.fetch(FetchDescriptor<SmartCollection>()).first?.name, "Collection")
    }
}

extension PromptDockTests {
    @MainActor
    func testFailedImportRollsBackAllRecords() throws {
        struct SimulatedDiskFailure: Error {}
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let original = Prompt(title: "Original", category: "AI", content: "Preserve")
        context.insert(original)
        context.insert(PromptTag(name: "Original tag", promptIDs: [original.id]))
        try context.save()
        let before = try BackupService.makeBackup(in: context)
        var replacement = before
        replacement.prompts = [TransferService.record(title: "Replacement", content: "New", category: "Writing")]
        replacement.tags = []
        XCTAssertThrowsError(try BackupService.importBackup(replacement, mode: .replace, in: context, createsSafetyBackup: false, persist: { _ in throw SimulatedDiskFailure() }))
        let after = try BackupService.makeBackup(in: context)
        XCTAssertEqual(after.prompts, before.prompts)
        XCTAssertEqual(after.tags, before.tags)
    }

    func testStoredZIPCanBeReadBySystemUnzip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = directory.appendingPathComponent("export.zip")
        try StoredZIP.encode([("one.md", Data("中文\nContent".utf8)), ("two.md", Data("More".utf8))]).write(to: archive)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", archive.path]
        let output = Pipe(); process.standardOutput = output; process.standardError = output
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }
}

extension PromptDockTests {
    @MainActor
    func testJSONImportCanExplicitlyKeepValidRecordsAndPreservesTrash() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let local = try BackupService.makeBackup(in: container.mainContext)
        var incoming = local
        let good = TransferService.record(title: "Good", content: "Body", category: "AI")
        let bad = TransferService.record(title: "", content: "Invalid", category: "AI")
        incoming.prompts = [good, bad]
        incoming.trash = [.init(promptID: good.id, deletedAt: .now)]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let batch = TransferService.parse([(name: "mixed.json", data: try encoder.encode(incoming))])
        XCTAssertEqual(batch.items.count, 1)
        XCTAssertEqual(batch.errors.count, 1)
        XCTAssertNil(batch.completeBackup)
        let preview = try TransferService.preview(batch, local: local, conflict: .keepLocal, validOnly: true, replace: false)
        XCTAssertEqual(preview.result.trash.first?.promptID, good.id)
        XCTAssertEqual(preview.result.prompts.count, 1)
    }
}

extension PromptDockTests {
    func testPersistedDraftRecoversAndRejectsChangedOrDeletedRecord() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID(), revision = Date(timeIntervalSince1970: 1000)
        let saved = LocalEditorDraft(promptID: id, baselineDate: revision, draft: PromptDraft(title: "Unsaved", content: "Recover me"))
        try LocalDraftStore.save(saved, directory: directory)
        let recovered = try XCTUnwrap(LocalDraftStore.load(promptID: id, directory: directory))
        XCTAssertEqual(recovered.draft, saved.draft)
        XCTAssertNoThrow(try recovered.requireUnchanged(currentDate: revision, isDeleted: false))
        XCTAssertThrowsError(try recovered.requireUnchanged(currentDate: revision.addingTimeInterval(1), isDeleted: false))
        XCTAssertThrowsError(try recovered.requireUnchanged(currentDate: revision, isDeleted: true))
        XCTAssertNotNil(try LocalDraftStore.load(promptID: id, directory: directory), "Conflicted drafts remain recoverable")
        try LocalDraftStore.remove(promptID: id, directory: directory)
        XCTAssertNil(try LocalDraftStore.load(promptID: id, directory: directory))
    }
}

extension PromptDockTests {
    @MainActor
    func testSamplesAreStableAndDeletedSamplesAreNotRecreated() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let suite = "PromptDockTests.samples.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = try SampleLibrary.install(in: container.mainContext, defaults: defaults)
        XCTAssertEqual(first.count, 12)
        XCTAssertEqual(Set(SampleLibrary.batch().items.map { $0.record.id }), first)
        XCTAssertTrue(try SampleLibrary.install(in: container.mainContext, defaults: defaults).isEmpty)
        let prompt = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Prompt>()).first)
        let deletedID = prompt.id
        container.mainContext.delete(prompt)
        try container.mainContext.save()
        XCTAssertTrue(try SampleLibrary.install(in: container.mainContext, defaults: defaults).isEmpty)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<Prompt>()).contains { $0.id == deletedID })
    }

    @MainActor
    func testImportPreviewReportsOnlyAddedOrUpdatedIDs() throws {
        let container = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let local = try BackupService.makeBackup(in: container.mainContext)
        let batch = SampleLibrary.batch()
        let first = try TransferService.preview(batch, local: local, conflict: .keepLocal, validOnly: false, replace: false)
        XCTAssertEqual(first.changedIDs.count, 12)
        let second = try TransferService.preview(batch, local: first.result, conflict: .keepLocal, validOnly: false, replace: false)
        XCTAssertTrue(second.changedIDs.isEmpty)
        XCTAssertEqual(second.skipped, 12)
        let updated = try TransferService.preview(batch, local: first.result, conflict: .update, validOnly: false, replace: false)
        XCTAssertEqual(updated.changedIDs, first.changedIDs)
    }

    func testRecentUsagePersistsDeduplicatesAndCapsAt100() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecentUsageStore(fileURL: directory.appendingPathComponent("usage.json"))
        var entries: [RecentUsageStore.Entry] = []
        for i in 0..<110 { entries = RecentUsageStore.recording(UUID(), at: Date(timeIntervalSince1970: Double(i)), in: entries) }
        XCTAssertEqual(entries.count, 100)
        let id = entries[50].id
        entries = RecentUsageStore.recording(id, at: .now, in: entries)
        XCTAssertEqual(entries.first?.id, id)
        XCTAssertEqual(Set(entries.map(\.id)).count, 100)
        try store.record(id)
        try store.record(id)
        XCTAssertEqual(try store.load().map(\.id), [id])
    }

    func testRewriteRejectsRemovedRenamedAndRetypedVariables() throws {
        let request = AIRewriteRequest(content: "Hello {{name}}: {{tasks[]}}", definitions: [], goal: .concise, instructions: "", usesChinese: false)
        XCTAssertNoThrow(try request.validate("{{tasks[]}} for {{name}}"))
        XCTAssertThrowsError(try request.validate("Hello {{person}}: {{tasks[]}}"))
        XCTAssertThrowsError(try request.validate("Hello {{name}}: {{tasks}}"))
        XCTAssertThrowsError(try request.validate("Hello {{name}}"))
        XCTAssertThrowsError(try request.validate(""))
    }

    func testRewriteDiffPreservesBothSidesWithInsertedAndRemovedLines() {
        let old = "alpha\nbeta\ngamma", new = "intro\nalpha\ngamma\nend"
        let lines = RewriteDiffLine.compare(original: old, candidate: new)
        XCTAssertEqual(lines.filter { $0.kind != .added }.map(\.text).joined(separator: "\n"), old)
        XCTAssertEqual(lines.filter { $0.kind != .removed }.map(\.text).joined(separator: "\n"), new)
    }

    func testRewriteRequestContainsOnlyExplicitInput() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); AIStubURLProtocol.requestHandler = nil }
        let input = AIRewriteRequest(content: "Hello {{name}}", definitions: [.init(name: "name", label: "Recipient", defaultValue: "World", order: 0)], goal: .concise, instructions: "Keep polite", usesChinese: false)
        AIStubURLProtocol.requestHandler = { request in
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
            }
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
            XCTAssertEqual(messages.count, 1)
            XCTAssertEqual(messages.first?["content"], input.payload)
            let data = Data(#"{"choices":[{"message":{"content":"Welcome {{name}}"}}]}"#.utf8)
            return .init(statusCode: 200, data: data)
        }
        let result = try await AITemplateService(session: session).rewrite(input, configuration: .init(provider: .custom, baseURL: "https://example.test/v1", model: "test"), apiKey: nil)
        XCTAssertEqual(result.content, "Welcome {{name}}")
    }
}

extension PromptDockTests {
    @MainActor
    func testRecentUsageFiltersMissingIDsWithoutChangingUpdatedDates() {
        let first = Prompt(title: "First", category: "AI", content: "One")
        let second = Prompt(title: "Second", category: "AI", content: "Two")
        let originalDate = first.updatedDate
        let model = PromptViewModel()
        model.selectedSection = .recentlyUsed
        let found = model.filteredPrompts(from: [first, second], recentIDs: [second.id, UUID(), first.id])
        XCTAssertEqual(found.map(\.id), [second.id, first.id])
        XCTAssertEqual(first.updatedDate, originalDate)
        model.selectedSection = .trash
        XCTAssertTrue(model.filteredPrompts(from: [first, second]).isEmpty)
        XCTAssertTrue(PromptSection.librarySections.contains(.trash))
    }
}

extension PromptDockTests {
    @MainActor
    func testPermissionFailureDoesNotAutomaticallyRetry() async throws {
        var attempts = 0
        let controller = AppBootstrapController(modelContainerFactory: {
            attempts += 1
            throw CocoaError(.fileReadNoPermission)
        })
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(attempts, 1)
        guard case .failed = controller.state else { return XCTFail("Expected a stable failed state") }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(attempts, 1)
        controller.retry()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(attempts, 2)
    }

    func testRewritePreservesMixedVariableSyntaxAndExcludesUnrelatedDefinitions() {
        let input = AIRewriteRequest(content: "{{name}} and {{name[]}}", definitions: [.init(name: "unrelated", defaultValue: "SECRET OTHER PROMPT", order: 0)], goal: .concise, instructions: "", usesChinese: false)
        XCTAssertThrowsError(try input.validate("{{name[]}}"))
        XCTAssertFalse(input.payload.contains("SECRET OTHER PROMPT"))
    }
}

extension PromptDockTests {
    func testRewriteStreamSeparatesReasoningFromAdoptableText() throws {
        var parser = RewriteStreamAccumulator()
        try parser.consume(": keep-alive")
        try parser.consume(#"data: {"choices":[{"delta":{"reasoning_content":"检查约束"}}]}"#)
        try parser.consume(#"data: {"choices":[{"delta":{"content":"你好 {{name}}"}}]}"#)
        XCTAssertEqual(parser.progress.reasoning, "检查约束")
        XCTAssertThrowsError(try parser.result()) // Interrupted output cannot be adopted.
        try parser.consume(#"data: {"choices":[{"delta":{},"finish_reason":"stop"}]}"#)
        try parser.consume("data: [DONE]")
        XCTAssertEqual(try parser.result().content, "你好 {{name}}")
    }

    func testRewriteStreamRejectsTruncationErrorsAndReasoningOnly() throws {
        var parser = RewriteStreamAccumulator()
        XCTAssertThrowsError(try parser.consume(#"data: {"choices":[{"delta":{},"finish_reason":"length"}]}"#))
        XCTAssertThrowsError(try parser.consume(#"data: {"error":{"message":"failed"}}"#))
        XCTAssertThrowsError(try parser.consume("data: broken json"))
        try parser.consume(#"data: {"choices":[{"delta":{"reasoning_content":"thinking"}}]}"#)
        try parser.consume("data: [DONE]")
        XCTAssertThrowsError(try parser.result())
    }

    func testRewriteGoalsHaveDistinctEditingPolicies() {
        let policies = AIRewriteGoal.allCases.map {
            AIRewriteRequest(content: "Test {{feature}}", definitions: [], goal: $0, instructions: "", usesChinese: false).payload
        }
        XCTAssertEqual(Set(policies).count, AIRewriteGoal.allCases.count)
        XCTAssertTrue(policies.allSatisfy { $0.contains("not executing") && $0.contains("original language") })
    }
}

extension PromptDockTests {
    @MainActor
    func testDeepSeekStreamingRequestAndFinalResult() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIStubURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); AIStubURLProtocol.requestHandler = nil }
        AIStubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
            let events = """
            data: {"choices":[{"delta":{"reasoning_content":"Check variables"}}]}

            data: {"choices":[{"delta":{"content":"Hello {{name}}"}}]}

            data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

            data: [DONE]

            """
            return .init(statusCode: 200, data: Data(events.utf8))
        }
        var updates: [AIRewriteProgress] = []
        let input = AIRewriteRequest(content: "Hi {{name}}", definitions: [], goal: .tone, instructions: "", usesChinese: false)
        let result = try await AITemplateService(session: session).rewriteStreaming(input,
            configuration: .init(provider: .deepSeek, baseURL: "https://example.test", model: "test"),
            apiKey: "test-key", thinking: true) { updates.append($0) }
        XCTAssertEqual(result.content, "Hello {{name}}")
        XCTAssertEqual(updates.last?.reasoning, "Check variables")
        XCTAssertEqual(updates.last?.content, "Hello {{name}}")
    }
}

extension PromptDockTests {
    @MainActor
    func testSafetyBackupFailureNeverMutatesLibrary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let container = try DataService.makeModelContainer(storeURL: folder.appendingPathComponent("library.store"))
        let context = container.mainContext
        context.autosaveEnabled = false
        context.insert(Prompt(title: "Original", category: "AI", content: "Keep"))
        try context.save()
        let original = try BackupService.makeBackup(in: context)
        var replacement = original
        replacement.prompts = [TransferService.record(title: "Replacement", content: "New", category: "AI")]
        let blockedDirectory = folder.appendingPathComponent("not-a-directory")
        try Data().write(to: blockedDirectory)
        var didPersist = false
        XCTAssertThrowsError(try BackupService.importBackup(replacement, mode: .replace, in: context,
            createsSafetyBackup: true, safetyBackupDirectory: blockedDirectory, persist: { _ in didPersist = true }))
        XCTAssertFalse(didPersist)
        XCTAssertFalse(context.hasChanges)
        let independentContext = ModelContext(container)
        XCTAssertEqual(try BackupService.makeBackup(in: independentContext).prompts, original.prompts)
        XCTAssertThrowsError(try BackupService.importBackup(replacement, mode: .replace, in: context,
            createsSafetyBackup: true), "Tests must not implicitly write to Application Support")
    }

    @MainActor
    func testDiskReplacementSafetyBackupCanRestoreAllMetadata() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = folder.appendingPathComponent("library.store")
        func replaceLibrary() throws -> (PromptDockBackup, URL) {
            let container = try DataService.makeModelContainer(storeURL: store)
            let context = container.mainContext
            context.autosaveEnabled = false
            let prompt = Prompt(title: "Original", category: "AI", content: "\n{{name}} {{items[]}}\n", createdDate: Date(timeIntervalSince1970: 1_700_000_000), isFavorite: true)
            context.insert(prompt)
            context.insert(PromptTag(name: "Tag", color: .blue, promptIDs: [prompt.id], createdAt: Date(timeIntervalSince1970: 1_700_000_000)))
            context.insert(PromptVersion(promptID: prompt.id, title: "Before", category: "AI", content: "History", createdAt: Date(timeIntervalSince1970: 1_700_000_000)))
            context.insert(TemplateVariableDefinition(promptID: prompt.id, name: "name", label: "Name", defaultValue: "World"))
            context.insert(TemplateVariableDefinition(promptID: prompt.id, name: "items", order: 1, isRepeatable: true))
            context.insert(TrashEntry(promptID: prompt.id, deletedAt: Date(timeIntervalSince1970: 1_700_000_000)))
            context.insert(SmartCollection(name: "Favorites", favoriteOnly: true, createdAt: Date(timeIntervalSince1970: 1_700_000_000)))
            try context.save()
            let before = try BackupService.makeBackup(in: context)
            var replacement = before
            replacement.prompts = []; replacement.tags = []; replacement.versions = []
            replacement.variableDefinitions = []; replacement.trash = []; replacement.smartCollections = []
            let result = try BackupService.importBackup(replacement, mode: .replace, in: context,
                createsSafetyBackup: true, safetyBackupDirectory: folder.appendingPathComponent("backups"))
            XCTAssertTrue(try context.fetch(FetchDescriptor<Prompt>()).isEmpty)
            return (before, try XCTUnwrap(result.safetyBackupURL))
        }
        let (before, backupURL) = try replaceLibrary()
        let reopened = try DataService.makeModelContainer(storeURL: store)
        let decoded = try BackupService.decode(Data(contentsOf: backupURL))
        _ = try BackupService.importBackup(decoded, mode: .replace, in: reopened.mainContext, createsSafetyBackup: false)
        let recovered = try BackupService.makeBackup(in: ModelContext(reopened))
        XCTAssertEqual(recovered.prompts, before.prompts)
        XCTAssertEqual(recovered.tags, before.tags)
        XCTAssertEqual(recovered.versions, before.versions)
        XCTAssertEqual(recovered.variableDefinitions, before.variableDefinitions)
        XCTAssertEqual(recovered.trash, before.trash)
        XCTAssertEqual(recovered.smartCollections, before.smartCollections)
    }

    @MainActor
    func testAutomaticBackupCapturesCommittedStateBeforePendingEdit() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: folder); defaults.removePersistentDomain(forName: suite) }
        let container = try DataService.makeModelContainer(storeURL: folder.appendingPathComponent("library.store"))
        let context = container.mainContext
        context.autosaveEnabled = false
        let prompt = Prompt(title: "Original", category: "AI", content: "Saved content")
        context.insert(prompt)
        try context.save()
        prompt.content = "Unsaved edit"
        let directory = folder.appendingPathComponent("backups")
        let service = AutomaticBackupService(directory: directory, defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        service.beforeSave(container: container, now: date)
        XCTAssertNil(service.lastError)
        try context.save()
        service.beforeSave(container: container, now: date.addingTimeInterval(1))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        let backup = try BackupService.decode(Data(contentsOf: XCTUnwrap(files.first)))
        XCTAssertEqual(backup.prompts.first?.content, "Saved content")
        XCTAssertEqual(prompt.content, "Unsaved edit")
    }
}

extension PromptDockTests {
    @MainActor
    func testSearchPipelineIncludesSnapshotDebounceAndResultApplication() async {
        let prompts = (0..<10_000).map { index in
            Prompt(title: "Prompt \(index)", category: "Coding", content: "Explain Swift testing for item \(index)", createdDate: Date(timeIntervalSince1970: Double(index)))
        }
        let tags = [PromptTag(name: "Development", promptIDs: prompts.map(\.id))]
        let clock = ContinuousClock()
        for limit: Int? in [nil, 12] {
            let controller = PromptSearchController()
            var durations: [Double] = []
            for iteration in 0..<23 {
                let start = clock.now
                let input = PromptSearchInput(snapshots: PromptSearchService.snapshots(prompts, tags: tags, locale: Locale(identifier: "en")), query: iteration.isMultiple(of: 2) ? "Swift" : "Development", localeIdentifier: "en", limit: limit)
                await controller.search(input)
                let byID = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0) })
                let result = controller.ids.compactMap { byID[$0] }
                let elapsed = start.duration(to: clock.now).components
                if iteration >= 3 { durations.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15) }
                XCTAssertEqual(result.count, limit ?? prompts.count)
                XCTAssertEqual(controller.completedInput, input)
            }
            durations.sort()
            let report = "PromptDock synthetic pipeline limit=\(limit.map(String.init) ?? "all") samples=20 P95=\(durations[18])ms; includes snapshot/debounce/mapping, excludes SwiftUI rendering."
            print(report)
            let attachment = XCTAttachment(string: report)
            attachment.name = "Synthetic search pipeline - \(limit.map(String.init) ?? "all")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testCancelledHundredThousandSearchCannotPublishResults() async {
        let snapshots = (0..<100_000).map { index in
            PromptSearchSnapshot(id: UUID(), title: "Prompt \(index)", category: "Coding", displayedCategory: "Coding", content: "Swift", isFavorite: false, updatedDate: .distantPast, tags: [])
        }
        let controller = PromptSearchController()
        let input = PromptSearchInput(snapshots: snapshots, query: "Swift", localeIdentifier: "en", limit: 12)
        let task = Task { await controller.search(input) }
        task.cancel()
        await task.value
        XCTAssertNil(controller.completedInput)
        XCTAssertTrue(controller.ids.isEmpty)
        await controller.search(.init(snapshots: [], query: "Latest", localeIdentifier: "en"))
        XCTAssertEqual(controller.completedInput?.query, "Latest")
    }
}

extension PromptDockTests {
    @MainActor
    func testLegacyBackupFormatsRestoreIntoDiskLibrary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try DataService.makeModelContainer(isStoredInMemoryOnly: true)
        let prompt = Prompt(title: "Legacy", category: "AI", content: "Keep {{name}}", createdDate: Date(timeIntervalSince1970: 1_700_000_000))
        source.mainContext.insert(prompt)
        source.mainContext.insert(TemplateVariableDefinition(promptID: prompt.id, name: "name", defaultValue: "World"))
        try source.mainContext.save()
        let backup = try BackupService.makeBackup(in: source.mainContext)
        for version in [1, 2] {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: BackupService.encode(backup)) as? [String: Any])
            object["formatVersion"] = version
            object.removeValue(forKey: "trash")
            if version == 1 {
                for key in ["tags", "versions", "variableDefinitions", "smartCollections"] { object.removeValue(forKey: key) }
            }
            let decoded = try BackupService.decode(JSONSerialization.data(withJSONObject: object))
            let destination = try DataService.makeModelContainer(storeURL: folder.appendingPathComponent("v\(version).store"))
            _ = try BackupService.importBackup(decoded, mode: .replace, in: destination.mainContext, createsSafetyBackup: false)
            let restored = try BackupService.makeBackup(in: ModelContext(destination))
            XCTAssertEqual(restored.prompts, backup.prompts)
            XCTAssertEqual(restored.variableDefinitions.count, version == 2 ? 1 : 0)
            XCTAssertTrue(restored.trash.isEmpty)
        }
    }
}
