import Foundation

@main struct StoreBehaviorMain {
    @MainActor static func main() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("openchat16-storetest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("conversations.json")
        let store = ConversationStore(storageURL: fileURL)
        func check(_ condition: @autoclosure () -> Bool, _ reason: String) {
            if !condition() { fatalError("V22 recovery/store test failed: \(reason)") }
        }
        check(store.conversations.count == 1, "fresh store starts with one chat")
        let id = store.selectedID!
        store.append("Hello", role: "user", to: id)
        store.append("", role: "assistant", to: id)
        let assistantID = store.conversations[0].messages.last!.id
        for index in 0..<150 { store.appendDelta("\(index),", to: assistantID, in: id) }
        check(store.conversations[0].messages.last?.text.hasPrefix("0,1,2") == true,
              "streaming fragments appended in order")
        check(store.streamingTick == 150, "stream tick advances")
        let before = store.conversations[0].messages.last!.text
        store.markInterrupted(assistantID, in: id)
        store.flushStreamingChanges()
        let restored = ConversationStore(storageURL: fileURL)
        check(restored.conversations.first?.messages.last?.text == before, "flush persists all stream deltas")
        check(restored.conversations.first?.messages.last?.isInterrupted == true,
              "interrupted partial reply is marked after relaunch")
        store.setPinned(id, true)
        store.setArchived(id, true)
        store.setLocked(id, true)
        store.setWebSearch(id, true)
        store.saveDraft("unsent", in: id)
        store.flushStreamingChanges()
        let restoredFlags = ConversationStore(storageURL: fileURL)
        let a = restoredFlags.conversations[0]
        check(a.isPinned && a.isArchived && a.isLocked && a.webSearchEnabled,
              "metadata survives reload")
        check(a.draft == "unsent", "draft preserved")
        store.newChat(temporary: true)
        let ephemeral = store.selectedID!
        store.append("This should not persist", role: "user", to: ephemeral)
        store.flushStreamingChanges()
        let afterTemporary = ConversationStore(storageURL: fileURL)
        check(!afterTemporary.conversations.contains(where: { $0.id == ephemeral }),
              "temporary chats omitted from disk")
        store.delete(id)
        store.flushStreamingChanges()
        let afterDelete = ConversationStore(storageURL: fileURL)
        check(afterDelete.conversations.allSatisfy { $0.id != id }, "delete persists")
        // A malformed local file must be preserved, not overwritten by
        // the new-chat initializer. This was unsafe in Stage 21.
        let corruptURL = dir.appendingPathComponent("corrupt.json")
        let corruptBytes = Data("{\"private\":\"keep these bytes\",bad".utf8)
        try corruptBytes.write(to: corruptURL)
        let recoveredStore = ConversationStore(storageURL: corruptURL)
        check(recoveredStore.startupRecoveryNotice != nil, "corrupt history reports recovery")
        check(recoveredStore.conversations.count == 1, "app still opens after corrupt history")
        guard let recoveryURL = recoveredStore.recoveryFileURL else {
            fatalError("corrupt history did not create a recovery file")
        }
        let recoveredBytes = try Data(contentsOf: recoveryURL)
        check(recoveredBytes == corruptBytes,
              "recovered file retains exact original bytes")
        let freshBytes = try Data(contentsOf: corruptURL)
        check(freshBytes != corruptBytes,
              "new history is stored separately from original")
        let afterRestart = ConversationStore(storageURL: corruptURL)
        // Verify actual recovered content, not ambiguous URL-object equality.
        guard let foundRecoveryURL = afterRestart.recoveryFileURL else {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            fatalError("Recovery missing on restart: expected=" +
                       recoveryURL.lastPathComponent +
                       "; directory=" + names.sorted().joined(separator: ", "))
        }
        check(foundRecoveryURL.lastPathComponent == recoveryURL.lastPathComponent,
              "restart locates the same recovered history filename")
        let rediscoveredBytes = try Data(contentsOf: foundRecoveryURL)
        check(rediscoveredBytes == corruptBytes,
              "restart recovery retains the original bytes")
        check(FileManager.default.fileExists(atPath: recoveryURL.path),
              "preserved recovery file still exists")

        // Exercise a path alias, as macOS can expose the same directory via
        // /var and /private/var or through another symlink.
        let aliasDirectory = dir.appendingPathComponent("alias-to-test-folder")
        try FileManager.default.createSymbolicLink(at: aliasDirectory,
                                                   withDestinationURL: dir)
        let aliasURL = aliasDirectory.appendingPathComponent("corrupt.json")
        guard let aliasRecoveredURL = ConversationFileRecovery.mostRecentRecovery(for: aliasURL) else {
            fatalError("Recovery missing when folder is reached through a symlink")
        }
        check(aliasRecoveredURL.lastPathComponent == recoveryURL.lastPathComponent,
              "recovery found through an alias path")
        let aliasBytes = try Data(contentsOf: aliasRecoveredURL)
        check(aliasBytes == corruptBytes,
              "recovery through alias retains exact bytes")
        // A valid file with an unsafe annotation should not destroy its text.
        let unsafe = """
        [{"id":"11111111-1111-4111-8111-111111111111","title":"Old chat",
          "messages":[{"id":"22222222-2222-4222-8222-222222222222",
            "role":"assistant","text":"Keep me","citations":[
              {"url":"javascript:alert(1)","title":"unsafe"}]}],
          "updatedAt":1000}]
        """
        let lossyURL = dir.appendingPathComponent("lossy.json")
        try Data(unsafe.utf8).write(to: lossyURL)
        let sanitizedStore = ConversationStore(storageURL: lossyURL)
        check(sanitizedStore.conversations[0].messages[0].text == "Keep me",
              "invalid citation does not erase entire transcript")
        check(sanitizedStore.conversations[0].messages[0].citations.isEmpty,
              "invalid citation removed")
        // A too-large file is not loaded or overwritten. Use a sparse file
        // to avoid allocating 96 MB in this regression test.
        let oversizedURL = dir.appendingPathComponent("oversized.json")
        check(FileManager.default.createFile(atPath: oversizedURL.path, contents: nil),
              "sparse input created")
        let handle = try FileHandle(forWritingTo: oversizedURL)
        try handle.truncate(atOffset: UInt64(ConversationFileRecovery.maxOnDeviceJSONBytes + 1))
        try handle.close()
        let tooLarge = ConversationStore(storageURL: oversizedURL)
        check(tooLarge.startupRecoveryNotice != nil, "large history reports read-only state")
        check(tooLarge.recoveryFileURL == nil, "large valid file is not moved")
        let largeSize = (try FileManager.default.attributesOfItem(atPath: oversizedURL.path)[.size]
                         as? NSNumber)?.int64Value
        check(largeSize == ConversationFileRecovery.maxOnDeviceJSONBytes + 1,
              "large history never overwritten")
        // A temporary filesystem problem (including iOS Data Protection not
        // allowing file reads yet) must never trigger a quarantine or write.
        let unreadableURL = dir.appendingPathComponent("unreadable.json")
        try FileManager.default.createDirectory(at: unreadableURL,
                                                withIntermediateDirectories: false)
        let unreadableStore = ConversationStore(storageURL: unreadableURL)
        check(unreadableStore.startupRecoveryNotice != nil,
              "unreadable history produces a visible warning")
        check(unreadableStore.recoveryFileURL == nil,
              "unreadable history is not renamed as corrupt")
        unreadableStore.append("local ephemeral text", role: "user")
        let pathAttributes = try FileManager.default.attributesOfItem(atPath: unreadableURL.path)
        check((pathAttributes[.type] as? FileAttributeType) == .typeDirectory,
              "read-only recovery never overwrites the unreadable path")
        print("PASS: Stage 22 conversation-store and recovery checks")
    }
}
