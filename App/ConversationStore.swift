import Foundation
#if canImport(Combine)
import Combine
#else
// Linux-only shims enable actual ConversationStore typechecking in CI.
// iOS/macOS builds use Apple's real Combine ObservableObject / @Published.
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
protocol ObservableObject: AnyObject {}
#endif

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: String
    var text: String
    var imageDataURL: String? = nil
    var citations: [ResponseCitation] = []

    enum CodingKeys: String, CodingKey { case id, role, text, imageDataURL, citations }
    init(id: UUID = UUID(), role: String, text: String, imageDataURL: String? = nil, citations: [ResponseCitation] = []) {
        self.id = id; self.role = role; self.text = text; self.imageDataURL = imageDataURL; self.citations = citations
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(String.self, forKey: .role)
        text = try c.decode(String.self, forKey: .text)
        imageDataURL = try c.decodeIfPresent(String.self, forKey: .imageDataURL)
        // An invalid source annotation must not make an entire chat history
        // unreadable. Drop unsafe citations while preserving the messages.
        citations = (try? c.decodeIfPresent([ResponseCitation].self, forKey: .citations)) ?? []
    }
}
struct LocalConversation: Identifiable, Codable {
    var id = UUID()
    var title: String = "New chat"
    var messages: [ChatMessage] = []
    var updatedAt = Date()
    var isTemporary: Bool = false
    var draft: String = ""
    var importedSourceID: String? = nil
    var modelID: String? = nil
    var lastUsage: ResponseUsage? = nil
    var lastRateLimits: RateLimitHeaders? = nil
    var branchMode: LocalBranchMode = .chat
    var reasoningEffort: BranchReasoning = .automatic
    var branchedFrom: BranchProvenance? = nil
    // User-controlled organization and local privacy state; backwards compatible.
    var isPinned: Bool = false
    var isArchived: Bool = false
    var isLocked: Bool = false
    var webSearchEnabled: Bool = false

    enum CodingKeys: String, CodingKey { case id, title, messages, updatedAt, isTemporary, draft, importedSourceID, modelID, lastUsage, lastRateLimits, branchMode, reasoningEffort, branchedFrom, isPinned, isArchived, isLocked, webSearchEnabled }
    init() {}
    init(imported: ImportedChatRecord) {
        title = imported.title
        messages = imported.messages
        updatedAt = imported.updatedAt
        importedSourceID = imported.sourceID
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        messages = try c.decode([ChatMessage].self, forKey: .messages)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        isTemporary = try c.decodeIfPresent(Bool.self, forKey: .isTemporary) ?? false
        draft = try c.decodeIfPresent(String.self, forKey: .draft) ?? ""
        importedSourceID = try c.decodeIfPresent(String.self, forKey: .importedSourceID)
        modelID = try c.decodeIfPresent(String.self, forKey: .modelID)
        lastUsage = try c.decodeIfPresent(ResponseUsage.self, forKey: .lastUsage)
        lastRateLimits = try c.decodeIfPresent(RateLimitHeaders.self, forKey: .lastRateLimits)
        branchMode = try c.decodeIfPresent(LocalBranchMode.self, forKey: .branchMode) ?? .chat
        reasoningEffort = try c.decodeIfPresent(BranchReasoning.self, forKey: .reasoningEffort) ?? .automatic
        branchedFrom = try c.decodeIfPresent(BranchProvenance.self, forKey: .branchedFrom)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        webSearchEnabled = try c.decodeIfPresent(Bool.self, forKey: .webSearchEnabled) ?? false
    }
}
@MainActor final class ConversationStore: ObservableObject {
    @Published var conversations: [LocalConversation] = []
    @Published var selectedID: UUID?
    @Published private(set) var startupRecoveryNotice: String?
    private(set) var recoveryFileURL: URL?
    private let fileURL: URL
    private var diskWritesEnabled = true
    private var lastStreamPersistence = Date()
    // The @Published conversations array already invalidates the transcript.
    // Publishing a second tick caused duplicate whole-screen updates.
    private(set) var streamingTick: UInt64 = 0

    init(storageURL: URL? = nil) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = storageURL ?? dir.appendingPathComponent("conversations.json")
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        // Conversations are never part of an automatic cloud backup.
        var protectedURL = fileURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? protectedURL.setResourceValues(resourceValues)
        switch ConversationFileRecovery.load([LocalConversation].self, at: fileURL) {
        case .loaded(let decoded):
            conversations = decoded
            selectedID = decoded.first?.id
        case .quarantined(let backup, let explanation):
            recoveryFileURL = backup
            startupRecoveryNotice = explanation + " Recovery file: " + backup.lastPathComponent
        case .readOnly(let explanation):
            // Still allow using the app in memory, but never overwrite the file.
            diskWritesEnabled = false
            startupRecoveryNotice = explanation
        case .missing:
            break
        }
        if recoveryFileURL == nil,
           let preserved = ConversationFileRecovery.mostRecentRecovery(for: fileURL) {
            recoveryFileURL = preserved
            if startupRecoveryNotice == nil {
                startupRecoveryNotice = "An earlier saved-history recovery file is available: " +
                    preserved.lastPathComponent
            }
        }
        if conversations.isEmpty { newChat() }
    }
    func draft(for id: UUID?) -> String {
        guard let id = id else { return "" }
        return conversations.first(where: { $0.id == id })?.draft ?? ""
    }
    func saveDraft(_ text: String, in id: UUID?) {
        guard let id = id, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        guard conversations[index].draft != text else { return }
        conversations[index].draft = String(text.prefix(20000))
        persist()
    }
    /// A proper message-anchored branch. The parent conversation is unchanged.
    /// Work-style enables a local instruction preset, never the first-party Work runtime.
    @discardableResult
    func branch(from id: UUID?, at messageID: UUID?, mode: LocalBranchMode,
                modelID: String, reasoning: BranchReasoning,
                temporary: Bool) -> UUID? {
        guard let id = id, let source = conversations.first(where: { $0.id == id }),
              let prefixCount = BranchPlanning.prefixCount(
                ids: source.messages.map(\.id), through: messageID) else { return nil }
        var branch = LocalConversation()
        branch.title = BranchPlanning.title(parent: source.title, mode: mode)
        branch.messages = Array(source.messages.prefix(prefixCount))
        // An old draft is not context for branching from an earlier message.
        branch.draft = (messageID == nil) ? source.draft : ""
        branch.modelID = modelID
        branch.branchMode = mode
        branch.reasoningEffort = reasoning
        branch.isTemporary = temporary
        // Never copy the parent's privacy state onto a new branch implicitly.
        // A locked parent can be deliberately branched after local authentication.
        branch.isLocked = false
        branch.webSearchEnabled = source.webSearchEnabled
        branch.branchedFrom = BranchProvenance(
            parentConversationID: id, parentMessageID: messageID, createdAt: Date())
        branch.updatedAt = Date()
        conversations.insert(branch, at: 0)
        selectedID = branch.id
        persist()
        return branch.id
    }
    // Preserve the old call signature for any existing integrations, but the UI
    // must now expose message selection and mode/model choice before branching.
    func branch(from id: UUID?) {
        guard let id = id, let chat = conversations.first(where: { $0.id == id }) else { return }
        _ = branch(from: id, at: nil, mode: .chat,
                   modelID: chat.modelID ?? "gpt-4.1-mini",
                   reasoning: .automatic, temporary: chat.isTemporary)
    }
    func updateRateLimits(_ limits: RateLimitHeaders, in id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].lastRateLimits = limits
        persist()
    }
    func setModel(_ modelID: String, in id: UUID?) {
        guard let id = id, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].modelID = modelID
        persist()
    }
    func updateUsage(_ usage: ResponseUsage, in id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].lastUsage = usage
        persist()
    }
    func newChat(temporary: Bool = false) {
        var chat = LocalConversation()
        chat.isTemporary = temporary
        conversations.insert(chat, at: 0)
        selectedID = chat.id
        persist()
    }
    func append(_ text: String, role: String = "user") {
        guard let id = selectedID else { return }
        append(text, role: role, to: id)
    }
    func append(_ text: String, role: String, to id: UUID, imageDataURL: String? = nil) {
        guard let index = conversations.firstIndex(where: {$0.id == id}) else { return }
        conversations[index].messages.append(ChatMessage(role: role, text: text, imageDataURL: imageDataURL))
        if conversations[index].title == "New chat" && role == "user" {
            conversations[index].title = String(text.prefix(48))
        }
        conversations[index].updatedAt = Date()
        persist()
    }
    func updateMessage(_ messageID: UUID, in conversationID: UUID, text: String) {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let m = conversations[c].messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversations[c].messages[m].text = text
        noteStreamingChange()
    }
    /// One lookup instead of scanning the entire conversation twice per SSE update.
    func appendDelta(_ delta: String, to messageID: UUID, in conversationID: UUID) {
        guard !delta.isEmpty,
              let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let m = conversations[c].messages.firstIndex(where: { $0.id == messageID }),
              conversations[c].messages[m].role == "assistant" else { return }
        conversations[c].messages[m].text.append(contentsOf: delta)
        streamingTick &+= 1
        noteStreamingChange()
    }
    /// Stage 21: fewer whole-history JSON encodes while streaming.
    /// Completion, cancellation and backgrounding always flush explicitly.
    private func noteStreamingChange() {
        let now = Date()
        if now.timeIntervalSince(lastStreamPersistence) >= 8.0 {
            lastStreamPersistence = now
            persist()
        }
    }
    func addCitation(_ citation: ResponseCitation, to messageID: UUID, in conversationID: UUID) {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let m = conversations[c].messages.firstIndex(where: { $0.id == messageID }),
              conversations[c].messages[m].role == "assistant" else { return }
        if !conversations[c].messages[m].citations.contains(where: { $0.url == citation.url }) {
            // Bound memory and disk costs if a large response contains many sources.
            guard conversations[c].messages[m].citations.count < 40 else { return }
            conversations[c].messages[m].citations.append(citation)
            noteStreamingChange()
        }
    }
    func flushStreamingChanges() {
        persist()
        lastStreamPersistence = Date()
    }
    func setWebSearch(_ id: UUID, _ value: Bool) {
        guard let i = conversations.firstIndex(where: { $0.id == id }),
              conversations[i].webSearchEnabled != value else { return }
        conversations[i].webSearchEnabled = value
        persist()
    }
    func setPinned(_ id: UUID, _ value: Bool) {
        guard let i = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[i].isPinned = value
        persist()
    }
    func setArchived(_ id: UUID, _ value: Bool) {
        guard let i = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[i].isArchived = value
        persist()
    }
    func setLocked(_ id: UUID, _ value: Bool) {
        guard let i = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[i].isLocked = value
        persist()
    }
    func rename(_ id: UUID, title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = String(title.prefix(100))
        persist()
    }
    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if selectedID == id { selectedID = conversations.first?.id }
        if conversations.isEmpty { newChat() } else { persist() }
    }
    func editUserMessage(_ messageID: UUID, in conversationID: UUID, text: String) {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let m = conversations[c].messages.firstIndex(where: { $0.id == messageID }),
              conversations[c].messages[m].role == "user" else { return }
        conversations[c].messages[m].text = text
        conversations[c].messages = Array(conversations[c].messages.prefix(m + 1))
        persist()
    }
    // Regenerate from the user prompt preceding the chosen assistant message.
    // Later turns are removed intentionally; the UI should make this clear.
    func rewindToAssistant(_ messageID: UUID, in conversationID: UUID) -> Bool {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }),
              let position = conversations[c].messages.firstIndex(where: { $0.id == messageID }),
              conversations[c].messages[position].role == "assistant" else { return false }
        guard let userPosition = conversations[c].messages[..<position].lastIndex(where: { $0.role == "user" }) else { return false }
        conversations[c].messages = Array(conversations[c].messages.prefix(userPosition + 1))
        persist()
        return true
    }
    func removeMessage(_ messageID: UUID, in conversationID: UUID) {
        guard let c = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[c].messages.removeAll { $0.id == messageID }
        persist()
    }
    @discardableResult
    func mergeChatGPTExport(_ incoming: [ImportedChatRecord]) -> Int {
        var known = Set(conversations.compactMap { $0.importedSourceID })
        var accepted = [LocalConversation]()
        for record in incoming where !known.contains(record.sourceID) {
            known.insert(record.sourceID)
            accepted.append(LocalConversation(imported: record))
        }
        guard !accepted.isEmpty else { return 0 }
        conversations.insert(contentsOf: accepted.sorted { $0.updatedAt > $1.updatedAt }, at: 0)
        selectedID = accepted.first?.id
        persist()
        return accepted.count
    }
    func deleteAll() {
        conversations.removeAll()
        selectedID = nil
        newChat()
    }
    func exportData() -> Data? {
        try? JSONEncoder().encode(conversations.filter { !$0.isTemporary })
    }
    func persist() {
        guard diskWritesEnabled else { return }
        guard let data = try? JSONEncoder().encode(conversations.filter { !$0.isTemporary }) else { return }
        do {
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: fileURL.path)
            #else
            // Portable store regression tests also run on macOS/Linux.
            try data.write(to: fileURL, options: .atomic)
            #endif
            var persistedURL = fileURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? persistedURL.setResourceValues(resourceValues)
        } catch {
            NSLog("Conversation persistence failed: %@", String(describing: error))
        }
    }
}
