import Foundation

enum ClientError: LocalizedError {
    case noKey, invalidResponse, api(String), diagnostic(BackendDiagnostic), interrupted(StreamInterruption)
    var errorDescription: String? {
        switch self {
        case .noKey: return "Continue with ChatGPT or add an API key in Settings."
        case .invalidResponse: return "Invalid server response."
        case .api(let text): return text
        case .diagnostic(let issue): return issue.errorDescription
        case .interrupted(let event): return event.errorDescription
        }
    }
}
private struct StreamEvent: Decodable {
    let type: String
    let delta: String?
    let message: String?
    let response: ResponseInfo?
    struct ResponseInfo: Decodable {
        let error: ErrorInfo?
        struct ErrorInfo: Decodable {
            let message: String?
            let code: String?
        }
    }
}
private struct ErrorEnvelope: Decodable {
    let error: StreamEvent.ResponseInfo.ErrorInfo?
    let detail: String?
}
actor OpenAIClient {
    // A selected ChatGPT plan must never silently spend an API key when
    // OAuth refresh fails. This was an actual bug in the Stage 16 transport.
    private func selectedCredential() async throws -> String {
        switch AuthBillingChoice.route {
        case .chatgptPlan:
            guard let token = try await ChatGPTCredentialProvider.shared.token(),
                  !token.isEmpty else { throw ClientError.noKey }
            return token
        case .apiKey:
            guard let key = CredentialVault.readAPIKey(), !key.isEmpty else {
                throw ClientError.noKey
            }
            return key
        }
    }

    func stream(messages: [ChatMessage], model: String, webSearch: Bool = false,
                branchMode: LocalBranchMode = .chat,
                reasoningEffort: BranchReasoning = .automatic,
                onProgress: @escaping @Sendable (String) async -> Void = { _ in },
                onRateLimits: @escaping @Sendable (RateLimitHeaders) async -> Void = { _ in },
                onDelta: @escaping @Sendable (String) async -> Void,
                onCitation: @escaping @Sendable (ResponseCitation) async -> Void,
                onUsage: @escaping @Sendable (ResponseUsage) async -> Void) async throws {
        let key = try await selectedCredential()
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONEncoder().encode(ResponsesPayload(
            messages: messages, model: model, webSearch: webSearch,
            branchMode: branchMode, reasoningEffort: reasoningEffort))
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, item in
            if let key = item.key as? String { result[key] = "\(item.value)" }
        }
        if let snapshot = RateLimitHeaders.parse(headers) {
            await onRateLimits(snapshot)
        }
        guard (200..<300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes {
                if body.count >= 65536 { break }
                body.append(byte)
            }
            throw ClientError.diagnostic(BackendDiagnostic.parse(
                body, status: http.statusCode,
                requestID: http.value(forHTTPHeaderField: "x-request-id"),
                headers: headers))
        }
        var collector = SSEFrameCollector()
        var completed = false
        var receivedText = false
        var eventCount = 0
        let requestID = http.value(forHTTPHeaderField: "x-request-id")
        var seenURLs = Set<String>()
        var textBatcher = StreamingTextBatcher()
        func deliverPendingText() async {
            if let text = textBatcher.flush() { await onDelta(text) }
        }
        func handle(_ payload: String) async throws {
            if payload == "[DONE]" { return }
            eventCount += 1
            switch ResponseStreamEvents.parse(payload) {
            case .delta(let delta):
                if !delta.isEmpty { receivedText = true }
                if let text = textBatcher.push(delta) { await onDelta(text) }
            case .progress(let status):
                await onProgress(status)
            case .citation(let citation):
                await deliverPendingText()
                if seenURLs.insert(citation.url).inserted { await onCitation(citation) }
            case .completed(let sources, let usage):
                await deliverPendingText()
                for citation in sources where seenURLs.insert(citation.url).inserted {
                    await onCitation(citation)
                }
                if let usage = usage { await onUsage(usage) }
                completed = true
            case .failed(let reason):
                await deliverPendingText()
                throw ClientError.api(reason)
            case .incomplete(let reason):
                await deliverPendingText()
                throw ClientError.interrupted(StreamInterruption(
                    cause: .serverIncomplete, reason: reason, requestID: requestID,
                    eventsReceived: eventCount, receivedText: receivedText))
            case .ignore: break
            }
        }
        do {
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if let payload = try collector.consume(line) { try await handle(payload) }
                if completed { break }
            }
            try Task.checkCancellation()
            if let final = collector.finish() { try await handle(final) }
        } catch is CancellationError {
            await deliverPendingText()
            throw CancellationError()
        } catch let clientError as ClientError {
            throw clientError
        } catch {
            await deliverPendingText()
            throw ClientError.interrupted(StreamInterruption(
                cause: .connectionError, reason: nil, requestID: requestID,
                eventsReceived: eventCount, receivedText: receivedText))
        }
        await deliverPendingText()
        guard completed else {
            throw ClientError.interrupted(StreamInterruption(
                cause: .connectionClosed, reason: nil, requestID: requestID,
                eventsReceived: eventCount, receivedText: receivedText))
        }
    }
}


// The model picker deliberately exposes all models returned by the account
// catalog. The UI separates ordinary choices from "other returned" entries.
// Neither the catalog nor a manual model ID bypasses server permissions.
extension OpenAIClient {
    func availableModels() async throws -> [ModelChoice] {
        let key = try await selectedCredential()
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.api("Could not load model list (HTTP \(http.statusCode)).")
        }
        return try ModelCatalog.decode(data)
    }
}
