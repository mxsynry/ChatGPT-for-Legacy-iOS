import SwiftUI

@main
struct ChatGPTReconstructedApp: App {
    @StateObject private var store = ConversationStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
        }
    }
}
