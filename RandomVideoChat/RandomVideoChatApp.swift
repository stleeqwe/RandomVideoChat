import SwiftUI
import FirebaseCore

@main
struct RandomVideoChatApp: App {
    @StateObject private var matchingManager = MatchingManager.shared
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var userManager = UserManager.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(matchingManager)
                .environmentObject(agoraManager)
                .environmentObject(userManager)
        }
    }
}
