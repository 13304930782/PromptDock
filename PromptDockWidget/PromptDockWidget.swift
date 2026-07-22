import SwiftUI
import WidgetKit

struct PromptDockWidgetEntry: TimelineEntry {
    let date: Date
    let prompt: WidgetPromptSnapshot?
}

struct PromptDockWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptDockWidgetEntry {
        PromptDockWidgetEntry(
            date: .now,
            prompt: WidgetPromptSnapshot(
                id: UUID(),
                title: "Explain SwiftData",
                category: "Coding",
                content: "Explain SwiftData with a practical example.",
                updatedDate: .now,
                isFavorite: true
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PromptDockWidgetEntry) -> Void
    ) {
        completion(entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PromptDockWidgetEntry>) -> Void
    ) {
        let entry = entry()
        let refreshDate = Calendar.current.date(
            byAdding: .minute,
            value: 15,
            to: .now
        ) ?? .now.addingTimeInterval(900)

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func entry() -> PromptDockWidgetEntry {
        PromptDockWidgetEntry(
            date: .now,
            prompt: (try? WidgetSharedStore.load())?.first
        )
    }
}

struct PromptDockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale
    let entry: PromptDockWidgetEntry

    var body: some View {
        Group {
            if let prompt = entry.prompt {
                promptContent(prompt)
            } else {
                emptyContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func promptContent(
        _ prompt: WidgetPromptSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: prompt.isFavorite ? "star.fill" : "text.bubble")
                    .foregroundStyle(.tint)

                Text(
                    BuiltInCategoryPresentation.displayName(
                        for: prompt.category,
                        locale: locale
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(prompt.title)
                .font(.headline)
                .lineLimit(family == .systemSmall ? 2 : 1)

            Text(prompt.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 3 : 4)

            Spacer(minLength: 0)

            Button(
                "Copy",
                systemImage: "doc.on.doc",
                intent: CopyPromptIntent(promptContent: prompt.content)
            )
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label("No Prompts", systemImage: "text.bubble")
        } description: {
            Text("Open PromptDock and create a prompt to show it here.")
        }
        .padding()
    }
}

struct PromptDockWidget: Widget {
    let kind = WidgetSharedStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: PromptDockWidgetProvider()
        ) { entry in
            PromptDockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PromptDock Prompt")
        .description("Shows a recent or favorite prompt for quick copying.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
