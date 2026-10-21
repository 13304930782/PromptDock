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

    @Parameter(title: "Prompt ID")
    var promptID: String?

    init() {
        promptContent = ""
    }

    init(promptContent: String, promptID: UUID) {
        self.promptID = promptID.uuidString
        self.promptContent = promptContent
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(promptContent, forType: .string) else {
            return .result(dialog: "Unable to copy")
        }
        if let promptID, let id = UUID(uuidString: promptID) { RecentUsage.record(id) }

        if PromptTemplate(promptContent).hasVariables {
            return .result(
                dialog: "Template copied. Replace its variables before use."
            )
        }

        return .result(dialog: "Copied")
    }
}
