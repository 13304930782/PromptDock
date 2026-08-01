import AppKit
import SwiftUI

struct StartupFailureView: View {
    let failure: AppBootstrapFailure
    let onRetry: () -> Void

    private var dataDirectoryURL: URL? {
        DataService.dataDirectoryURLIfAvailable()
    }

    var body: some View {
        ContentUnavailableView {
            Label(
                "PromptDock Could Not Open Its Library",
                systemImage: "externaldrive.badge.exclamationmark"
            )
        } description: {
            Text(
                "Your existing data was not changed. Retry, or copy the details if you need help."
            )
        } actions: {
            VStack(spacing: 10) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)

                HStack {
                    Button("Copy Error Details", action: copyDetails)
                    Button("Show Data Folder in Finder", action: revealDataFolder)
                        .disabled(dataDirectoryURL == nil)
                    Button("Quit PromptDock") { NSApp.terminate(nil) }
                }

                Text(failure.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: 540)
            }
        }
        .padding(32)
    }

    private func copyDetails() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            failure.diagnosticDetails,
            forType: .string
        )
    }

    private func revealDataFolder() {
        guard let dataDirectoryURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([dataDirectoryURL])
    }
}
