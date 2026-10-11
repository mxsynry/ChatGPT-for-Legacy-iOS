import Foundation

/// Pure, iOS-independent model-catalog parsing. `visibility != list` means
/// "not suggested for the normal picker", not proof of account entitlement.
struct ModelChoice: Hashable, Identifiable {
  let id: String
  let displayName: String
  let visibility: String
  var isListed: Bool { visibility == "list" || visibility == "api" }
}

enum ModelCatalogError: Error { case unrecognized }

enum ModelCatalog {
  static func decode(_ data: Data) throws -> [ModelChoice] {
    guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ModelCatalogError.unrecognized
    }
    var options = [ModelChoice]()
    var seen = Set<String>()
    if let entries = raw["models"] as? [[String: Any]] {
      for entry in entries {
        guard let id = entry["slug"] as? String, !id.isEmpty,
          seen.insert(id).inserted
        else { continue }
        let name = entry["display_name"] as? String
        let label = (name?.isEmpty == false) ? name! : id
        options.append(
          ModelChoice(
            id: id, displayName: label,
            visibility: entry["visibility"] as? String ?? "unspecified"))
      }
      return options
    }
    if let entries = raw["data"] as? [[String: Any]] {
      for entry in entries {
        guard let id = entry["id"] as? String, !id.isEmpty,
          seen.insert(id).inserted
        else { continue }
        options.append(ModelChoice(id: id, displayName: id, visibility: "api"))
      }
      return options.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }
    throw ModelCatalogError.unrecognized
  }

  static func filtered(_ choices: [ModelChoice], query: String, showOther: Bool) -> [ModelChoice] {
    choices.filter { choice in
      (showOther || choice.isListed)
        && (query.isEmpty || choice.id.localizedCaseInsensitiveContains(query)
          || choice.displayName.localizedCaseInsensitiveContains(query))
    }
  }
}
