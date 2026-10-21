import Foundation
import Security

enum AIProviderKind: String, CaseIterable, Identifiable {
    case deepSeek
    case custom

    var id: Self { self }

    var keychainAccount: String {
        switch self {
        case .deepSeek: "deepseek"
        case .custom: "custom"
        }
    }

    func displayName(usesChinese: Bool) -> String {
        switch self {
        case .deepSeek:
            "DeepSeek"
        case .custom:
            usesChinese ? "自定义 API" : "Custom API"
        }
    }
}

struct AIProviderConfiguration: Equatable {
    static let deepSeekBaseURL = "https://api.deepseek.com"
    static let defaultDeepSeekModel = "deepseek-v4-flash"

    let provider: AIProviderKind
    let baseURL: String
    let model: String

    var requiresAPIKey: Bool {
        provider == .deepSeek
    }

    func chatCompletionsURL() throws -> URL {
        let trimmed = baseURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil
        else {
            throw AIServiceError.invalidBaseURL
        }

        let isLocalHost = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocalHost) else {
            throw AIServiceError.insecureBaseURL
        }

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        if !path.hasSuffix("/chat/completions") {
            path += "/chat/completions"
        }
        components.path = path

        guard let url = components.url else {
            throw AIServiceError.invalidBaseURL
        }
        return url
    }

    func validated() throws -> Self {
        _ = try chatCompletionsURL()
        guard !model.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw AIServiceError.missingModel
        }
        return self
    }
}

enum AIKeychainStore {
    private static var service: String { AppEnvironment.keychainService }

    static func load(for provider: AIProviderKind) throws -> String? {
        guard !AppEnvironment.isTesting else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            throw AIServiceError.keychain(status)
        }
        return key
    }

    static func save(
        _ apiKey: String,
        for provider: AIProviderKind
    ) throws {
        guard !AppEnvironment.isTesting else { throw AIServiceError.keychain(errSecInteractionNotAllowed) }
        let trimmed = apiKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmed.isEmpty {
            try remove(for: provider)
            return
        }

        let keyData = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: keyData,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            let addStatus = SecItemAdd(
                newItem as CFDictionary,
                nil
            )
            guard addStatus == errSecSuccess else {
                throw AIServiceError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw AIServiceError.keychain(updateStatus)
        }
    }

    static func remove(for provider: AIProviderKind) throws {
        guard !AppEnvironment.isTesting else { throw AIServiceError.keychain(errSecInteractionNotAllowed) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIServiceError.keychain(status)
        }
    }
}

struct AITemplateService {
    static let maximumResponseByteCount = 2 * 1_024 * 1_024

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func rewritePrompt(
        content: String,
        goal: AIRewriteGoal,
        additionalInstructions: String,
        usesChinese: Bool,
        configuration: AIProviderConfiguration,
        apiKey: String?
    ) async throws -> String {
        let instruction = usesChinese
            ? "你是提示词编辑器。请按“\(goal.title(usesChinese: true))”改写下面的提示词。只返回完整改写正文，不要解释，不要使用 Markdown 代码块。必须原样保留所有 {{变量}} 和 {{变量[]}} 占位符。"
            : "You are a prompt editor. Rewrite the prompt for: \(goal.title(usesChinese: false)). Return only the complete rewritten prompt, with no explanation or Markdown fence. Preserve every {{variable}} and {{variable[]}} placeholder exactly."
        let extra = additionalInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = [instruction, extra.isEmpty ? nil : (usesChinese ? "补充要求：\(extra)" : "Additional requirements: \(extra)"), usesChinese ? "原提示词：\n\(content)" : "Original prompt:\n\(content)"].compactMap { $0 }.joined(separator: "\n\n")
        return try await generateTemplate(request: request, configuration: configuration, apiKey: apiKey)
    }

    func generateTemplate(
        request: String,
        configuration: AIProviderConfiguration,
        apiKey: String?
    ) async throws -> String {
        let urlRequest = try makeRequest(
            request: request,
            configuration: configuration,
            apiKey: apiKey
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw AIServiceError.network(error.localizedDescription)
        }

        guard data.count <= Self.maximumResponseByteCount else {
            throw AIServiceError.responseTooLarge
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(
                APIErrorEnvelope.self,
                from: data
            )
            throw AIServiceError.http(
                statusCode: httpResponse.statusCode,
                message: serverError?.error.message
            )
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(
                ChatCompletionResponse.self,
                from: data
            )
        } catch {
            throw AIServiceError.invalidResponse
        }

        guard let content = decoded.choices.first?.message.content else {
            throw AIServiceError.emptyResponse
        }
        let cleaned = Self.cleanGeneratedTemplate(content)
        guard !cleaned.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        return cleaned
    }

    func makeRequest(
        request: String,
        configuration: AIProviderConfiguration,
        apiKey: String?
    ) throws -> URLRequest {
        let configuration = try configuration.validated()
        let trimmedKey = apiKey?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let trimmedKey,
           trimmedKey.rangeOfCharacter(from: .newlines) != nil {
            throw AIServiceError.invalidAPIKey
        }
        if configuration.requiresAPIKey,
           trimmedKey?.isEmpty != false {
            throw AIServiceError.missingAPIKey
        }

        let body = ChatCompletionRequest(
            model: configuration.model.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            messages: [
                .init(role: "user", content: request)
            ],
            stream: false
        )

        var urlRequest = URLRequest(
            url: try configuration.chatCompletionsURL()
        )
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 90
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        if let trimmedKey, !trimmedKey.isEmpty {
            urlRequest.setValue(
                "Bearer \(trimmedKey)",
                forHTTPHeaderField: "Authorization"
            )
        }
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    func testConnection(
        configuration: AIProviderConfiguration,
        apiKey: String?
    ) async throws {
        _ = try await generateTemplate(
            request: "Reply with exactly: OK",
            configuration: configuration,
            apiKey: apiKey
        )
    }

    static func cleanGeneratedTemplate(_ content: String) -> String {
        var result = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard result.hasPrefix("```"), result.hasSuffix("```") else {
            return result
        }

        let lines = result.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        guard lines.count >= 2 else { return result }

        var contentLines = Array(lines.dropFirst().dropLast())
        if contentLines.last?.isEmpty == true {
            contentLines.removeLast()
        }
        result = contentLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError
}

enum AIServiceError: LocalizedError, Equatable {
    case invalidBaseURL
    case insecureBaseURL
    case missingModel
    case missingAPIKey
    case invalidAPIKey
    case keychain(OSStatus)
    case network(String)
    case invalidResponse
    case responseTooLarge
    case emptyResponse
    case http(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "The AI API address is invalid."
        case .insecureBaseURL:
            "Use an HTTPS API address. HTTP is allowed only for localhost."
        case .missingModel:
            "Enter a model name."
        case .missingAPIKey:
            "Enter and save a DeepSeek API key first."
        case .invalidAPIKey:
            "The API key contains an invalid line break."
        case .keychain(let status):
            "Unable to access the API key in Keychain (code \(status))."
        case .network(let message):
            "Unable to reach the AI service: \(message)"
        case .invalidResponse:
            "The AI service returned an unsupported response."
        case .responseTooLarge:
            "The AI response is too large."
        case .emptyResponse:
            "The AI service returned an empty response."
        case .http(let statusCode, let message):
            if let message,
               !message.trimmingCharacters(
                   in: .whitespacesAndNewlines
               ).isEmpty {
                "AI request failed (HTTP \(statusCode)): \(message)"
            } else {
                "AI request failed (HTTP \(statusCode))."
            }
        }
    }
}


struct AIRewriteRequest {
    let content: String
    let definitions: [TemplateVariableDraft]
    let goal: AIRewriteGoal
    let instructions: String
    let usesChinese: Bool

    var payload: String {
        let names = Set(PromptTemplate(content).variables)
        let metadata = definitions.filter { names.contains($0.name) }.sorted { $0.order < $1.order }.map {
            "\($0.name) | label=\($0.label) | default=\($0.defaultValue) | list=\($0.isRepeatable)"
        }.joined(separator: "\n")
        let goalRule: String
        switch goal {
        case .concise: goalRule = "Remove repetition and filler while retaining every task, constraint and acceptance criterion. Do not shorten at the expense of clarity."
        case .context: goalRule = "Clarify prerequisites and ambiguous references using only supplied facts. Identify missing context as an instruction to ask for it; never invent project details or add placeholders."
        case .structure: goalRule = "Organize the task, supplied context, constraints and output requirements into a logical order. Use headings only when useful; avoid boilerplate roles and unnecessary sections."
        case .tone: goalRule = "Use precise, natural and actionable language. Resolve vague wording without changing intent, audience, technical terms or scope."
        case .custom: goalRule = "Apply the user's specific editing requirements while preserving intent and all mandatory constraints."
        }
        return """
        You are editing a reusable prompt, not executing the task inside it.
        Preserve the original language unless the additional requirements explicitly request translation.
        Preserve factual details, technical frameworks, audience, scope and output constraints. Do not answer the original task or add unsupported claims.
        Editing policy: \(goalRule)
        Check that the result is actionable and contains all original requirements. If the original is already effective, make minimal changes. Longer is not inherently better.
        Rewrite the prompt for: \(goal.title(usesChinese: usesChinese)).
        Return only the complete rewritten text. Preserve the exact set of {{name}} and {{name[]}} variables and their types. Do not invent factual context.
        Requirements:
        \(instructions)
        Variable definitions (preserve):
        \(metadata)
        Original prompt:
        \(content)
        """
    }
    func validate(_ candidate: String) throws {
        guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIServiceError.emptyResponse }
        let signature: (String) -> Set<String> = { text in
            Set(PromptTemplate(text).variableSignatures.map { "\($0.name)|\($0.isRepeatable)" })
        }
        guard signature(content) == signature(candidate) else {
            throw TransferError.invalid(usesChinese ? "变量名称或列表类型发生了变化，请修正后再采用。" : "Variable names or list types changed. Correct them before accepting.")
        }
    }
}
struct AIRewriteResult { let content: String }
extension AITemplateService {
    func rewrite(_ request: AIRewriteRequest, configuration: AIProviderConfiguration, apiKey: String?) async throws -> AIRewriteResult {
        let content = try await generateTemplate(request: request.payload, configuration: configuration, apiKey: apiKey)
        try Task.checkCancellation()
        return AIRewriteResult(content: content)
    }
}

struct RewriteDiffLine: Identifiable {
    let id: Int
    let text: String
    let kind: Kind
    enum Kind { case unchanged, removed, added }
    static func compare(original: String, candidate: String) -> [RewriteDiffLine] {
        let old = original.components(separatedBy: "\n"), new = candidate.components(separatedBy: "\n")
        let changes = new.difference(from: old)
        var removed = Set<Int>(), added = Set<Int>()
        for change in changes {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): added.insert(offset)
            }
        }
        var result: [RewriteDiffLine] = [], i = 0, j = 0
        func append(_ text: String, _ kind: Kind) { result.append(.init(id: result.count, text: text, kind: kind)) }
        while i < old.count || j < new.count {
            if i < old.count && removed.contains(i) { append(old[i], .removed); i += 1 }
            else if j < new.count && added.contains(j) { append(new[j], .added); j += 1 }
            else if i < old.count && j < new.count { append(new[j], .unchanged); i += 1; j += 1 }
            else if i < old.count { append(old[i], .removed); i += 1 }
            else { append(new[j], .added); j += 1 }
        }
        return result
    }
}


/// Only provider-returned text is displayed; it is never stored in the library or logs.
struct AIRewriteProgress: Sendable {
    var reasoning = ""
    var content = ""
}

struct RewriteStreamAccumulator {
    private(set) var progress = AIRewriteProgress()
    private(set) var finished = false
    mutating func consume(_ line: String) throws {
        guard line.hasPrefix("data:") else { return }
        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { finished = true; return }
        guard !payload.isEmpty else { return }
        guard let data = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["error"] == nil,
              let choices = object["choices"] as? [[String: Any]] else { throw AIServiceError.invalidResponse }
        guard let choice = choices.first else { return }
        if let reason = choice["finish_reason"] as? String, reason != "stop" {
            throw AIServiceError.invalidResponse // Never offer truncated or filtered output for adoption.
        }
        let delta = choice["delta"] as? [String: Any] ?? [:]
        progress.reasoning += delta["reasoning_content"] as? String ?? ""
        progress.content += delta["content"] as? String ?? ""
    }
    func result() throws -> AIRewriteResult {
        guard finished else { throw AIServiceError.invalidResponse }
        let content = AITemplateService.cleanGeneratedTemplate(progress.content)
        guard !content.isEmpty else { throw AIServiceError.emptyResponse }
        return AIRewriteResult(content: content)
    }
}

extension AITemplateService {
    func rewriteStreaming(_ input: AIRewriteRequest, configuration: AIProviderConfiguration,
                          apiKey: String?, thinking: Bool,
                          onProgress: @MainActor (AIRewriteProgress) -> Void) async throws -> AIRewriteResult {
        // Custom providers retain compatibility with the existing non-streaming API.
        guard configuration.provider == .deepSeek else {
            return try await rewrite(input, configuration: configuration, apiKey: apiKey)
        }
        var request = try makeRequest(request: input.payload, configuration: configuration, apiKey: apiKey)
        var body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        body["stream"] = true
        body["thinking"] = ["type": thinking ? "enabled" : "disabled"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AIServiceError.http(statusCode: http.statusCode, message: nil)
        }
        var parser = RewriteStreamAccumulator(), line = Data(), count = 0
        var lastUpdate = Date.distantPast
        for try await byte in bytes {
            try Task.checkCancellation()
            count += 1
            guard count <= Self.maximumResponseByteCount else { throw AIServiceError.responseTooLarge }
            if byte == 10 {
                guard let text = String(data: line, encoding: .utf8) else { throw AIServiceError.invalidResponse }
                try parser.consume(text.trimmingCharacters(in: .newlines))
                line.removeAll(keepingCapacity: true)
                if Date().timeIntervalSince(lastUpdate) >= 0.1 || parser.finished {
                    await onProgress(parser.progress)
                    lastUpdate = Date()
                }
                if parser.finished { break }
            } else { line.append(byte) }
        }
        if !line.isEmpty, let text = String(data: line, encoding: .utf8) { try parser.consume(text) }
        try Task.checkCancellation()
        await onProgress(parser.progress)
        return try parser.result()
    }
}
