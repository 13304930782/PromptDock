import Foundation
import SwiftData

struct TransferItem {
    var record: PromptDockBackup.PromptRecord
    var hasIdentity: Bool
    var tagNames: [String] = []
    var definitions: [PromptDockBackup.VariableDefinitionRecord] = []
    var versions: [PromptDockBackup.VersionRecord] = []
}

struct TransferBatch {
    var items: [TransferItem] = []
    var errors: [String] = []
    var completeBackup: PromptDockBackup?
}

enum TransferConflict: String, CaseIterable, Identifiable {
    case keepLocal = "Keep Local", update = "Update", copy = "Save Copy"
    var id: String { rawValue }
}

enum TransferError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

struct TransferPreview {
    var baseline: PromptDockBackup
    var result: PromptDockBackup
    var added: Int
    var updated: Int
    var skipped: Int
}

enum TransferService {
    static let csvHeader = ["title", "content", "category", "tags", "favorite"]
    private static let markdownPrefix = "<!-- PromptDock-v1 "

    static func parse(_ files: [(name: String, data: Data)]) -> TransferBatch {
        var batch = TransferBatch()
        var total = 0
        for file in files {
            total += file.data.count
            guard total <= BackupService.maximumBackupByteCount else {
                batch.errors.append("Total import exceeds 100 MB."); break
            }
            do {
                switch URL(fileURLWithPath: file.name).pathExtension.lowercased() {
                case "json":
                    let backup = try BackupService.decode(file.data)
                    if files.count == 1 && backup.kind == .full { batch.completeBackup = backup }
                    batch.items += backup.prompts.map { record in
                        TransferItem(record: record, hasIdentity: true,
                                     tagNames: backup.tags.filter { $0.promptIDs.contains(record.id) }.map(\.name),
                                     definitions: backup.variableDefinitions.filter { $0.promptID == record.id },
                                     versions: backup.versions.filter { $0.promptID == record.id })
                    }
                case "csv":
                    guard let text = String(data: file.data, encoding: .utf8) else { throw TransferError.invalid("CSV must be UTF-8.") }
                    let rows = try parseCSV(text)
                    guard rows.first == csvHeader else { throw TransferError.invalid("CSV header must be title,content,category,tags,favorite.") }
                    for (index, row) in rows.dropFirst().enumerated() {
                        do {
                            guard row.count == 5, ["true", "false"].contains(row[4].lowercased()) else { throw TransferError.invalid("Invalid CSV fields.") }
                            let tags = try JSONDecoder().decode([String].self, from: Data(row[3].utf8))
                            let item = TransferItem(record: record(title: row[0], content: row[1], category: row[2], favorite: row[4].lowercased() == "true"), hasIdentity: false, tagNames: tags)
                            try validate(item)
                            batch.items.append(item)
                        } catch { batch.errors.append("\(file.name): row \(index + 2): \(error.localizedDescription)") }
                    }
                case "md", "markdown", "txt":
                    guard var text = String(data: file.data, encoding: .utf8) else { throw TransferError.invalid("Markdown must be UTF-8.") }
                    if text.hasPrefix(markdownPrefix), let end = text.range(of: " -->\n") {
                        let metadata = String(text[text.index(text.startIndex, offsetBy: markdownPrefix.count)..<end.lowerBound])
                        guard let data = Data(base64Encoded: metadata) else { throw TransferError.invalid("Invalid Markdown metadata.") }
                        let backup = try BackupService.decode(data)
                        guard backup.prompts.count == 1 else { throw TransferError.invalid("Markdown metadata must contain one prompt.") }
                        text = String(text[end.upperBound...])
                        var prompt = backup.prompts[0]; prompt.content = text
                        batch.items.append(TransferItem(record: prompt, hasIdentity: true, tagNames: backup.tags.map(\.name), definitions: backup.variableDefinitions))
                    } else {
                        batch.items.append(TransferItem(record: record(title: URL(fileURLWithPath: file.name).deletingPathExtension().lastPathComponent, content: text, category: "Uncategorized"), hasIdentity: false))
                    }
                default: throw TransferError.invalid("Unsupported file format.")
                }
            } catch { batch.errors.append("\(file.name): \(error.localizedDescription)") }
        }
        var valid: [TransferItem] = []
        for item in batch.items {
            do { try validate(item); valid.append(item) }
            catch { batch.errors.append("\(item.record.title): \(error.localizedDescription)") }
        }
        batch.items = valid
        if !batch.errors.isEmpty { batch.completeBackup = nil }
        return batch
    }

    static func record(title: String, content: String, category: String, favorite: Bool = false) -> PromptDockBackup.PromptRecord {
        .init(id: UUID(), title: title, category: category, content: content, createdDate: .now, updatedDate: .now, isFavorite: favorite)
    }

    static func validate(_ item: TransferItem) throws {
        guard !item.record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !item.record.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !item.record.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransferError.invalid("Title, content and category are required.")
        }
    }

    static func preview(_ batch: TransferBatch, local: PromptDockBackup, conflict: TransferConflict, validOnly: Bool, replace: Bool) throws -> TransferPreview {
        guard batch.errors.isEmpty || validOnly else { throw TransferError.invalid("Resolve invalid records or explicitly choose valid items only.") }
        if replace {
            guard let full = batch.completeBackup else { throw TransferError.invalid("Only one complete JSON backup can replace the library.") }
            return TransferPreview(baseline: local, result: full, added: full.prompts.count, updated: 0, skipped: 0)
        }
        var result = local
        var added = 0, updated = 0, skipped = 0
        for item in batch.items {
            var record = item.record
            if !item.hasIdentity && result.prompts.contains(where: { $0.title == record.title && $0.content == record.content }) {
                skipped += 1; continue
            }
            if let index = result.prompts.firstIndex(where: { $0.id == record.id }) {
                switch conflict {
                case .keepLocal: skipped += 1; continue
                case .copy: record.id = UUID()
                case .update:
                    result.prompts.remove(at: index)
                    result.variableDefinitions.removeAll { $0.promptID == record.id }
                    result.versions.removeAll { $0.promptID == record.id }
                    result.trash.removeAll { $0.promptID == record.id }
                    for index in result.tags.indices { result.tags[index].promptIDs.removeAll { $0 == record.id } }
                    updated += 1
                }
            } else { added += 1 }
            if record.id != item.record.id { added += 1 }
            let categoryKey = CategoryNameIdentity.normalized(record.category)
            if let category = result.categories.first(where: { CategoryNameIdentity.normalized($0.name) == categoryKey }) {
                record.category = category.name
            } else {
                result.categories.append(.init(id: UUID(), name: record.category, systemImage: "folder", sortOrder: result.categories.count, createdDate: .now, isBuiltIn: false, iconKind: .sfSymbol, iconEmoji: nil, iconImageData: nil))
            }
            result.prompts.append(record)
            for name in item.tagNames {
                let key = CategoryNameIdentity.normalized(name)
                if let index = result.tags.firstIndex(where: { CategoryNameIdentity.normalized($0.name) == key }) {
                    if !result.tags[index].promptIDs.contains(record.id) { result.tags[index].promptIDs.append(record.id) }
                } else {
                    result.tags.append(.init(id: UUID(), name: name, color: .gray, promptIDs: [record.id], createdAt: .now))
                }
            }
            result.variableDefinitions += item.definitions.map { original in
                var copy = original; copy.promptID = record.id
                if result.variableDefinitions.contains(where: { $0.id == copy.id }) || record.id != item.record.id { copy.id = UUID() }
                return copy
            }
            result.versions += item.versions.map { original in
                var copy = original; copy.promptID = record.id
                if result.versions.contains(where: { $0.id == copy.id }) || record.id != item.record.id { copy.id = UUID() }
                return copy
            }
        }
        try BackupService.validate(result)
        return TransferPreview(baseline: local, result: result, added: added, updated: updated, skipped: skipped)
    }

    @MainActor
    static func apply(_ preview: TransferPreview, in context: ModelContext) throws {
        var current = try BackupService.makeBackup(in: context)
        current.createdAt = preview.baseline.createdAt
        // Fetch ordering for related entities is not guaranteed; compare canonical encodings.
        guard canonical(current) == canonical(preview.baseline) else { throw TransferError.invalid("The library changed after preview. Preview again before importing.") }
        _ = try BackupService.importBackup(preview.result, mode: .replace, in: context)
    }

    static func canonical(_ backup: PromptDockBackup) -> PromptDockBackup {
        var copy = backup
        copy.prompts.sort { $0.id.uuidString < $1.id.uuidString }
        copy.categories.sort { $0.id.uuidString < $1.id.uuidString }
        copy.tags.sort { $0.id.uuidString < $1.id.uuidString }
        copy.versions.sort { $0.id.uuidString < $1.id.uuidString }
        copy.variableDefinitions.sort { $0.id.uuidString < $1.id.uuidString }
        copy.smartCollections.sort { $0.id.uuidString < $1.id.uuidString }
        copy.trash.sort { $0.promptID.uuidString < $1.promptID.uuidString }
        return copy
    }

    static func subset(_ backup: PromptDockBackup, ids: Set<UUID>) -> PromptDockBackup {
        var copy = backup; copy.kind = .content
        copy.prompts.removeAll { !ids.contains($0.id) }
        let names = Set(copy.prompts.map { CategoryNameIdentity.normalized($0.category) })
        copy.categories.removeAll { !names.contains(CategoryNameIdentity.normalized($0.name)) }
        copy.tags = copy.tags.compactMap { tag in
            var tag = tag; tag.promptIDs = tag.promptIDs.filter(ids.contains)
            return tag.promptIDs.isEmpty ? nil : tag
        }
        copy.versions.removeAll { !ids.contains($0.promptID) }
        copy.variableDefinitions.removeAll { !ids.contains($0.promptID) }
        copy.trash.removeAll { !ids.contains($0.promptID) }
        copy.smartCollections = []
        return copy
    }

    static func csv(_ backup: PromptDockBackup) throws -> Data {
        let rows = [csvHeader] + (try backup.prompts.map { prompt in
            [prompt.title, prompt.content, prompt.category,
             String(decoding: try JSONEncoder().encode(backup.tags.filter { $0.promptIDs.contains(prompt.id) }.map(\.name)), as: UTF8.self),
             prompt.isFavorite ? "true" : "false"]
        })
        return Data(rows.map { row in row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }.joined(separator: "\r\n").utf8)
    }

    static func markdownFiles(_ backup: PromptDockBackup) throws -> [(String, Data)] {
        try backup.prompts.map { prompt in
            var metadata = subset(backup, ids: [prompt.id]); metadata.versions = []; metadata.trash = []
            let header = try BackupService.encode(metadata).base64EncodedString()
            return (prompt.id.uuidString + ".md", Data((markdownPrefix + header + " -->\n" + prompt.content).utf8))
        }
    }

    static func parseCSV(_ proposed: String) throws -> [[String]] {
        let text = proposed.hasPrefix("\u{feff}") ? String(proposed.dropFirst()) : proposed
        var rows: [[String]] = [], row: [String] = [], value = ""
        let chars = Array(text); var index = 0; var quoted = false; var closed = false
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { value.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { value.append(char) }
            } else if char == "," {
                row.append(value); value = ""; closed = false
            } else if char == "\n" || char == "\r" || char == "\r\n" {
                row.append(value); rows.append(row); row = []; value = ""; closed = false
                if char == "\r" && index + 1 < chars.count && chars[index + 1] == "\n" { index += 1 }
            } else if char == "\"" && value.isEmpty && !closed { quoted = true }
            else {
                guard !closed && char != "\"" else { throw TransferError.invalid("Malformed CSV quoting.") }
                value.append(char)
            }
            index += 1
        }
        guard !quoted else { throw TransferError.invalid("Unclosed CSV quote.") }
        if !value.isEmpty || !row.isEmpty || closed { row.append(value); rows.append(row) }
        return rows
    }
}

/// Uncompressed ZIP, UTF-8 names; no shell, external executable or new dependency.
enum StoredZIP {
    static func encode(_ files: [(String, Data)]) throws -> Data {
        guard files.count <= 65535 else { throw TransferError.invalid("ZIP supports up to 65,535 Markdown files. Export smaller batches.") }
        var output = Data(), central = Data()
        func u16(_ value: UInt16) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
        func u32(_ value: UInt32) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
        for (name, data) in files {
            let nameData = Data(name.utf8)
            guard data.count <= Int(UInt32.max), output.count <= Int(UInt32.max), nameData.count <= 65535 else { throw TransferError.invalid("ZIP is too large.") }
            var crc: UInt32 = 0xffffffff
            for byte in data { crc ^= UInt32(byte); for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0) } }
            crc ^= 0xffffffff
            let offset = UInt32(output.count), size = UInt32(data.count)
            let common = u16(20) + u16(0x800) + u16(0) + u16(0) + u16(0x21) + u32(crc) + u32(size) + u32(size) + u16(UInt16(nameData.count)) + u16(0)
            output += u32(0x04034b50) + common + nameData + data
            central += u32(0x02014b50) + u16(20) + common + u16(0) + u16(0) + u16(0) + u32(0) + u32(offset) + nameData
        }
        let offset = UInt32(output.count), size = UInt32(central.count)
        output += central
        output += u32(0x06054b50) + u16(0) + u16(0) + u16(UInt16(files.count)) + u16(UInt16(files.count)) + u32(size) + u32(offset) + u16(0)
        return output
    }
}
