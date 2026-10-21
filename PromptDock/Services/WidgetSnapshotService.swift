import OSLog
import WidgetKit

@MainActor
enum WidgetSnapshotService {
    private(set) static var lastError: String?

    /// Called only from an explicit user retry action.
    static func retry(from prompts: [Prompt]) {
        lastError = nil
        refresh(from: prompts)
    }
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PromptDock",
        category: "WidgetSnapshot"
    )

    static func refresh(from prompts: [Prompt]) {
        guard !AppEnvironment.isTesting, lastError == nil else { return }
        let snapshots = prompts
            .sorted { first, second in
                if first.isFavorite != second.isFavorite {
                    return first.isFavorite
                }
                return first.updatedDate > second.updatedDate
            }
            .prefix(12)
            .map {
                WidgetPromptSnapshot(
                    id: $0.id,
                    title: $0.title,
                    category: $0.category,
                    content: $0.content,
                    updatedDate: $0.updatedDate,
                    isFavorite: $0.isFavorite
                )
            }

        do {
            try WidgetSharedStore.save(Array(snapshots))
            WidgetCenter.shared.reloadTimelines(
                ofKind: WidgetSharedStore.widgetKind
            )
        } catch {
            lastError = error.localizedDescription
            logger.error(
                "Unable to save widget snapshots: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
