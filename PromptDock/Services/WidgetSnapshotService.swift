import WidgetKit

enum WidgetSnapshotService {
    static func refresh(from prompts: [Prompt]) {
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

        try? WidgetSharedStore.save(Array(snapshots))
        WidgetCenter.shared.reloadTimelines(
            ofKind: WidgetSharedStore.widgetKind
        )
    }
}
