import Foundation

struct BackendDiagnostic: LocalizedError, Equatable {
  let message: String
  let code: String?
  let parameter: String?
  let httpStatus: Int
  let requestID: String?
  let retryAfter: Date?

  static func parse(_ data: Data, status: Int, requestID: String?,
                    headers: [String: String] = [:]) -> BackendDiagnostic {
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    let error = json?["error"] as? [String: Any]
    let reason =
      (error?["message"] as? String) ?? (json?["detail"] as? String)
      ?? "Request rejected (HTTP \(status))"
    return BackendDiagnostic(
      message: String(reason.prefix(1200)),
      code: error?["code"] as? String,
      parameter: error?["param"] as? String,
      httpStatus: status,
      requestID: requestID,
      retryAfter: status == 429 ? RetryAfterPolicy.deadline(headers: headers) : nil)
  }

  var isPlanLimit: Bool {
    code == "subscription_sharing_usage_limit_exceeded"
  }
  var isCapabilityIssue: Bool {
    code == "subscription_sharing_unsupported_capability"
  }
  var guidance: String? {
    if isPlanLimit { return "See ChatGPT Settings → Usage for your app's plan limits." }
    if isCapabilityIssue {
      return
        "This model or request feature was not accepted. Try disabling web search or selecting a different model; your selection won't be changed automatically."
    }
    if httpStatus == 401 { return "Your chosen account authorization may need renewal." }
    if httpStatus == 429 { return "The server is rate-limiting requests. Use the manual Retry response button after the limit resets." }
    return nil
  }
  var errorDescription: String? {
    let category = code.map { "[\($0)] " } ?? ""
    let detail = guidance.map { " \($0)" } ?? ""
    let req = requestID.map { " (Request ID: \($0))" } ?? ""
    return category + message + detail + req
  }
}
