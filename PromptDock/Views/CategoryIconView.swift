import AppKit
import SwiftUI

struct CategoryIconView: View {
    let category: PromptCategory

    var body: some View {
        Group {
            switch category.iconKind {
            case .sfSymbol:
                Image(systemName: category.systemImage)
                    .foregroundStyle(.tint)
            case .emoji:
                Text(category.iconEmoji ?? "📁")
            case .localImage:
                if let data = category.iconImageData,
                   let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(.rect(cornerRadius: 4))
                } else {
                    Image(systemName: "folder")
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

struct CategoryIconPreview: View {
    let draft: CategoryIconDraft

    var body: some View {
        Group {
            switch draft.kind {
            case .sfSymbol:
                Image(systemName: "folder")
                    .foregroundStyle(.tint)
            case .emoji:
                Text(draft.emoji ?? "📁")
            case .localImage:
                if let data = draft.imageData,
                   let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 42, height: 42)
    }
}
