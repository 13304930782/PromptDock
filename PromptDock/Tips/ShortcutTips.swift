import AppKit
import SwiftUI

enum LearnableShortcut: String, Identifiable {
    case copyPrompt
    case nextSearchResult
    case previousSearchResult

    var id: String { rawValue }
}

enum ShortcutLearningStorage {
    static let copyPrompt = "shortcutLearning.copyPrompt"
    static let nextSearchResult = "shortcutLearning.nextSearchResult"
    static let previousSearchResult = "shortcutLearning.previousSearchResult"
}

struct ShortcutGuideItem: Identifiable {
    let shortcut: LearnableShortcut
    let title: String
    let keys: String
    let isCompleted: Bool

    var id: LearnableShortcut { shortcut }
}

struct ShortcutGuidePopover: View {
    let title: String
    let message: String
    let items: [ShortcutGuideItem]

    private var completedCount: Int {
        items.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(
                    systemName: completedCount == items.count
                        ? "checkmark.circle.fill"
                        : "keyboard"
                )
                .font(.title2)
                .foregroundStyle(
                    completedCount == items.count
                        ? Color.green
                        : Color.accentColor
                )
            }

            Divider()

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(
                        systemName: item.isCompleted
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(
                        item.isCompleted ? .green : .secondary
                    )
                    .contentTransition(.symbolEffect(.replace))

                    Text(item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.keys)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .frame(width: 330)
        .animation(.snappy, value: completedCount)
    }
}

struct ShortcutSuccessBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct ShortcutKeyMonitor: NSViewRepresentable {
    let onShortcut: (LearnableShortcut) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onShortcut: onShortcut)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onShortcut = onShortcut
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onShortcut: (LearnableShortcut) -> Void
        private var eventMonitor: Any?

        init(onShortcut: @escaping (LearnableShortcut) -> Void) {
            self.onShortcut = onShortcut
        }

        func start() {
            guard eventMonitor == nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown
            ) { [weak self] event in
                self?.recognize(event)
                return event
            }
        }

        func stop() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
            eventMonitor = nil
        }

        private func recognize(_ event: NSEvent) {
            guard !event.isARepeat,
                  let key = event.charactersIgnoringModifiers?.lowercased()
            else { return }

            let modifiers = event.modifierFlags.intersection([
                .command,
                .shift,
                .option,
                .control
            ])

            switch (key, modifiers) {
            case ("c", [.command, .shift]):
                onShortcut(.copyPrompt)
            case ("g", [.command]):
                onShortcut(.nextSearchResult)
            case ("g", [.command, .shift]):
                onShortcut(.previousSearchResult)
            default:
                break
            }
        }
    }
}
