import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct TransferView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var selectedIDs: Set<UUID> = []
    var filteredIDs: Set<UUID> = []
    @State private var batch: TransferBatch?
    @State private var preview: TransferPreview?
    @State private var conflict = TransferConflict.keepLocal
    @State private var validOnly = false
    @State private var replace = false
    @State private var importing = false
    @State private var exporting = false
    @State private var busy = false
    @State private var scope = "Library"
    @State private var format = "JSON"
    @State private var document: TransferDocument?
    @State private var filename = "PromptDock.json"
    @State private var outputType = UTType.json
    @State private var notice: String?

    var body: some View {
        VStack {
            Form {
                Section("Import") {
                    Button("Choose JSON, Markdown or CSV Files…") { importing = true }
                    if let batch {
                        Text("Valid: \(batch.items.count) · Invalid: \(batch.errors.count)")
                        if !batch.errors.isEmpty {
                            ScrollView { Text(batch.errors.joined(separator: "\n")).textSelection(.enabled) }.frame(maxHeight: 90)
                            Toggle("Import valid items only", isOn: $validOnly)
                        }
                        Picker("Same ID", selection: $conflict) { ForEach(TransferConflict.allCases) { Text($0.rawValue).tag($0) } }
                        Toggle("Replace the entire library (safety backup required)", isOn: $replace).disabled(batch.completeBackup == nil)
                        Button("Preview Changes") { makePreview() }
                            .disabled(!batch.errors.isEmpty && !validOnly)
                    }
                    if let preview {
                        Text("Add: \(preview.added) · Update: \(preview.updated) · Skip: \(preview.skipped)")
                        if replace { Text("All current library contents will be replaced.").foregroundStyle(.red) }
                        Button("Confirm Import") {
                            do { try TransferService.apply(preview, in: context); self.preview = nil; batch = nil; notice = "Import completed." }
                            catch { notice = error.localizedDescription; self.preview = nil }
                        }
                    }
                }
                Section("Export") {
                    Picker("Scope", selection: $scope) {
                        Text("Entire Library").tag("Library")
                        Text("Selected (\(selectedIDs.count))").tag("Selected")
                        Text("Current Filter (\(filteredIDs.count))").tag("Filtered")
                    }
                    Picker("Format", selection: $format) { ForEach(["JSON", "Markdown ZIP", "CSV"], id: \.self) { Text($0) } }
                    Text("Full JSON preserves the library, including Trash and history. Content packages exclude global smart collections. Markdown preserves title, content, category, tags, favorites and variables; CSV preserves only its five columns. Neither preserves history or Trash state.")
                        .font(.caption)
                    HStack {
                        Button("Export…") { prepareExport() }
                        Button("CSV Template…") { exportTemplate() }
                    }
                }
            }
            .formStyle(.grouped)
            if busy { ProgressView("Processing files…") }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }.padding()
        }
        .frame(minWidth: 650, minHeight: 620)
        .disabled(busy)
        .onChange(of: conflict) { preview = nil }
        .onChange(of: replace) { preview = nil }
        .onChange(of: validOnly) { preview = nil }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .commaSeparatedText, UTType(filenameExtension: "md") ?? .plainText], allowsMultipleSelection: true) { result in
            Task { await read(result) }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: outputType, defaultFilename: filename) { result in
            if case .failure(let error) = result { notice = error.localizedDescription }
            document = nil
        }
        .alert("Import / Export", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("OK") {} } message: { Text(notice ?? "") }
    }

    @MainActor
    private func read(_ result: Result<[URL], Error>) async {
        busy = true; preview = nil; defer { busy = false }
        do {
            var files: [(name: String, data: Data)] = []
            var total = 0
            for url in try result.get() {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let data = try BoundedFileReader.read(url: url, maximumByteCount: BackupService.maximumBackupByteCount - total)
                total += data.count
                files.append((url.lastPathComponent, data))
            }
            let input = files
            batch = await Task.detached { TransferService.parse(input) }.value
            validOnly = false; replace = false
        } catch { notice = error.localizedDescription }
    }
    private func makePreview() {
        guard let batch else { return }
        do { preview = try TransferService.preview(batch, local: BackupService.makeBackup(in: context), conflict: conflict, validOnly: validOnly, replace: replace) }
        catch { notice = error.localizedDescription }
    }
    private func prepareExport() {
        do {
            let full = try BackupService.makeBackup(in: context)
            var chosen = scope == "Library" ? full : TransferService.subset(full, ids: scope == "Selected" ? selectedIDs : filteredIDs)
            if format != "JSON" {
                let deleted = Set(chosen.trash.map(\.promptID))
                chosen = TransferService.subset(chosen, ids: Set(chosen.prompts.map(\.id)).subtracting(deleted))
            }
            switch format {
            case "CSV": document = TransferDocument(data: try TransferService.csv(chosen)); filename = "PromptDock.csv"; outputType = .commaSeparatedText
            case "Markdown ZIP": document = TransferDocument(data: try StoredZIP.encode(TransferService.markdownFiles(chosen))); filename = "PromptDock.zip"; outputType = .zip
            default: document = TransferDocument(data: try BackupService.encode(chosen)); filename = "PromptDock.json"; outputType = .json
            }
            exporting = true
        } catch { notice = error.localizedDescription }
    }
    private func exportTemplate() {
        document = TransferDocument(data: Data("title,content,category,tags,favorite\r\nExample,Write a summary,Writing,[],false\r\n".utf8))
        filename = "PromptDock-template.csv"; outputType = .commaSeparatedText; exporting = true
    }
}
