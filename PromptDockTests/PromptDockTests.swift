import XCTest
import SwiftData
import AppKit
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

    func testWidgetSnapshotsRoundTripThroughSharedStore() throws {
        let suiteName = "PromptDockTests.Widget.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create test UserDefaults suite")
            return
        }

        let snapshot = WidgetPromptSnapshot(
            id: UUID(),
            title: "Widget Prompt",
            category: "AI",
            content: "Summarize this document.",
            updatedDate: .now,
            isFavorite: true
        )

        try WidgetSharedStore.save([snapshot], to: defaults)
        XCTAssertEqual(
            WidgetSharedStore.load(from: defaults),
            [snapshot]
        )

        defaults.removePersistentDomain(forName: suiteName)
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
                    category: "Coding",
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
            categories: []
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
}
