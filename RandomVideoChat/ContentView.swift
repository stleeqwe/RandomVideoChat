import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var showSplash = true
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    @State private var hasAgreedToTerms = false
    @StateObject private var userManager = UserManager.shared

    var body: some View {
        ZStack {
            if isCheckingAuth {
                // Initial loading screen
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                    )
            } else if showSplash {
                // Splash screen
                if #available(iOS 15.0, *) {
                    SplashView(showSplash: $showSplash)
                } else {
                    Color.black.ignoresSafeArea()
                }
            } else if !isAuthenticated {
                // Onboarding screen for new users
                if #available(iOS 15.0, *) {
                    SignUpView(isAuthenticated: $isAuthenticated)
                } else {
                    Text("iOS 15.0+ required").foregroundColor(.white)
                }
            } else if !hasAgreedToTerms {
                // Terms agreement screen
                if #available(iOS 15.0, *) {
                    TermsAgreementView(hasAgreedToTerms: $hasAgreedToTerms)
                } else {
                    Text("iOS 15.0+ required").foregroundColor(.white)
                }
            } else {
                // Main app for authenticated users who agreed to terms
                if #available(iOS 15.0, *) {
                    MainView()
                } else {
                    Text("iOS 15.0+ required").foregroundColor(.white)
                }
            }
        }
        .onAppear {
            // Clear any existing match data
            UserDefaults.standard.removeObject(forKey: "currentChannelName")
            UserDefaults.standard.removeObject(forKey: "currentMatchId")
            checkAuthStatus()
        }
        .onReceive(userManager.$currentUser) { user in
            // React to user authentication state changes
            DispatchQueue.main.async {
                if let user = user {
                    self.isAuthenticated = true
                    self.hasAgreedToTerms = user.hasAgreedToTerms
                } else if !self.isCheckingAuth {
                    self.isAuthenticated = false
                    self.hasAgreedToTerms = false
                }
            }
        }
    }

    func checkAuthStatus() {
        // Check if this is a fresh install (after app deletion)
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if !hasLaunchedBefore {
            // First launch after fresh install - clear any lingering auth state
            print("🆕 Fresh install detected - clearing auth state")
            do {
                try Auth.auth().signOut()
            } catch {
                print("❌ Error signing out: \(error)")
            }
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            isAuthenticated = false
            hasAgreedToTerms = false
            isCheckingAuth = false
            return
        }

        // Check for existing authenticated user
        if let user = Auth.auth().currentUser {
            print("✅ Found existing user: \(user.uid) - Auto login")
            UserManager.shared.loadCurrentUser(uid: user.uid)
            isAuthenticated = true
            // hasAgreedToTerms will be updated via onReceive when currentUser is loaded
        } else {
            print("🔑 No authenticated user - Show onboarding")
            isAuthenticated = false
            hasAgreedToTerms = false
        }
        isCheckingAuth = false
    }
}
