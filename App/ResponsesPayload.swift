import Foundation

// The supported public Responses API contract. No ChatGPT first-party endpoint
// or private account cookie is involved. This module is platform-independent.
struct ResponsesPayload: Encodable {
    struct Part: Encodable {
        let type: String
        let text: String?
        let image_url: String?
    }
    enum Content: Encodable {
        case plain(String)
        case multipart([Part])
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .plain(let string): try c.encode(string)
            case .multipart(let parts): try c.encode(parts)
            }
        }
    }
    struct Message: Encodable {
        let role: String
        let content: Content
    }
    struct Tool: Encodable { let type: String }
    struct Reasoning: Encodable { let effort: String }
    let model: String
    let input: [Message]
    let store = false
    let stream = true
    let tools: [Tool]?
    let instructions: String?
    let reasoning: Reasoning?

    init(messages: [ChatMessage], model: String, webSearch: Bool,
         branchMode: LocalBranchMode = .chat,
         reasoningEffort: BranchReasoning = .automatic) {
        self.model = model
        self.instructions = branchMode.instructions
        self.reasoning = reasoningEffort.apiValue.map { Reasoning(effort: $0) }
        input = messages.map { message in
            if message.role == "user", let image = message.imageDataURL {
                let parts = [
                    Part(type: "input_text", text: message.text, image_url: nil),
                    Part(type: "input_image", text: nil, image_url: image)
                ]
                return Message(role: "user", content: .multipart(parts))
            }
            // Text strings are accepted for prior assistant and user turns.
            return Message(role: message.role, content: .plain(message.text))
        }
        tools = webSearch ? [Tool(type: "web_search")] : nil
    }
}
