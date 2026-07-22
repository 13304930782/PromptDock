import AppIntents
import AppKit

struct CopyPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Prompt"
    static var description = IntentDescription(
        "Copies a PromptDock prompt to the clipboard."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Prompt Content")
    var promptContent: String

    init() {
        promptContent = ""
    }

    init(promptContent: String) {
        self.promptContent = promptContent
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(promptContent, forType: .string)
        return .result(dialog: "Copied")
    }
}
