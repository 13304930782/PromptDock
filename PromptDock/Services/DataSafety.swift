import Foundation

enum CategoryNameIdentity {
    private static let stableLocale = Locale(identifier: "en_US_POSIX")

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalized(_ value: String) -> String {
        trimmed(value).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: stableLocale
        )
    }
}

enum BoundedFileReaderError: LocalizedError, Equatable {
    case fileTooLarge(maximumByteCount: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maximumByteCount):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return String(
                localized: "The selected file is larger than \(formatter.string(fromByteCount: Int64(maximumByteCount)))."
            )
        }
    }
}

enum BoundedFileReader {
    private static let chunkByteCount = 64 * 1_024

    static func read(
        url: URL,
        maximumByteCount: Int
    ) throws -> Data {
        precondition(maximumByteCount >= 0)

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        return try read(
            fileHandle: handle,
            maximumByteCount: maximumByteCount
        )
    }

    static func read(
        fileHandle: FileHandle,
        maximumByteCount: Int
    ) throws -> Data {
        precondition(maximumByteCount >= 0)

        var result = Data()
        result.reserveCapacity(min(maximumByteCount, chunkByteCount))

        while result.count <= maximumByteCount {
            let remaining = maximumByteCount - result.count + 1
            let requestedCount = min(chunkByteCount, remaining)
            guard let chunk = try fileHandle.read(upToCount: requestedCount),
                  !chunk.isEmpty
            else {
                return result
            }
            result.append(chunk)
        }

        throw BoundedFileReaderError.fileTooLarge(
            maximumByteCount: maximumByteCount
        )
    }
}
