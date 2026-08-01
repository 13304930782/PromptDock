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
              !host.isEmpty
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
    private static let service = "com.promptdock.PromptDock.ai-api-key"

    static func load(for provider: AIProviderKind) throws -> String? {
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
