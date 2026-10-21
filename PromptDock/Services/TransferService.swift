import Foundation
import SwiftData

struct TransferItem {
    var record: PromptDockBackup.PromptRecord
    var hasIdentity: Bool
    var sourceName: String = ""
    var deletedAt: Date? = nil
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
    var changedIDs: Set<UUID> = []
}

enum TransferService {
    static let csvHeader = ["title", "content", "category", "tags", "favorite"]
    private static let markdownPrefix = "<!-- PromptDock-v1 "

    static func parse(_ files: [(name: String, data: Data)]) -> TransferBatch {
        var batch = TransferBatch()
        var total = 0
        for file in files {
            let firstItem = batch.items.count
            defer {
                for index in firstItem..<batch.items.count { batch.items[index].sourceName = file.name }
            }
            total += file.data.count
            guard total <= BackupService.maximumBackupByteCount else {
                batch.errors.append("Total import exceeds 100 MB."); break
            }
            do {
                switch URL(fileURLWithPath: file.name).pathExtension.lowercased() {
                case "json":
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970
                    let backup = try decoder.decode(PromptDockBackup.self, from: file.data)
                    var fullyValid = true
                    do { try BackupService.validate(backup) }
                    catch BackupError.invalidPrompt {
                        guard backup.prompts.contains(where: { (try? validate(TransferItem(record: $0, hasIdentity: true))) == nil }) else { throw BackupError.invalidPrompt }
                        fullyValid = false
                    }

                    if files.count == 1 && backup.kind == .full && fullyValid { batch.completeBackup = backup }
                    batch.items += backup.prompts.map { record in
                        TransferItem(record: record, hasIdentity: true, deletedAt: backup.trash.first(where: { $0.promptID == record.id })?.deletedAt,
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
            catch { batch.errors.append("\(item.sourceName): \(item.record.title): \(error.localizedDescription)") }
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
            return TransferPreview(baseline: local, result: full, added: full.prompts.count, updated: 0, skipped: 0, changedIDs: Set(full.prompts.map(\.id)))
        }
        var result = local
        var added = 0, updated = 0, skipped = 0
        var changedIDs: Set<UUID> = []
        var records = Dictionary(uniqueKeysWithValues: local.prompts.map { ($0.id, $0) })
        var contentCounts: [[String]: Int] = [:]
        for record in local.prompts { contentCounts[[record.title, record.content], default: 0] += 1 }
        var categoryNames = Dictionary(local.categories.map { (CategoryNameIdentity.normalized($0.name), $0.name) }, uniquingKeysWith: { first, _ in first })
        for item in batch.items {
            var record = item.record
            if !item.hasIdentity && contentCounts[[record.title, record.content], default: 0] > 0 {
                skipped += 1; continue
            }
            if let existing = records[record.id] {
                switch conflict {
                case .keepLocal: skipped += 1; continue
                case .copy: record.id = UUID()
                case .update:
                    contentCounts[[existing.title, existing.content], default: 0] -= 1
                    result.variableDefinitions.removeAll { $0.promptID == record.id }
                    result.versions.removeAll { $0.promptID == record.id }
                    result.trash.removeAll { $0.promptID == record.id }
                    for index in result.tags.indices { result.tags[index].promptIDs.removeAll { $0 == record.id } }
                    updated += 1
                }
            } else { added += 1 }
            if record.id != item.record.id { added += 1 }
            let categoryKey = CategoryNameIdentity.normalized(record.category)
            if let category = categoryNames[categoryKey] {
                record.category = category
            } else {
                categoryNames[categoryKey] = record.category
                result.categories.append(.init(id: UUID(), name: record.category, systemImage: "folder", sortOrder: result.categories.count, createdDate: .now, isBuiltIn: false, iconKind: .sfSymbol, iconEmoji: nil, iconImageData: nil))
            }
            changedIDs.insert(record.id)
            records[record.id] = record
            contentCounts[[record.title, record.content], default: 0] += 1
            if let deletedAt = item.deletedAt {
                result.trash.append(.init(promptID: record.id, deletedAt: deletedAt))
            }
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
        result.prompts = records.values.sorted { $0.id.uuidString < $1.id.uuidString }
        try BackupService.validate(result)
        return TransferPreview(baseline: local, result: result, added: added, updated: updated, skipped: skipped, changedIDs: changedIDs)
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
            var common = Data()
            let fields: [Data] = [u16(20), u16(0x800), u16(0), u16(0), u16(0x21), u32(crc), u32(size), u32(size), u16(UInt16(nameData.count)), u16(0)]
            for field in fields { common.append(field) }
            for field in [u32(0x04034b50), common, nameData, data] { output.append(field) }
            let centralFields: [Data] = [u32(0x02014b50), u16(20), common, u16(0), u16(0), u16(0), u32(0), u32(offset), nameData]
            for field in centralFields { central.append(field) }
        }
        let offset = UInt32(output.count), size = UInt32(central.count)
        output.append(central)
        let endFields: [Data] = [u32(0x06054b50), u16(0), u16(0), u16(UInt16(files.count)), u16(UInt16(files.count)), u32(size), u32(offset), u16(0)]
        for field in endFields { output.append(field) }
        return output
    }
}


/// Explicitly installed content, never loaded during application bootstrap.
enum SampleLibrary {
    static let receiptKey = "sampleLibrary.installedIDs.v1"
    static func batch(excluding installedIDs: Set<UUID> = []) -> TransferBatch {
        var result = TransferService.parse([(name: "Samples.json", data: Data(json.utf8))])
        result.items.removeAll { installedIDs.contains($0.record.id) }
        return result
    }
    @MainActor
    static func install(in context: ModelContext, defaults: UserDefaults) throws -> Set<UUID> {
        let installed = Set((defaults.stringArray(forKey: receiptKey) ?? []).compactMap(UUID.init(uuidString:)))
        let input = batch(excluding: installed)
        let preview = try TransferService.preview(input, local: BackupService.makeBackup(in: context), conflict: .keepLocal, validOnly: false, replace: false)
        try TransferService.apply(preview, in: context)
        defaults.set(Array(installed.union(input.items.map { $0.record.id })).map(\.uuidString), forKey: receiptKey)
        return preview.changedIDs
    }
    private static let json = #"""
{
  "kind": "content",
  "formatVersion": 3,
  "createdAt": 1792604960.929135,
  "appVersion": "1.2.0",
  "prompts": [
    {
      "id": "11E38BAA-5CFE-4E38-800F-82BEA7D57F10",
      "title": "SwiftUI 页面设计",
      "category": "iOS 开发",
      "content": "请设计一个{{页面名称}}的 SwiftUI 页面，面向{{用户群体}}。说明状态管理、布局和无障碍支持。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": true
    },
    {
      "id": "ACEA6DC4-8DED-4CC1-84FF-786C48FCEFAC",
      "title": "Swift 代码审查",
      "category": "iOS 开发",
      "content": "请审查以下 Swift 代码，重点检查并发安全、内存管理与错误处理：\n{{代码}}",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "33110B94-B81E-4D0E-9D47-47BF60DA5033",
      "title": "iOS 功能拆解",
      "category": "iOS 开发",
      "content": "把{{功能描述}}拆成可独立验收的开发任务，列出界面、数据模型、测试和风险。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "2CA70E58-0814-4338-99C6-66FB47BED7C1",
      "title": "单元测试设计",
      "category": "iOS 开发",
      "content": "针对{{功能}}设计正常、边界和失败场景的单元测试，使用 Swift Testing 给出示例。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "5DE25D56-43E3-418D-A40B-B7444EE1E8F1",
      "title": "文章大纲",
      "category": "内容创作",
      "content": "请围绕{{主题}}为{{读者}}写一份文章大纲，包含开头、三个核心论点与结尾。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "C487B9C0-BC72-47B2-9BC7-55766A3BEB62",
      "title": "文案润色",
      "category": "内容创作",
      "content": "润色以下文字，语气自然简洁，保留事实，不添加未经确认的信息：\n{{原文}}",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "D9986FF6-201E-4B89-80C2-7BE58ABD5FE8",
      "title": "中英翻译",
      "category": "内容创作",
      "content": "将下面文字翻译为{{目标语言}}，保留格式与专业术语：\n{{原文}}",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "40CB3992-732A-46BE-A212-36B2B20B8494",
      "title": "会议纪要",
      "category": "工作效率",
      "content": "整理以下会议记录，输出结论、待办、负责人和截止时间。缺失信息标记为待确认：\n{{会议记录}}",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": true
    },
    {
      "id": "49E25989-72F2-494D-BC7C-C70ECCE4B157",
      "title": "每周复盘",
      "category": "工作效率",
      "content": "根据本周记录{{本周记录}}，归纳成果、阻碍、经验和下周三项优先事项。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "400DA8B3-4E6D-4DCD-95FD-C0A007452886",
      "title": "学习计划",
      "category": "学习成长",
      "content": "为{{学习主题}}制定{{天数}}天入门计划，每天可投入{{每日时间}}，包含练习和验收标准。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": true
    },
    {
      "id": "BCC15FF4-CBFB-484B-B535-C6F9B1BBFEA8",
      "title": "概念讲解",
      "category": "学习成长",
      "content": "用一个日常例子解释{{概念}}，再提供准确的技术定义和一道自测题。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    },
    {
      "id": "7949E5DF-69E3-425D-BD34-D2EC26B08294",
      "title": "产品需求梳理",
      "category": "产品设计",
      "content": "将{{需求描述}}整理成用户问题、使用流程、边界情况和验收标准，明确哪些假设还需验证。",
      "createdDate": 1792604960.929135,
      "updatedDate": 1792604960.929135,
      "isFavorite": false
    }
  ],
  "categories": [
    {
      "id": "9B208924-1EE3-4787-AEFE-60E8208DBE7D",
      "name": "iOS 开发",
      "systemImage": "folder",
      "sortOrder": 0,
      "createdDate": 1792604960.929135,
      "isBuiltIn": false,
      "iconKind": "sfSymbol"
    },
    {
      "id": "0C45F138-C053-473B-A397-D89C28331D0C",
      "name": "内容创作",
      "systemImage": "folder",
      "sortOrder": 1,
      "createdDate": 1792604960.929135,
      "isBuiltIn": false,
      "iconKind": "sfSymbol"
    },
    {
      "id": "0443DAB4-0C59-4FA9-9839-FD64658B62FC",
      "name": "工作效率",
      "systemImage": "folder",
      "sortOrder": 2,
      "createdDate": 1792604960.929135,
      "isBuiltIn": false,
      "iconKind": "sfSymbol"
    },
    {
      "id": "6084C99B-D20C-4184-B835-722C41426F2F",
      "name": "学习成长",
      "systemImage": "folder",
      "sortOrder": 3,
      "createdDate": 1792604960.929135,
      "isBuiltIn": false,
      "iconKind": "sfSymbol"
    },
    {
      "id": "CAB0B53B-ABBF-49A4-8DD5-8D9F0018EFB7",
      "name": "产品设计",
      "systemImage": "folder",
      "sortOrder": 4,
      "createdDate": 1792604960.929135,
      "isBuiltIn": false,
      "iconKind": "sfSymbol"
    }
  ],
  "tags": [
    {
      "id": "64E1CC10-9CB9-48D7-A331-2234D1301EEC",
      "name": "样例",
      "color": "blue",
      "promptIDs": [
        "11E38BAA-5CFE-4E38-800F-82BEA7D57F10",
        "ACEA6DC4-8DED-4CC1-84FF-786C48FCEFAC",
        "33110B94-B81E-4D0E-9D47-47BF60DA5033",
        "2CA70E58-0814-4338-99C6-66FB47BED7C1",
        "5DE25D56-43E3-418D-A40B-B7444EE1E8F1",
        "C487B9C0-BC72-47B2-9BC7-55766A3BEB62",
        "D9986FF6-201E-4B89-80C2-7BE58ABD5FE8",
        "40CB3992-732A-46BE-A212-36B2B20B8494",
        "49E25989-72F2-494D-BC7C-C70ECCE4B157",
        "400DA8B3-4E6D-4DCD-95FD-C0A007452886",
        "BCC15FF4-CBFB-484B-B535-C6F9B1BBFEA8",
        "7949E5DF-69E3-425D-BD34-D2EC26B08294"
      ],
      "createdAt": 1792604960.929135
    },
    {
      "id": "3D2C98F9-9862-471A-829B-019864384D48",
      "name": "SwiftUI",
      "color": "orange",
      "promptIDs": [
        "11E38BAA-5CFE-4E38-800F-82BEA7D57F10"
      ],
      "createdAt": 1792604960.929135
    }
  ],
  "variableDefinitions": [
    {
      "id": "B02197DC-5D7E-42C3-943C-00468055D897",
      "promptID": "11E38BAA-5CFE-4E38-800F-82BEA7D57F10",
      "name": "页面名称",
      "label": "页面名称",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "2011EB5B-F329-475F-90DC-B927E16EF1EC",
      "promptID": "11E38BAA-5CFE-4E38-800F-82BEA7D57F10",
      "name": "用户群体",
      "label": "用户群体",
      "defaultValue": "",
      "order": 1,
      "isRepeatable": false
    },
    {
      "id": "FC54CD57-5CE7-4D37-96A1-E8321D1E7F26",
      "promptID": "ACEA6DC4-8DED-4CC1-84FF-786C48FCEFAC",
      "name": "代码",
      "label": "代码",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "A2BFCFEA-A1BC-4E65-B0DE-9F0A9E0D87F3",
      "promptID": "33110B94-B81E-4D0E-9D47-47BF60DA5033",
      "name": "功能描述",
      "label": "功能描述",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "E7AD3D09-6848-4F1A-8A63-340B62ED7F76",
      "promptID": "2CA70E58-0814-4338-99C6-66FB47BED7C1",
      "name": "功能",
      "label": "功能",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "3E6C38B6-E0B3-47FB-AEA8-D2A853F2A16D",
      "promptID": "5DE25D56-43E3-418D-A40B-B7444EE1E8F1",
      "name": "主题",
      "label": "主题",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "A691012D-BCD7-4E04-9F5F-B13791858F63",
      "promptID": "5DE25D56-43E3-418D-A40B-B7444EE1E8F1",
      "name": "读者",
      "label": "读者",
      "defaultValue": "",
      "order": 1,
      "isRepeatable": false
    },
    {
      "id": "7EBB0256-6E3E-4F3D-8E6B-B0EF0B9E66FD",
      "promptID": "C487B9C0-BC72-47B2-9BC7-55766A3BEB62",
      "name": "原文",
      "label": "原文",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "A4E91B6B-F3CA-4D47-BB22-10305A0D1009",
      "promptID": "D9986FF6-201E-4B89-80C2-7BE58ABD5FE8",
      "name": "目标语言",
      "label": "目标语言",
      "defaultValue": "英语",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "0D6F0BCA-597B-4E00-9BCF-501A123DF31E",
      "promptID": "D9986FF6-201E-4B89-80C2-7BE58ABD5FE8",
      "name": "原文",
      "label": "原文",
      "defaultValue": "",
      "order": 1,
      "isRepeatable": false
    },
    {
      "id": "8F1F925C-26E6-433B-B254-B78A5E0F7714",
      "promptID": "40CB3992-732A-46BE-A212-36B2B20B8494",
      "name": "会议记录",
      "label": "会议记录",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "3F7D97F5-6B24-4EFC-9259-2FA3097CE9D5",
      "promptID": "49E25989-72F2-494D-BC7C-C70ECCE4B157",
      "name": "本周记录",
      "label": "本周记录",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "5595AA94-C8AE-4B38-B623-C4C1C8CADFFB",
      "promptID": "400DA8B3-4E6D-4DCD-95FD-C0A007452886",
      "name": "学习主题",
      "label": "学习主题",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "856C1182-CEE8-4ECB-AE8A-6732B3287951",
      "promptID": "400DA8B3-4E6D-4DCD-95FD-C0A007452886",
      "name": "天数",
      "label": "天数",
      "defaultValue": "14",
      "order": 1,
      "isRepeatable": false
    },
    {
      "id": "B01655C7-0059-419E-9EA6-9C3099FAA71E",
      "promptID": "400DA8B3-4E6D-4DCD-95FD-C0A007452886",
      "name": "每日时间",
      "label": "每日时间",
      "defaultValue": "30 分钟",
      "order": 2,
      "isRepeatable": false
    },
    {
      "id": "9D6A2A73-392E-4969-852A-3EF939C6F9FB",
      "promptID": "BCC15FF4-CBFB-484B-B535-C6F9B1BBFEA8",
      "name": "概念",
      "label": "概念",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    },
    {
      "id": "C55698D4-1417-47D9-B16F-C292D2FA2789",
      "promptID": "7949E5DF-69E3-425D-BD34-D2EC26B08294",
      "name": "需求描述",
      "label": "需求描述",
      "defaultValue": "",
      "order": 0,
      "isRepeatable": false
    }
  ],
  "versions": [],
  "smartCollections": [],
  "trash": []
}
"""#
}
