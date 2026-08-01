import SwiftUI
import WidgetKit

struct PromptDockWidgetEntry: TimelineEntry {
    let date: Date
    let prompts: [WidgetPromptSnapshot]
}

struct PromptDockWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptDockWidgetEntry {
        PromptDockWidgetEntry(
            date: .now,
            prompts: [
                WidgetPromptSnapshot(
                    id: UUID(),
                    title: "Explain SwiftData",
                    category: "Coding",
                    content: "Explain SwiftData with a practical example.",
                    updatedDate: .now,
                    isFavorite: true
                ),
                WidgetPromptSnapshot(
                    id: UUID(),
                    title: "Review this code",
                    category: "AI",
                    content: "Review this code for correctness and clarity.",
                    updatedDate: .now,
                    isFavorite: false
                )
            ]
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
            prompts: Array((try? WidgetSharedStore.load())?.prefix(2) ?? [])
        )
    }
}

struct PromptDockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale
    let entry: PromptDockWidgetEntry

    var body: some View {
        Group {
            if entry.prompts.isEmpty {
                emptyContent
            } else {
                promptContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var promptContent: some View {
        if family == .systemMedium {
            HStack(spacing: 0) {
                ForEach(Array(entry.prompts.prefix(2).enumerated()), id: \.element.id) { index, prompt in
                    if index > 0 {
                        Divider()
                    }

                    promptCard(prompt, isSmall: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else if let prompt = entry.prompts.first {
            promptCard(prompt, isSmall: true)
        }
    }

    private func promptCard(
        _ prompt: WidgetPromptSnapshot,
        isSmall: Bool
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
                .lineLimit(isSmall ? 2 : 1)

            Text(prompt.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(isSmall ? 3 : 2)

            Spacer(minLength: 0)

            if PromptTemplate(prompt.content).hasVariables {
                Button(
                    "Copy Template",
                    systemImage: "curlybraces",
                    intent: CopyPromptIntent(promptContent: prompt.content)
                )
                .buttonStyle(.bordered)
            } else {
                Button(
                    "Copy",
                    systemImage: "doc.on.doc",
                    intent: CopyPromptIntent(promptContent: prompt.content)
                )
                .buttonStyle(.bordered)
            }
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
