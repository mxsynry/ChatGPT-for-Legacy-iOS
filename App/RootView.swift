import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import PDFKit

struct RootView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appLock = AppLock()
    @StateObject private var privateChatAccess = PrivateChatAccess()
    @State private var sidebarFilter: ConversationListFilter = .recent
    @StateObject private var voice = VoiceServices()
    @StateObject private var chatGPTSignIn = ChatGPTSignIn()
    @State private var showSidebar = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var showHistoryImporter = false
    @State private var importingHistory = false
    @State private var importingDocument = false
    @State private var historyImportMessage: String?
    @State private var importedDocument: ImportedDocument?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachedImage: Data?
    @State private var useWebSearch = false
    @State private var restoringTools = false
    @State private var editingContext: MessageEditContext?
    @State private var previousConversationID: UUID?
    @State private var followLatest = true
    @State private var lastAutoScroll = Date.distantPast
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var renamingChat: LocalConversation?
    @State private var renameText = ""
    @State private var shareText: String?
    @State private var showShareText = false
    @State private var showSettings = false
    @State private var privacyShieldActive = false
    @State private var input = ""
    @State private var search = ""
    @State private var appliedSearch = ""
    @State private var sidebarSearchTask: Task<Void, Never>?
    @State private var apiKeyInput = ""
    @State private var hasAPIKey = CredentialVault.readAPIKey() != nil
    @AppStorage("preferredAPImodel") private var model = "gpt-4.1-mini"
    @State private var modelOptions: [ModelChoice] = []
    @State private var modelSearch = ""
    @State private var showModelPicker = false
    @State private var showOtherReturnedModels = false
    @State private var showUsage = false
    @State private var branchContext: BranchCreationContext?
    @State private var showBranchVersions = false
    @State private var showDiscardWarning = false
    @State private var pendingRegeneration: UUID?
    @State private var draftSaveTask: Task<Void, Never>?
    @State private var restoringDraft = false
    @State private var loadingModels = false
    @State private var modelLoadError: String?
    @State private var modelFetchID = UUID()
    @State private var activeTask: Task<Void, Never>?
    @State private var activeConversation: UUID?
    @State private var activeRequest: UUID?
    @State private var activeAssistantMessageID: UUID?
    @State private var generationStatus: String?
    @State private var requestError: String?
    @State private var lastBackendIssue: BackendDiagnostic?
    @State private var confirmDelete = false
    @State private var exportURL: URL?
    @State private var showExport = false
    private let client = OpenAIClient()

    private var selected: LocalConversation? {
        guard let chat = store.conversations.first(where: { $0.id == store.selectedID }) else { return nil }
        // Never feed locked text to SwiftUI's message tree before local auth.
        if chat.isLocked && !privateChatAccess.canRead(chat.id) { return nil }
        return chat
    }
    private var lockedSelection: LocalConversation? {
        guard let chat = store.conversations.first(where: { $0.id == store.selectedID }),
              chat.isLocked, !privateChatAccess.canRead(chat.id) else { return nil }
        return chat
    }
    private var sidebarChats: [LocalConversation] {
        let entries = store.conversations.map { chat in
            ConversationListEntry(id: chat.id, title: chat.isLocked && !privateChatAccess.canRead(chat.id)
                ? "Locked conversation" : chat.title, updatedAt: chat.updatedAt,
                pinned: chat.isPinned, archived: chat.isArchived,
                locked: chat.isLocked && !privateChatAccess.canRead(chat.id),
                searchableText: (appliedSearch.isEmpty ||
                        (chat.isLocked && !privateChatAccess.canRead(chat.id)))
                    ? "" : chat.messages.map(\.text).joined(separator: " "))
        }
        let byID = Dictionary(uniqueKeysWithValues: store.conversations.map { ($0.id, $0) })
        return ConversationListPolicy.visible(entries, filter: sidebarFilter, query: appliedSearch)
            .compactMap { byID[$0.id] }
    }
    private var selectedModelID: String { selected?.modelID ?? model }
    private var selectedModelLabel: String {
        modelOptions.first(where: { $0.id == selectedModelID })?.displayName ?? selectedModelID
    }
    private var isChatGPTPlan: Bool { AuthBillingChoice.route == .chatgptPlan }
    var body: some View {
        ZStack {
        NavigationStack {
            VStack(spacing: 0) {
                if store.startupRecoveryNotice != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "externaldrive.badge.exclamationmark")
                        Text("Saved history needs recovery")
                            .font(.caption)
                        Spacer()
                        Button("Details") { showSettings = true }
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
                ModelAndUsageBar(
                    modelName: selectedModelLabel,
                    isChatGPTPlan: isChatGPTPlan,
                    lastUsage: selected?.lastUsage,
                    lastRateLimits: selected?.lastRateLimits,
                    onModel: { showModelPicker = true },
                    onBranch: { openBranchFromHere(messageID: nil) },
                    onUsage: { showUsage = true }
                )
                if let chat = selected,
                   chat.branchedFrom == nil,
                   store.conversations.contains(where: {
                       $0.branchedFrom?.parentConversationID == chat.id
                   }) {
                    HStack {
                        Label("This chat has alternate branches", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                        Spacer()
                        Button("View branches") { showBranchVersions = true }
                            .font(.caption)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .foregroundColor(.secondary)
                }
                if let chat = selected, chat.branchedFrom != nil {
                    HStack(spacing: 7) {
                        Label(chat.branchMode.displayName, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                        if let origin = chat.branchedFrom,
                           store.conversations.contains(where: { $0.id == origin.parentConversationID }) {
                            Button("Original chat") {
                                store.selectedID = origin.parentConversationID
                            }.font(.caption)
                        }
                        Button("Versions") { showBranchVersions = true }
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .foregroundColor(.secondary)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if selected?.messages.isEmpty != false {
                                Text("What can I help with?")
                                    .font(.system(size: 26, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 160)
                            }
                            ForEach(selected?.messages ?? []) { message in
                                MessageRowView(
                                    message: message,
                                    onCopy: { UIPasteboard.general.string = message.text },
                                    onShare: { shareText = message.text; showShareText = true },
                                    onEdit: {
                                        guard let chat = selected,
                                              let offset = chat.messages.firstIndex(where: { $0.id == message.id }) else { return }
                                        editingContext = MessageEditContext(
                                            messageID: message.id,
                                            conversationID: chat.id,
                                            originalText: message.text,
                                            hasLaterMessages: offset < chat.messages.count - 1,
                                            preservesImage: message.imageDataURL != nil)
                                    },
                                    onRegenerate: { requestRegeneration(messageID: message.id) },
                                    onBranch: { openBranchFromHere(messageID: message.id) },
                                    onReadAloud: {
                                        if voice.speaking { voice.stopSpeaking() }
                                        else { voice.readAloud(message.text) }
                                    },
                                    speaking: voice.speaking,
                                    isStreaming: activeConversation == selected?.id &&
                                        activeAssistantMessageID == message.id
                                )
                            }
                        }.padding(16)
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { _ in
                        // Do not drag the reader back to the bottom while the user
                        // is reviewing earlier messages during streaming.
                        followLatest = false
                    })
                    .onChange(of: selected?.messages.count) { _ in
                        // New turns should appear immediately, but individual SSE
                        // fragments must not trigger full-layout scrolling.
                        guard followLatest, let last = selected?.messages.last else { return }
                        lastAutoScroll = Date()
                        withTransaction(Transaction(animation: nil)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: store.streamingTick) { _ in
                        guard followLatest, let last = selected?.messages.last,
                              Date().timeIntervalSince(lastAutoScroll) >= 0.22 else { return }
                        lastAutoScroll = Date()
                        withTransaction(Transaction(animation: nil)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: selected?.messages.last?.citations.count) { _ in
                        guard followLatest, let last = selected?.messages.last else { return }
                        withTransaction(Transaction(animation: nil)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !followLatest, selected?.messages.isEmpty == false {
                            Button {
                                followLatest = true
                                if let last = selected?.messages.last {
                                    withTransaction(Transaction(animation: nil)) {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            } label: {
                                Label("Latest", systemImage: "arrow.down")
                                    .font(.caption.bold())
                                    .padding(9)
                                    .background(Color(.secondarySystemBackground), in: Capsule())
                            }
                            .padding(12)
                        }
                    }
                }
                if importingDocument {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Reading attachment…").font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }.padding(.horizontal, 18).padding(.bottom, 3)
                }
                if activeTask != nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(generationStatus ?? "Waiting for response…")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.bottom, 3)
                    .accessibilityElement(children: .combine)
                }
                ChatComposerView(
                    input: $input,
                    selectedPhoto: $selectedPhoto,
                    webSearch: $useWebSearch,
                    imageAttached: attachedImage != nil,
                    documentName: importedDocument?.name,
                    modelLabel: selectedModelLabel,
                    isGenerating: activeTask != nil,
                    isRecording: voice.recording,
                    onRemoveImage: { attachedImage = nil },
                    onRemoveDocument: { importedDocument = nil },
                    onCamera: { showCamera = true },
                    onDocument: { showDocumentPicker = true },
                    onModelPicker: { showModelPicker = true },
                    onDictate: {
                        if voice.recording {
                            voice.stopDictation()
                            if !voice.recognizedText.isEmpty {
                                input = [input, voice.recognizedText].filter { !$0.isEmpty }.joined(separator: " ")
                            }
                        } else {
                            Task { await voice.beginDictation() }
                        }
                    },
                    onSend: { send() },
                    onStop: { cancelGeneration() },
                    onNewChat: { store.newChat() },
                    onTemporaryChat: { store.newChat(temporary: true) }
                )
                .onChange(of: input) { newText in
                    guard !restoringDraft else { return }
                    let id = store.selectedID
                    draftSaveTask?.cancel()
                    draftSaveTask = Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled else { return }
                        store.saveDraft(newText, in: id)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { data in
                    if let data = data { attachedImage = data }
                    showCamera = false
                }
            }
            .fileImporter(isPresented: $showDocumentPicker,
                          allowedContentTypes: [.pdf, .plainText, .json]) { result in
                do {
                    let url = try result.get()
                    importingDocument = true
                    Task {
                        defer { importingDocument = false }
                        do {
                            // PDFKit text extraction should not block the chat UI.
                            importedDocument = try await Task.detached(priority: .utility) {
                                try AttachmentTextExtractor.importDocument(from: url)
                            }.value
                        } catch {
                            requestError = "Import failed: \(error.localizedDescription)"
                        }
                    }
                } catch {
                    requestError = "Import failed: \(error.localizedDescription)"
                }
            }
            .onChange(of: store.selectedID) { id in
                draftSaveTask?.cancel()
                // Commit the old draft before swapping the composer. The earlier
                // deferred-save logic silently lost text on rapid navigation.
                if previousConversationID != id,
                   let prior = previousConversationID,
                   let priorChat = store.conversations.first(where: { $0.id == prior }),
                   (!priorChat.isLocked || privateChatAccess.canRead(prior)) {
                    store.saveDraft(input, in: prior)
                }
                previousConversationID = id
                restoringDraft = true
                input = lockedSelection == nil ? store.draft(for: id) : ""
                restoringTools = true
                useWebSearch = selected?.webSearchEnabled ?? false
                DispatchQueue.main.async { restoringTools = false }
                followLatest = true
                DispatchQueue.main.async { restoringDraft = false }
                photoLoadTask?.cancel()
                selectedPhoto = nil
                attachedImage = nil
                importedDocument = nil
            }
            .onAppear {
                ThumbnailCache.configure()
                previousConversationID = store.selectedID
                input = lockedSelection == nil ? store.draft(for: store.selectedID) : ""
                useWebSearch = selected?.webSearchEnabled ?? false
            }
            .onChange(of: useWebSearch) { flag in
                guard !restoringTools, let chat = selected else { return }
                store.setWebSearch(chat.id, flag)
            }
            .onChange(of: privateChatAccess.unlocked) { _ in
                // Unlocking a private chat restores its draft only after Touch ID.
                if lockedSelection == nil, let chat = selected, chat.isLocked {
                    restoringDraft = true
                    input = store.draft(for: chat.id)
                    DispatchQueue.main.async { restoringDraft = false }
                }
            }
            .onChange(of: selectedPhoto) { item in
                photoLoadTask?.cancel()
                attachedImage = nil
                guard let item = item else { return }
                photoLoadTask = Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          data.count <= ImagePreparation.maxSourceBytes,
                          !Task.isCancelled else { return }
                    let compressed = await Task.detached(priority: .userInitiated) {
                        ImagePreparation.jpeg(fromEncodedImageData: data)
                    }.value
                    guard !Task.isCancelled else { return }
                    if let compressed = compressed {
                        attachedImage = compressed
                    } else {
                        requestError = "Could not load photo, or photo is too large."
                    }
                }
            }
            .onChange(of: voice.errorMessage) { error in
                if let error = error { requestError = error; voice.errorMessage = nil }
            }
            .navigationTitle(selected?.isTemporary == true ? "Temporary chat" : "ChatGPT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSidebar = true } label: { Image(systemName: "line.3.horizontal") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New chat") { store.newChat() }
                        Button("Temporary chat") { store.newChat(temporary: true) }
                        Button("Branch into mode/model…") { openBranchFromHere(messageID: nil) }
                    } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .alert("Request failed", isPresented: Binding(
                get: { requestError != nil },
                set: { if !$0 { requestError = nil; lastBackendIssue = nil } })) {
                    if lastBackendIssue?.isPlanLimit == true {
                        Button("View usage") {
                            requestError = nil
                            lastBackendIssue = nil
                            DispatchQueue.main.async { showUsage = true }
                        }
                    }
                    Button("OK", role: .cancel) { requestError = nil; lastBackendIssue = nil }
                } message: { Text(requestError ?? "") }
            .sheet(isPresented: $showSidebar) {
                NavigationStack {
                    List {
                        Picker("View", selection: $sidebarFilter) {
                            ForEach(ConversationListFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }.pickerStyle(.segmented)
                        ForEach(sidebarChats) { chat in
                            Button { store.selectedID = chat.id; showSidebar = false } label: {
                                HStack(spacing: 9) {
                                    if chat.isPinned { Image(systemName: "pin.fill") }
                                    if chat.isLocked && !privateChatAccess.canRead(chat.id) {
                                        Image(systemName: "lock.fill")
                                        Text("Locked conversation").lineLimit(1)
                                    } else {
                                        Text(chat.title).lineLimit(1)
                                    }
                                    if chat.isTemporary { Image(systemName: "eye.slash") }
                                    if chat.branchedFrom != nil {
                                        Image(systemName: "arrow.triangle.branch")
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    privateChatAccess.revoke(chat.id)
                                    store.delete(chat.id)
                                }
                                Button(chat.isArchived ? "Restore" : "Archive") {
                                    store.setArchived(chat.id, !chat.isArchived)
                                }.tint(.orange)
                            }
                            .contextMenu {
                                Button(chat.isPinned ? "Unpin" : "Pin") {
                                    store.setPinned(chat.id, !chat.isPinned)
                                }
                                Button(chat.isArchived ? "Restore" : "Archive") {
                                    store.setArchived(chat.id, !chat.isArchived)
                                }
                                Button(chat.isLocked ? "Remove local lock" : "Lock this chat") {
                                    Task {
                                        // Require Touch ID/passcode even to disable an existing lock.
                                        if await privateChatAccess.authenticate(chat.id) {
                                            store.setLocked(chat.id, !chat.isLocked)
                                            // Lock immediately; never leave this chat open after enabling.
                                            privateChatAccess.revoke(chat.id)
                                        }
                                    }
                                }
                                if !chat.isLocked || privateChatAccess.canRead(chat.id) {
                                    Button("Rename") { renamingChat = chat; renameText = chat.title }
                                }
                            }
                        }
                    }
                    .searchable(text: $search)
                    .onChange(of: search) { term in
                        // Avoid assembling/searching thousands of imported
                        // conversations for *every keystroke* on old devices.
                        sidebarSearchTask?.cancel()
                        if term.isEmpty { appliedSearch = ""; return }
                        sidebarSearchTask = Task {
                            try? await Task.sleep(nanoseconds: 220_000_000)
                            guard !Task.isCancelled else { return }
                            appliedSearch = term
                        }
                    }.navigationTitle("Chats")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showSidebar = false }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                // Avoid presenting Settings on top of the already
                                // presented Chats sheet (unreliable on iOS 16).
                                showSidebar = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    showSettings = true
                                }
                            } label: { Image(systemName: "gearshape") }
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareText) {
                if let shareText = shareText { ActivityShareSheet(items: [shareText]) }
            }
            .alert("Rename chat", isPresented: Binding(
                get: { renamingChat != nil },
                set: { if !$0 { renamingChat = nil } }
            )) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    if let chat = renamingChat { store.rename(chat.id, title: renameText) }
                    renamingChat = nil
                }
                Button("Cancel", role: .cancel) { renamingChat = nil }
            }
            .confirmationDialog("Regenerate this earlier response?", isPresented: $showDiscardWarning,
                                titleVisibility: .visible) {
                Button("Discard later messages and regenerate", role: .destructive) {
                    if let id = pendingRegeneration { performRegeneration(id) }
                    pendingRegeneration = nil
                }
                Button("Cancel", role: .cancel) { pendingRegeneration = nil }
            } message: { Text("Later messages in this chat will be removed.") }
            .sheet(item: $editingContext) { context in
                MessageEditorSheet(
                    context: context,
                    onSave: { updatedText in applyEdit(context, text: updatedText) },
                    onCancel: { editingContext = nil }
                )
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    Form {
                        Section("ChatGPT account") {
                            if let session = chatGPTSignIn.session {
                                Text(session.email ?? "Connected account")
                                Text(session.canUsePlan ? "ChatGPT plan permission granted" : "Plan permission not granted")
                                    .font(.footnote).foregroundColor(.secondary)
                                if session.canUsePlan && AuthBillingChoice.route != .chatgptPlan {
                                    Button("Use ChatGPT plan") {
                                        // Switching billing routes must not destroy the other
                                        // working account or discard its OAuth refresh token.
                                        cancelGeneration()
                                        AuthBillingChoice.select(.chatgptPlan)
                                        modelOptions = []
                                        fetchModels()
                                    }
                                }
                                if hasAPIKey && AuthBillingChoice.route != .apiKey {
                                    Button("Use my API key instead") {
                                        cancelGeneration()
                                        AuthBillingChoice.select(.apiKey)
                                        modelOptions = []
                                        fetchModels()
                                    }
                                }
                                Text(AuthBillingChoice.route == .chatgptPlan
                                     ? "Billing: ChatGPT plan (when authorized)"
                                     : "Billing: your API key")
                                    .font(.footnote).foregroundColor(.secondary)
                                Button("Sign out locally") {
                                    cancelGeneration()
                                    chatGPTSignIn.signOut()
                                }
                                Button("Disconnect and revoke session", role: .destructive) {
                                    cancelGeneration()
                                    Task { await chatGPTSignIn.disconnect() }
                                }.disabled(chatGPTSignIn.busy)
                            }
                            if chatGPTSignIn.session == nil || chatGPTSignIn.pendingAccountSwitch {
                                Button(chatGPTSignIn.busy ? "Opening OpenAI sign-in…" : "Continue with ChatGPT") {
                                    Task { await chatGPTSignIn.signIn() }
                                }.disabled(chatGPTSignIn.busy)
                            }
                            if chatGPTSignIn.session == nil && hasAPIKey &&
                               AuthBillingChoice.route == .chatgptPlan {
                                Button("Use my API key instead") {
                                    AuthBillingChoice.select(.apiKey)
                                    modelOptions = []
                                    fetchModels()
                                }
                                Text("This explicitly changes billing to your API account.")
                                    .font(.footnote).foregroundColor(.secondary)
                            }
                            if chatGPTSignIn.busy {
                                Text(chatGPTSignIn.phase)
                                    .font(.footnote).foregroundColor(.secondary)
                                Button("Cancel sign-in") { chatGPTSignIn.cancelSignIn() }
                            }
                            if chatGPTSignIn.session == nil || chatGPTSignIn.pendingAccountSwitch {
                                ForEach(ChatGPTSessionVault.registrations()) { account in
                                    Button("Reconnect: \(account.email ?? "Account …\(account.subject.suffix(6))")") {
                                        chatGPTSignIn.selectSavedAccount(account)
                                    }.disabled(chatGPTSignIn.busy)
                                }
                            }
                            Button("Switch ChatGPT account") {
                                cancelGeneration()
                                chatGPTSignIn.switchAccount()
                            }
                                .disabled(chatGPTSignIn.busy)
                            if let message = chatGPTSignIn.message {
                                Text(message).font(.footnote).foregroundColor(.secondary)
                            }
                            Text("Unofficial open-source client. OpenAI's sign-in page handles Google and passkeys when available. iOS 16 loopback browser behavior remains unverified on a real device.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        Section("API key fallback") {
                            SecureField("OpenAI API key", text: $apiKeyInput)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("Save API key to Keychain") {
                                hasAPIKey = CredentialVault.saveAPIKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
                                // Typing an API key while signed out is an explicit
                                // billing choice; merely saving a backup API key
                                // while ChatGPT is connected does NOT switch routes.
                                if hasAPIKey && chatGPTSignIn.session == nil {
                                    AuthBillingChoice.select(.apiKey)
                                }
                                apiKeyInput = ""
                            }
                            Text(hasAPIKey ? "Key stored on device" : "No API key stored")
                                .font(.footnote).foregroundColor(.secondary)
                            Button("Remove API key", role: .destructive) {
                                CredentialVault.deleteAPIKey(); hasAPIKey = false
                            }
                            Button("Select model: \(selectedModelLabel)") {
                                showSettings = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    showModelPicker = true
                                }
                            }
                            Text("API models are separate from ChatGPT app model choices.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        Section("Authentication diagnostics") {
                            Button("Test local callback listener") {
                                Task { await chatGPTSignIn.testLoopback() }
                            }.disabled(chatGPTSignIn.busy)
                            if let result = chatGPTSignIn.loopbackDiagnostic {
                                Text(result).font(.footnote).textSelection(.enabled)
                            }
                            Text("A passing foreground callback test does not prove Google or passkey authentication works through Safari on iOS 16.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        if let notice = store.startupRecoveryNotice {
                            Section("Saved-history recovery") {
                                Text(notice)
                                    .font(.footnote)
                                    .textSelection(.enabled)
                                if let recoveryFile = store.recoveryFileURL {
                                    Button("Export preserved original file") {
                                        Task {
                                            guard await privateChatAccess.authorizeSensitiveExport() else {
                                                requestError = "Device authentication required to export recovered history."
                                                return
                                            }
                                            guard FileManager.default.fileExists(atPath: recoveryFile.path) else {
                                                requestError = "Preserved history file could not be found."
                                                return
                                            }
                                            exportURL = recoveryFile
                                            showExport = true
                                        }
                                    }
                                }
                                Text("The app will not silently overwrite unreadable history. Keep the preserved file until you verify recovery.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Section("Security") {
                            if appLock.enabled {
                                Button("Disable app lock") { appLock.enabled = false }
                            } else {
                                Button("Enable Touch ID / passcode app lock") {
                                    Task { await appLock.enableAfterAuthentication() }
                                }
                            }
                            Text("Local device authentication, not an OpenAI account passkey.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        Section("Privacy") {
                            Text("Long-press a conversation in Chats to pin, archive, or protect it with Touch ID/passcode. Locked chat contents are hidden from sidebar search.")
                                .font(.footnote).foregroundColor(.secondary)
                            Text("API requests use store=false. History is saved locally.")
                                .font(.footnote)
                            Button("Delete all local conversations", role: .destructive) { confirmDelete = true }
                        }
                        Section("Data portability") {
                            Button(importingHistory ? "Importing history…" : "Import ChatGPT history (conversations.json)") {
                                showHistoryImporter = true
                            }.disabled(importingHistory)
                            if let result = historyImportMessage {
                                Text(result).font(.footnote).foregroundColor(.secondary)
                            }
                            Text("Import your own ChatGPT data export: unzip it in Files, then choose conversations.json. This is an offline import, not live account syncing.")
                                .font(.footnote).foregroundColor(.secondary)
                            Button("Export local conversations (JSON)") {
                                Task {
                                    // Do not leak private-chat content through data export
                                    // merely because the device is already unlocked.
                                    if store.conversations.contains(where: { $0.isLocked }) {
                                        guard await privateChatAccess.authorizeSensitiveExport() else {
                                            requestError = "Touch ID/passcode required to export protected chats."
                                            return
                                        }
                                    }
                                    guard let data = store.exportData() else { return }
                                    let file = FileManager.default.temporaryDirectory
                                        .appendingPathComponent("chatgpt-local-export-\(UUID().uuidString).json")
                                    do {
                                        try data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
                                        exportURL = file
                                        showExport = true
                                    } catch { requestError = "Unable to export conversations." }
                                }
                            }
                            Text("Exported files contain your messages. Share only with trusted destinations.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        Section("Voice") {
                            Text("Dictation uses iOS Speech Recognition. Read-aloud uses Apple's system voices. These are not ChatGPT realtime voice sessions.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        Section("About") { Text("Native iOS 16 Reconstruction · Stabilization V22") }
                    }
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showSettings = false }
                        }
                    }
                    .confirmationDialog("Delete all local conversations?", isPresented: $confirmDelete) {
                        Button("Delete all", role: .destructive) {
                            cancelGeneration()
                            store.deleteAll()
                        }
                    }
            .fileImporter(isPresented: $showHistoryImporter,
                          allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    importingHistory = true
                    historyImportMessage = "Reading your export…"
                    Task {
                        do {
                            // 64 MB JSON may take seconds to parse. Avoid
                            // blocking the sidebar/composer and animation loop.
                            let parsed = try await Task.detached(priority: .utility) {
                                let scoped = url.startAccessingSecurityScopedResource()
                                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                                guard bytes <= ChatGPTHistoryImporter.maxBytes else {
                                    throw HistoryImportError.tooLarge
                                }
                                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                                return try ChatGPTHistoryImporter.parse(data)
                            }.value
                            let added = store.mergeChatGPTExport(parsed)
                            historyImportMessage = "Imported \(added) conversations (\(parsed.count - added) already imported)."
                        } catch {
                            historyImportMessage = "Could not import history: \(error.localizedDescription)"
                        }
                        importingHistory = false
                    }
                } catch {
                    historyImportMessage = "Could not import history: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $showExport, onDismiss: {
                if let url = exportURL, url != store.recoveryFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                exportURL = nil
            }) {
                if let url = exportURL { ActivityShareSheet(items: [url]) }
            }
                }
            }
        }
        if privacyShieldActive {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 38))
                Text("Private content hidden")
                    .font(.subheadline.weight(.semibold))
            }.accessibilityLabel("App content hidden while inactive")
        }
        if let locked = lockedSelection {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill").font(.system(size: 48))
                Text("Private conversation").font(.title2.bold())
                Text("This conversation needs local Touch ID or passcode authentication.")
                    .font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                Button("Unlock private conversation") {
                    Task { await privateChatAccess.authenticate(locked.id) }
                }.buttonStyle(.borderedProminent)
                Button("Go to a new chat") { store.newChat() }.buttonStyle(.bordered)
                if let error = privateChatAccess.error {
                    Text(error).font(.caption).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
            }
        }
        if appLock.enabled && !appLock.unlocked {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield").font(.system(size: 48))
                Text("ChatGPT is locked").font(.title2.bold())
                Button("Unlock with Touch ID or passcode") {
                    Task { await appLock.unlock() }
                }.buttonStyle(.borderedProminent)
                if let error = appLock.errorMessage {
                    Text(error).font(.footnote).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
            }
        }
        }
        .sheet(isPresented: $showUsage) {
            UsageInfoSheet(
                isChatGPTPlan: isChatGPTPlan,
                lastUsage: selected?.lastUsage,
                lastRateLimits: selected?.lastRateLimits)
        }
        .sheet(isPresented: $showBranchVersions) {
            BranchVersionsSheet(
                currentID: store.selectedID,
                conversations: store.conversations,
                onChoose: { id in
                    // Conversation switch retains per-chat drafts via the existing
                    // onChange handler. Never alter the parent or branch messages.
                    store.selectedID = id
                    showBranchVersions = false
                },
                onClose: { showBranchVersions = false }
            )
        }
        .sheet(item: $branchContext) { context in
            BranchCreateSheet(context: context, models: modelOptions,
                              onCreate: { mode, chosenModel, effort, temporary in
                guard store.branch(from: context.conversationID, at: context.messageID,
                                   mode: mode, modelID: chosenModel,
                                   reasoning: effort, temporary: temporary) != nil else {
                    requestError = "The selected message is no longer available."
                    branchContext = nil
                    return
                }
                branchContext = nil
                followLatest = true
            }, onCancel: { branchContext = nil })
        }
        .sheet(isPresented: $showModelPicker) {
            NavigationStack {
                List {
                    Section("Current model") {
                        Text(selectedModelLabel).font(.headline)
                        Text(selectedModelID).font(.caption).foregroundColor(.secondary)
                        Text("Model selection is independent of temporary chat, image, and web-search switches. The server still enforces model and tool access.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Section(header: Text(AuthBillingChoice.route == .chatgptPlan
                                         ? "Models returned for your ChatGPT account"
                                         : "Models returned for your API key")) {
                        if loadingModels { ProgressView("Fetching models…") }
                        if !modelOptions.isEmpty && !modelOptions.contains(where: { $0.id == selectedModelID }) {
                            Text("Your current selection is not in this account's returned model catalog. It remains selected until you change it; requests may be rejected by the server.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        if let error = modelLoadError {
                            Text(error).font(.footnote).foregroundColor(.secondary)
                        }
                        ForEach(ModelCatalog.filtered(modelOptions, query: modelSearch,
                                                      showOther: showOtherReturnedModels)) { choice in
                            Button {
                                chooseModel(choice.id)
                                showModelPicker = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(choice.displayName)
                                        if choice.displayName != choice.id {
                                            Text(choice.id).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if !choice.isListed {
                                        Text("Other").font(.caption2).foregroundColor(.secondary)
                                    }
                                    if choice.id == selectedModelID { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                    Section("Advanced") {
                        Toggle("Show other models returned by server", isOn: $showOtherReturnedModels)
                        Text("Some returned models are not listed for normal display and might be unsupported. This toggle only changes what you see, not what your account is authorized to use.")
                            .font(.footnote).foregroundColor(.secondary)
                        NavigationLink("Enter a model ID manually") {
                            ManualModelEntry(current: selectedModelID) { chosen in
                                chooseModel(chosen)
                                showModelPicker = false
                            }
                        }
                    }
                    Section {
                        Text("The model list is a catalog, not an entitlement check. Server-side availability and tool compatibility still apply; your selection will not be silently replaced.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                .searchable(text: $modelSearch)
                .navigationTitle("Choose model")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Refresh") { fetchModels() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showModelPicker = false }
                    }
                }
                .onAppear { if modelOptions.isEmpty { fetchModels() } }
            }
        }
        .onChange(of: chatGPTSignIn.session?.clientID) { _ in
            modelOptions = []
            modelLoadError = nil
            // New accounts must not reuse a previous account's model catalog.
            // Invalidate any in-flight fetch even if login is still busy.
            modelFetchID = UUID()
            if !chatGPTSignIn.busy { fetchModels() }
        }
        .onChange(of: chatGPTSignIn.busy) { busy in
            // Account commit occurs while the login Task still owns busy=true.
            // Load models once the account transaction completes.
            if !busy && chatGPTSignIn.session?.canUsePlan == true {
                fetchModels()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                privacyShieldActive = false
                restoringDraft = true
                input = lockedSelection == nil ? store.draft(for: store.selectedID) : ""
                DispatchQueue.main.async { restoringDraft = false }
            }
            if phase != .active {
                // Clear decrypted thumbnails/parsed message content on app switch.
                ThumbnailCache.clear()
                MarkdownRenderCache.clear()
                if !chatGPTSignIn.busy { privacyShieldActive = true }
                // Commit the current draft before hiding it. Wiping the composer
                // without this save would lose text on permission dialogs/switching.
                draftSaveTask?.cancel()
                if let chat = selected { store.saveDraft(input, in: chat.id) }
                restoringDraft = true
                input = ""
                // Prevent a response from appearing behind the app-lock overlay.
                cancelGeneration()
                privateChatAccess.revokeAll()
                voice.stopDictation()
                voice.stopSpeaking()
                // Do not dismiss the Safari consent screen or lock its host scene
                // while an interactive ChatGPT OAuth transaction is in progress.
                if !chatGPTSignIn.busy {
                    appLock.lock()
                    showSettings = false
                    showSidebar = false
                }
            }
        }
    }

    private func chooseModel(_ id: String) {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 160,
              !normalized.contains(where: { $0.isWhitespace || $0.isNewline }) else { return }
        store.setModel(normalized, in: store.selectedID)
        model = normalized // default for newly created chats
    }

    private func fetchModels() {
        // A previous account's model lookup must never overwrite a newer
        // account's catalog, even if its network response arrives last.
        let fetchID = UUID()
        modelFetchID = fetchID
        loadingModels = true
        modelLoadError = nil
        Task {
            do {
                let loaded = try await client.availableModels()
                guard modelFetchID == fetchID else { return }
                modelOptions = loaded
                // Do not silently override the user's chosen model. The
                // catalog is advisory, not a guarantee of access.
            } catch {
                guard modelFetchID == fetchID else { return }
                modelLoadError = error.localizedDescription
            }
            if modelFetchID == fetchID { loadingModels = false }
        }
    }

    private func openBranchFromHere(messageID: UUID?) {
        guard activeTask == nil else {
            requestError = "Stop the current response before branching, so the branch has a complete history."
            return
        }
        guard let chat = selected,
              let count = BranchPlanning.prefixCount(ids: chat.messages.map(\.id),
                                                    through: messageID) else { return }
        // Flush debounced composer text before copying an entire conversation.
        store.saveDraft(input, in: chat.id)
        branchContext = BranchCreationContext(
            conversationID: chat.id, messageID: messageID,
            precedingCount: count, totalCount: chat.messages.count,
            parentTitle: chat.title, defaultModelID: chat.modelID ?? model,
            initiallyTemporary: chat.isTemporary)
    }

    private func requestRegeneration(messageID: UUID) {
        guard let chat = selected,
              let index = chat.messages.firstIndex(where: { $0.id == messageID }) else { return }
        if index < chat.messages.count - 1 {
            pendingRegeneration = messageID
            showDiscardWarning = true
        } else {
            performRegeneration(messageID)
        }
    }

    private func performRegeneration(_ messageID: UUID) {
        regenerate(messageID: messageID)
    }

    private func regenerate(messageID: UUID? = nil) {
        guard activeTask == nil, let id = store.selectedID,
              let chat = store.conversations.first(where: { $0.id == id }) else { return }
        if let messageID = messageID {
            guard store.rewindToAssistant(messageID, in: id) else { return }
        } else {
            guard let lastUser = chat.messages.last(where: { $0.role == "user" }) else { return }
            store.editUserMessage(lastUser.id, in: id, text: lastUser.text)
        }
        runResponse(in: id)
    }

    private var hasSelectedCredentials: Bool {
        switch AuthBillingChoice.route {
        case .chatgptPlan: return chatGPTSignIn.session?.canUsePlan == true
        case .apiKey: return CredentialVault.readAPIKey() != nil
        }
    }

    private func runResponse(in conversationID: UUID) {
        guard activeTask == nil,
              let chat = store.conversations.first(where: { $0.id == conversationID }) else { return }
        guard hasSelectedCredentials else {
            requestError = "Select an authorized ChatGPT plan or configure API-key billing in Settings."
            return
        }
        let history = chat.messages
        store.append("", role: "assistant", to: conversationID)
        guard let messageID = store.conversations.first(where: { $0.id == conversationID })?.messages.last?.id else { return }
        activeConversation = conversationID
        generationStatus = "Connecting…"
        activeAssistantMessageID = messageID
        let requestID = UUID()
        activeRequest = requestID
        let chosenModel = chat.modelID ?? model
        let searchEnabled = useWebSearch
        activeTask = Task {
            do {
                try await client.stream(messages: history, model: chosenModel, webSearch: searchEnabled,
                    branchMode: chat.branchMode,
                    reasoningEffort: chat.reasoningEffort,
                    onProgress: { text in
                        await MainActor.run {
                            guard activeConversation == conversationID, activeRequest == requestID else { return }
                            generationStatus = text
                        }
                    },
                    onRateLimits: { snapshot in
                        await MainActor.run {
                            guard activeConversation == conversationID, activeRequest == requestID else { return }
                            store.updateRateLimits(snapshot, in: conversationID)
                        }
                    },
                    onDelta: { delta in
                        await MainActor.run {
                            guard activeConversation == conversationID, activeRequest == requestID else { return }
                            generationStatus = "Writing response…"
                            var tx = Transaction(animation: nil)
                            tx.disablesAnimations = true
                            withTransaction(tx) {
                                store.appendDelta(delta, to: messageID, in: conversationID)
                            }
                        }
                    },
                    onCitation: { citation in
                        await MainActor.run {
                            guard activeConversation == conversationID, activeRequest == requestID else { return }
                            store.addCitation(citation, to: messageID, in: conversationID)
                        }
                    },
                    onUsage: { usage in
                        await MainActor.run {
                            guard activeConversation == conversationID, activeRequest == requestID else { return }
                            store.updateUsage(usage, in: conversationID)
                        }
                    })
            } catch is CancellationError {
            } catch {
                if activeRequest == requestID {
                    let content = store.conversations.first(where: { $0.id == conversationID })?
                        .messages.first(where: { $0.id == messageID })?.text ?? ""
                    if content.isEmpty { store.removeMessage(messageID, in: conversationID) }
                    if case ClientError.diagnostic(let diagnostic) = error {
                        lastBackendIssue = diagnostic
                    }
                    requestError = error.localizedDescription
                }
            }
            if activeRequest == requestID {
                // Some accepted requests complete with no textual message.
                // Never persist a fake, empty assistant turn as chat history.
                discardEmptyActivePlaceholder()
                store.flushStreamingChanges()
                activeTask = nil
                generationStatus = nil
                activeConversation = nil
                activeAssistantMessageID = nil
                activeRequest = nil
            }
        }
    }

    private func discardEmptyActivePlaceholder() {
        guard let id = activeConversation, let assistantID = activeAssistantMessageID,
              let message = store.conversations.first(where: { $0.id == id })?
                  .messages.first(where: { $0.id == assistantID }),
              message.text.isEmpty else { return }
        store.removeMessage(assistantID, in: id)
    }

    private func cancelGeneration() {
        activeTask?.cancel()
        // Stop pressed before the first SSE text delta used to leave a permanent
        // "…" row, which could then pollute the next API request context.
        discardEmptyActivePlaceholder()
        store.flushStreamingChanges()
        activeTask = nil
        generationStatus = nil
        activeConversation = nil
        activeAssistantMessageID = nil
        activeRequest = nil
    }

    private func applyEdit(_ context: MessageEditContext, text: String) {
        // The edit sheet already warned about rewinding a prior turn.
        guard store.conversations.contains(where: { $0.id == context.conversationID }) else {
            editingContext = nil
            return
        }
        cancelGeneration()
        store.editUserMessage(context.messageID, in: context.conversationID, text: text)
        editingContext = nil
        store.selectedID = context.conversationID
        followLatest = true
        runResponse(in: context.conversationID)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!appLock.enabled || appLock.unlocked),
              (!text.isEmpty || attachedImage != nil || importedDocument != nil),
              let conversationID = store.selectedID, activeTask == nil else { return }
        guard hasSelectedCredentials else {
            // Do not consume the draft or add an unsendable message when a
            // session is absent or an API key is not the active billing route.
            requestError = "Sign in or select API-key billing in Settings first."
            return
        }
        var messageText = text
        if let document = importedDocument {
            messageText += "\n\n[Attached document: \(document.name)]\n" + document.text
        }
        let imageURL = attachedImage.map { "data:image/jpeg;base64," + $0.base64EncodedString() }
        followLatest = true
        store.append(messageText, role: "user", to: conversationID, imageDataURL: imageURL)
        draftSaveTask?.cancel()
        store.saveDraft("", in: conversationID)
        input = ""
        attachedImage = nil
        selectedPhoto = nil // same photo can be attached again on the next turn
        importedDocument = nil
        runResponse(in: conversationID)
    }
}


private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
