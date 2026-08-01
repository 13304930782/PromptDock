import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var runtime: AppRuntime

    var body: some View {
        TabView {
            GeneralSettingsView(runtime: runtime)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ShortcutSettingsView(runtime: runtime)
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
        }
        .frame(width: 640, height: 540)
        .onAppear { runtime.start() }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var runtime: AppRuntime

    @AppStorage(AppLanguage.storageKey)
    private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferences.showMenuBar)
    private var showMenuBar = true
    @AppStorage(AppPreferences.launchAtLogin)
    private var launchAtLogin = false

    @State private var loginItemError: String?
    @State private var isSynchronizingLoginState = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Language", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
            }

            Section("Quick Access") {
                Toggle("Show PromptDock in the menu bar", isOn: $showMenuBar)
                    .onChange(of: showMenuBar) { _, isVisible in
                        runtime.setMenuBarVisible(isVisible)
                    }
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { oldValue, newValue in
                        guard !isSynchronizingLoginState else { return }
                        do {
                            try LoginItemService.setEnabled(newValue)
                        } catch {
                            isSynchronizingLoginState = true
                            launchAtLogin = oldValue
                            isSynchronizingLoginState = false
                            loginItemError = error.localizedDescription
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            isSynchronizingLoginState = true
            launchAtLogin = LoginItemService.isEnabled
            isSynchronizingLoginState = false
        }
        .alert("Unable to Change Login Setting", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "An unknown error occurred.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )
    }
}

private struct ShortcutSettingsView: View {
    @ObservedObject var runtime: AppRuntime
    @ObservedObject private var hotKeyService: GlobalHotKeyService

    @AppStorage(AppPreferences.globalQuickSearchEnabled)
    private var globalQuickSearchEnabled = true
    @AppStorage(AppPreferences.showMenuBar)
    private var showMenuBar = true

    init(runtime: AppRuntime) {
        self.runtime = runtime
        hotKeyService = runtime.hotKeyService
    }

    var body: some View {
        Form {
            Section("Global Quick Search") {
                Toggle(
                    "Enable global quick search",
                    isOn: $globalQuickSearchEnabled
                )
                .onChange(of: globalQuickSearchEnabled) { _, enabled in
                    runtime.setGlobalQuickSearchEnabled(enabled)
                }

                LabeledContent("Shortcut") {
                    ShortcutRecorderField(
                        displayText: hotKeyService.combination.displayText,
                        isEnabled: globalQuickSearchEnabled,
                        onBegin: hotKeyService.suspendForRecording,
                        onRecord: { combination in
                            _ = hotKeyService.apply(combination)
                        },
                        onCancel: hotKeyService.resumeAfterRecording,
                        onClear: {
                            globalQuickSearchEnabled = false
                        }
                    )
                    .frame(width: 150, height: 28)
                }

                LabeledContent("Status") {
                    Label(
                        hotKeyService.conflictStatus.localizedDescription,
                        systemImage: statusSymbol
                    )
                    .foregroundStyle(statusColor)
                }

                HStack {
                    Spacer()
                    Button("Restore Default ⇧⌘P") {
                        hotKeyService.resetToDefault()
                    }
                }
            }

            Section {
                Text(
                    "PromptDock checks macOS shortcuts and registration conflicts, but other apps may use shortcuts that macOS does not expose."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if !showMenuBar && !globalQuickSearchEnabled {
                    Label(
                        "Both quick-access methods are off. Open PromptDock normally to return to Settings.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { runtime.start() }
    }

    private var statusSymbol: String {
        switch hotKeyService.conflictStatus {
        case .available: "checkmark.circle.fill"
        case .disabled: "pause.circle"
        default: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch hotKeyService.conflictStatus {
        case .available: .green
        case .disabled: .secondary
        default: .orange
        }
    }
}

private struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: PromptDockBackupDocument?
    @State private var importCandidate: PromptDockBackup?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isChoosingImportMode = false
    @State private var notice: BackupNotice?

    var body: some View {
        Form {
            Section("Stored on This Mac") {
                Label("Prompts and categories", systemImage: "internaldrive")
                Label("Category emoji and images", systemImage: "photo")
                Label("AI credentials in Keychain", systemImage: "key")

                Text(
                    "Prompts, categories, local images, and backups stay on this Mac."
                )
                .foregroundStyle(.secondary)
            }

            Section("No Tracking") {
                Label("No account", systemImage: "person.crop.circle.badge.xmark")
                Label("No analytics or advertising", systemImage: "chart.bar.xaxis")
                Label("No cloud sync", systemImage: "icloud.slash")
            }

            Section("Optional AI Template Assistant") {
                Text(
                    "Only after you confirm online generation does PromptDock send the current requirement and template syntax guide to the selected provider. Saved prompts, categories, and local images are not included. The provider’s privacy terms apply."
                )
                .foregroundStyle(.secondary)
            }

            Section("System Backups") {
                Text(
                    "Time Machine, disk synchronization, and other macOS backups are controlled by your system settings."
                )
                .foregroundStyle(.secondary)
            }

            Section("Local Backup") {
                HStack {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export Backup…", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import Backup…", systemImage: "square.and.arrow.down")
                    }
                }

                Text(
                    "A backup includes prompts, favorites, categories, order, emoji, and local category images."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultBackupFilename
        ) { result in
            exportDocument = nil
            switch result {
            case .success:
                notice = BackupNotice(
                    title: String(localized: "Backup Exported"),
                    message: String(
                        localized: "Your local PromptDock backup was saved successfully."
                    )
                )
            case .failure(let error):
                showError(error)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: loadImportCandidate
        )
        .confirmationDialog(
            "Import PromptDock Backup?",
            isPresented: $isChoosingImportMode,
            titleVisibility: .visible
        ) {
            Button("Merge with Current Data") {
                performImport(mode: .merge)
            }
            Button("Replace Current Data", role: .destructive) {
                performImport(mode: .replace)
            }
            Button("Cancel", role: .cancel) {
                importCandidate = nil
            }
        } message: {
            if let summary = importCandidate?.summary {
                Text(
                    "This backup contains \(summary.promptCount) prompts and \(summary.categoryCount) categories. Replacing first saves an automatic safety backup on this Mac."
                )
            }
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var defaultBackupFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "PromptDock Backup \(formatter.string(from: .now))"
    }

    private func prepareExport() {
        do {
            exportDocument = PromptDockBackupDocument(
                backup: try BackupService.makeBackup(in: modelContext)
            )
            isExporting = true
        } catch {
            showError(error)
        }
    }

    private func loadImportCandidate(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data: Data
            do {
                data = try BoundedFileReader.read(
                    url: url,
                    maximumByteCount: BackupService.maximumBackupByteCount
                )
            } catch BoundedFileReaderError.fileTooLarge {
                throw BackupError.fileTooLarge
            }

            importCandidate = try BackupService.decode(data)
            isChoosingImportMode = true
        } catch {
            importCandidate = nil
            showError(error)
        }
    }

    private func performImport(mode: BackupImportMode) {
        guard let importCandidate else { return }

        do {
            let result = try BackupService.importBackup(
                importCandidate,
                mode: mode,
                in: modelContext
            )
            self.importCandidate = nil

            let prompts = try modelContext.fetch(FetchDescriptor<Prompt>())
            WidgetSnapshotService.refresh(from: prompts)

            var message = String(
                localized: "Imported \(result.promptCount) prompts and \(result.categoryCount) categories."
            )
            if result.safetyBackupURL != nil {
                message += " " + String(
                    localized: "A safety backup of the previous data was saved locally."
                )
            }
            notice = BackupNotice(
                title: String(localized: "Import Complete"),
                message: message
            )
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        notice = BackupNotice(
            title: String(localized: "Unable to Complete Backup"),
            message: error.localizedDescription
        )
    }
}

private struct AISettingsView: View {
    @Environment(\.locale) private var locale

    @AppStorage(AppPreferences.aiTemplateAssistantEnabled)
    private var isEnabled = false
    @AppStorage(AppPreferences.aiProvider)
    private var providerRawValue = AIProviderKind.deepSeek.rawValue
    @AppStorage(AppPreferences.aiDeepSeekModel)
    private var deepSeekModel =
        AIProviderConfiguration.defaultDeepSeekModel
    @AppStorage(AppPreferences.aiCustomBaseURL)
    private var customBaseURL = ""
    @AppStorage(AppPreferences.aiCustomModel)
    private var customModel = ""

    @State private var apiKey = ""
    @State private var hasStoredAPIKey = false
    @State private var status: AISettingsStatus?
    @State private var isTesting = false
    @State private var testTask: Task<Void, Never>?

    private var usesChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    private var provider: AIProviderKind {
        AIProviderKind(rawValue: providerRawValue) ?? .deepSeek
    }

    private var configuration: AIProviderConfiguration {
        switch provider {
        case .deepSeek:
            AIProviderConfiguration(
                provider: .deepSeek,
                baseURL: AIProviderConfiguration.deepSeekBaseURL,
                model: deepSeekModel
            )
        case .custom:
            AIProviderConfiguration(
                provider: .custom,
                baseURL: customBaseURL,
                model: customModel
            )
        }
    }

    var body: some View {
        Form {
            Section(
                usesChinese ? "AI 模板助手" : "AI Template Assistant"
            ) {
                Toggle(
                    usesChinese
                        ? "启用在线 AI 生成"
                        : "Enable online AI generation",
                    isOn: $isEnabled
                )

                Picker(
                    usesChinese ? "服务提供方" : "Provider",
                    selection: $providerRawValue
                ) {
                    ForEach(AIProviderKind.allCases) { kind in
                        Text(
                            kind.displayName(
                                usesChinese: usesChinese
                            )
                        )
                        .tag(kind.rawValue)
                    }
                }
                .onChange(of: providerRawValue) { _, _ in
                    loadAPIKey()
                    status = nil
                }
            }

            Section(
                usesChinese ? "连接设置" : "Connection"
            ) {
                if provider == .deepSeek {
                    LabeledContent(
                        usesChinese ? "API 地址" : "API Address",
                        value: AIProviderConfiguration.deepSeekBaseURL
                    )
                    TextField(
                        usesChinese ? "模型" : "Model",
                        text: $deepSeekModel
                    )
                } else {
                    TextField(
                        usesChinese
                            ? "API 地址"
                            : "API Address",
                        text: $customBaseURL,
                        prompt: Text("https://api.example.com/v1")
                    )
                    TextField(
                        usesChinese ? "模型" : "Model",
                        text: $customModel,
                        prompt: Text("model-name")
                    )
                }

                SecureField(
                    provider == .deepSeek
                        ? "DeepSeek API Key"
                        : (usesChinese
                            ? "API Key 或访问令牌（可选）"
                            : "API Key or access token (optional)"),
                    text: $apiKey
                )
                .textContentType(.password)

                HStack {
                    Label(
                        hasStoredAPIKey
                            ? (usesChinese
                                ? "凭证已存入 macOS 钥匙串"
                                : "Credential is stored in macOS Keychain")
                            : (usesChinese
                                ? "尚未保存凭证"
                                : "No stored credential"),
                        systemImage: hasStoredAPIKey
                            ? "checkmark.shield"
                            : "key"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if hasStoredAPIKey {
                        Button(
                            usesChinese ? "删除凭证" : "Delete Credential",
                            role: .destructive
                        ) {
                            deleteAPIKey()
                        }
                    }

                    Button(
                        usesChinese ? "存入钥匙串" : "Save to Keychain"
                    ) {
                        saveAPIKey()
                    }
                }
            }

            Section {
                HStack {
                    if let status {
                        Label(
                            status.message,
                            systemImage: status.systemImage
                        )
                        .font(.caption)
                        .foregroundStyle(status.color)
                        .lineLimit(2)
                    }

                    Spacer()

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button(
                        usesChinese ? "测试连接" : "Test Connection"
                    ) {
                        testConnection()
                    }
                    .disabled(isTesting)
                }

                Text(
                    usesChinese
                        ? "DeepSeek Key 仅保存在此 Mac 的钥匙串。自定义服务必须兼容 OpenAI 的 /chat/completions 响应格式；仅 localhost 可使用 HTTP。测试连接会发送一条很短的请求。"
                        : "The DeepSeek key stays in this Mac’s Keychain. A custom service must support the OpenAI-compatible /chat/completions format; HTTP is allowed only for localhost. Testing sends one short request."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAPIKey()
        }
        .onDisappear {
            testTask?.cancel()
        }
    }

    private func loadAPIKey() {
        do {
            let stored = try AIKeychainStore.load(for: provider)
            apiKey = stored ?? ""
            hasStoredAPIKey = stored?.isEmpty == false
        } catch {
            apiKey = ""
            hasStoredAPIKey = false
            status = .failure(error.localizedDescription)
        }
    }

    private func saveAPIKey() {
        do {
            if provider == .deepSeek,
               apiKey.trimmingCharacters(
                   in: .whitespacesAndNewlines
               ).isEmpty {
                throw AIServiceError.missingAPIKey
            }
            try AIKeychainStore.save(apiKey, for: provider)
            hasStoredAPIKey = !apiKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
            status = .success(
                usesChinese
                    ? "连接设置已保存"
                    : "Connection settings saved"
            )
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func deleteAPIKey() {
        do {
            try AIKeychainStore.remove(for: provider)
            apiKey = ""
            hasStoredAPIKey = false
            status = .success(
                usesChinese ? "凭证已删除" : "Credential deleted"
            )
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func testConnection() {
        testTask?.cancel()
        isTesting = true
        status = nil
        let configuration = configuration
        let key = apiKey

        testTask = Task { @MainActor in
            defer { isTesting = false }
            do {
                try await AITemplateService().testConnection(
                    configuration: configuration,
                    apiKey: key
                )
                guard !Task.isCancelled else { return }
                status = .success(
                    usesChinese ? "连接成功" : "Connection succeeded"
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                status = .failure(error.localizedDescription)
            }
        }
    }
}

private enum AISettingsStatus {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let message), .failure(let message):
            message
        }
    }

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failure: .orange
        }
    }
}

private struct BackupNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ShortcutRecorderField: NSViewRepresentable {
    let displayText: String
    let isEnabled: Bool
    let onBegin: () -> Void
    let onRecord: (HotKeyCombination) -> Void
    let onCancel: () -> Void
    let onClear: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.displayText = displayText
        button.isEnabled = isEnabled
        button.onBegin = onBegin
        button.onRecord = onRecord
        button.onCancel = onCancel
        button.onClear = onClear
        button.updateTitle()
    }
}

private final class ShortcutRecorderButton: NSButton {
    var displayText = ""
    var onBegin: (() -> Void)?
    var onRecord: ((HotKeyCombination) -> Void)?
    var onCancel: (() -> Void)?
    var onClear: (() -> Void)?
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isRecording = true
        title = String(localized: "Type shortcut…")
        window?.makeFirstResponder(self)
        onBegin?()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            finishRecording(cancelled: true)
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            isRecording = false
            onClear?()
            updateTitle()
            return
        }

        let combination = HotKeyCombination.from(event: event)
        isRecording = false
        onRecord?(combination)
        updateTitle()
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if isRecording {
            finishRecording(cancelled: true)
        }
        return result
    }

    func updateTitle() {
        guard !isRecording else { return }
        title = displayText
    }

    private func finishRecording(cancelled: Bool) {
        isRecording = false
        if cancelled { onCancel?() }
        updateTitle()
        window?.makeFirstResponder(nil)
    }
}
