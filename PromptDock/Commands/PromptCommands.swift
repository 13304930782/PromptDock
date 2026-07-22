import SwiftUI

struct PromptCommandActions {
    let selectedPromptTitle: String?
    let isSelectedPromptFavorite: Bool
    let createPrompt: () -> Void
    let copySelectedPrompt: () -> Void
    let editSelectedPrompt: () -> Void
    let toggleSelectedPromptFavorite: () -> Void
    let deleteSelectedPrompt: () -> Void

    var hasSelectedPrompt: Bool {
        selectedPromptTitle != nil
    }
}

private struct PromptCommandActionsKey: FocusedValueKey {
    typealias Value = PromptCommandActions
}

extension FocusedValues {
    var promptCommandActions: PromptCommandActions? {
        get { self[PromptCommandActionsKey.self] }
        set { self[PromptCommandActionsKey.self] = newValue }
    }
}

struct PromptCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppLanguage.storageKey)
    private var languageRawValue = AppLanguage.system.rawValue
    @FocusedValue(\.promptCommandActions)
    private var actions: PromptCommandActions?

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(language.text(english: "New Prompt", chinese: "新建提示词")) {
                actions?.createPrompt()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(actions == nil)

            Button(language.text(english: "New Window", chinese: "新建窗口")) {
                openWindow(id: "main")
            }
            .keyboardShortcut(
                "n",
                modifiers: [.command, .shift]
            )
        }

        CommandMenu(language.text(english: "Prompt", chinese: "提示词")) {
            Button(language.text(english: "Copy Prompt", chinese: "复制提示词")) {
                actions?.copySelectedPrompt()
            }
            .keyboardShortcut(
                "c",
                modifiers: [.command, .shift]
            )
            .disabled(actions?.hasSelectedPrompt != true)

            Button(language.text(english: "Edit Prompt", chinese: "编辑提示词")) {
                actions?.editSelectedPrompt()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(actions?.hasSelectedPrompt != true)

            Button(favoriteCommandTitle) {
                actions?.toggleSelectedPromptFavorite()
            }
            .keyboardShortcut(
                "f",
                modifiers: [.command, .shift]
            )
            .disabled(actions?.hasSelectedPrompt != true)

            Divider()

            Button(
                language.text(english: "Delete Prompt", chinese: "删除提示词"),
                role: .destructive
            ) {
                actions?.deleteSelectedPrompt()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(actions?.hasSelectedPrompt != true)
        }
    }

    private var favoriteCommandTitle: String {
        actions?.isSelectedPromptFavorite == true
            ? language.text(
                english: "Remove from Favorites",
                chinese: "取消收藏"
            )
            : language.text(
                english: "Add to Favorites",
                chinese: "添加到收藏"
            )
    }
}
