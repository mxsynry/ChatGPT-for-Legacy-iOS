import Foundation

// The public Responses API streams text and source metadata separately.
// Keep parsing independent of SwiftUI so it can be regression-tested on Linux.
struct ResponseCitation: Codable, Hashable, Identifiable {
    let url: String
    let title: String
    var id: String { url }

    init?(url raw: String, title rawTitle: String?) {
        guard raw.count <= 4096,
              let link = URLComponents(string: raw),
              CitationURLPolicy.allow(link),
              let host = link.host else { return nil }
        url = raw
        let cleaned = (rawTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        title = cleaned.isEmpty ? host : String(cleaned.prefix(140))
    }

    enum CodingKeys: String, CodingKey { case url, title }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawURL = try c.decode(String.self, forKey: .url)
        let rawTitle = try c.decodeIfPresent(String.self, forKey: .title)
        guard let sanitized = ResponseCitation(url: rawURL, title: rawTitle) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: c,
                debugDescription: "Unsafe source URL")
        }
        self = sanitized
    }

    static func parse(_ item: Any?) -> ResponseCitation? {
        guard let object = item as? [String: Any],
              object["type"] as? String == "url_citation",
              let url = object["url"] as? String else { return nil }
        return ResponseCitation(url: url, title: object["title"] as? String)
    }
}

struct ResponseUsage: Codable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int

    static func parse(_ response: [String: Any]) -> ResponseUsage? {
        guard let usage = response["usage"] as? [String: Any],
              let input = usage["input_tokens"] as? Int,
              let output = usage["output_tokens"] as? Int,
              input >= 0, output >= 0 else { return nil }
        let (sum, overflow) = input.addingReportingOverflow(output)
        guard !overflow else { return nil }
        let total = usage["total_tokens"] as? Int ?? sum
        guard total >= sum else { return nil }
        return ResponseUsage(inputTokens: input, outputTokens: output, totalTokens: total)
    }
}

enum ParsedResponseEvent {
    case delta(String)
    case progress(String)
    case citation(ResponseCitation)
    case completed([ResponseCitation], ResponseUsage?)
    case failed(String)
    case incomplete(String?)
    case ignore
}

enum ResponseStreamEvents {
    static func parse(_ dataLine: String) -> ParsedResponseEvent {
        guard let data = dataLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = json["type"] as? String else { return .ignore }
        switch kind {
        case "response.created", "response.in_progress":
            return .progress("Generating…")
        case "response.output_item.added":
            if let item = json["item"] as? [String: Any],
               item["type"] as? String == "web_search_call" {
                return .progress("Searching web…")
            }
        case "response.web_search_call.in_progress", "response.web_search_call.searching":
            return .progress("Searching web…")
        case "response.output_text.delta":
            if let delta = json["delta"] as? String { return .delta(delta) }
        case "response.output_text.annotation.added":
            if let citation = ResponseCitation.parse(json["annotation"]) { return .citation(citation) }
        case "response.completed":
            // Some servers send annotations only in the final response object.
            // Collect them even if no annotation.added event was received.
            var citations: [ResponseCitation] = []
            let response = json["response"] as? [String: Any]
            if let output = response?["output"] as? [[String: Any]] {
                for item in output {
                    guard let contents = item["content"] as? [[String: Any]] else { continue }
                    for content in contents {
                        guard let annotations = content["annotations"] as? [Any] else { continue }
                        citations.append(contentsOf: annotations.compactMap(ResponseCitation.parse))
                    }
                }
            }
            return .completed(citations, response.flatMap(ResponseUsage.parse))
        case "response.failed":
            let response = json["response"] as? [String: Any]
            let error = response?["error"] as? [String: Any]
            return .failed((error?["message"] as? String) ?? (error?["code"] as? String) ?? "Response failed")
        case "response.incomplete":
            let response = json["response"] as? [String: Any]
            let detail = response?["incomplete_details"] as? [String: Any]
            let reason = (detail?["reason"] as? String).map { String($0.prefix(120)) }
            return .incomplete(reason)
        case "error":
            let error = json["error"] as? [String: Any]
            return .failed((error?["message"] as? String) ?? (json["message"] as? String) ?? "Streaming error")
        default: break
        }
        return .ignore
    }
}
