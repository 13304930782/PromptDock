import AppKit
import Foundation

enum CategoryImageError: LocalizedError {
    case fileTooLarge
    case unreadableImage
    case unableToEncode

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            String(localized: "Choose an image smaller than 20 MB.")
        case .unreadableImage:
            String(localized: "PromptDock could not read this image.")
        case .unableToEncode:
            String(localized: "PromptDock could not prepare this image.")
        }
    }
}

enum CategoryImageProcessor {
    static let maximumSourceByteCount = 20 * 1_024 * 1_024
    static let outputPixelSize = 128

    static func process(_ data: Data) throws -> Data {
        guard data.count <= maximumSourceByteCount else {
            throw CategoryImageError.fileTooLarge
        }
        guard let image = NSImage(data: data),
              image.size.width > 0,
              image.size.height > 0
        else {
            throw CategoryImageError.unreadableImage
        }

        let size = outputPixelSize
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw CategoryImageError.unableToEncode
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            throw CategoryImageError.unableToEncode
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        let sourceSide = min(image.size.width, image.size.height)
        let sourceRect = NSRect(
            x: (image.size.width - sourceSide) / 2,
            y: (image.size.height - sourceSide) / 2,
            width: sourceSide,
            height: sourceSide
        )
        image.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(
            using: .png,
            properties: [:]
        ) else {
            throw CategoryImageError.unableToEncode
        }
        return pngData
    }
}
