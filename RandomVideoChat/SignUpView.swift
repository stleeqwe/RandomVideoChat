import SwiftUI
import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

@available(iOS 15.0, *)
struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @State private var birthDate = Date()
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var currentNonce: String?
    
    private let minimumAge = 18
    
    // Computed property to check if birth date is valid (18+)
    private var isValidAge: Bool {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        let age = ageComponents.year ?? 0
        return age >= minimumAge
    }
    
    var body: some View {
        ZStack {
            // Background gradient matching SplashView
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.sRGB, red: 0.03, green: 0.01, blue: 0.08), location: 0.0),
                        .init(color: Color(.sRGB, red: 0.06, green: 0.03, blue: 0.12), location: 0.4),
                        .init(color: Color(.sRGB, red: 0.08, green: 0.04, blue: 0.15), location: 0.8),
                        .init(color: Color(.sRGB, red: 0.04, green: 0.02, blue: 0.09), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 0.2, green: 0.1, blue: 0.3).opacity(0.3),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 60) {
                // Top: 5SEC Logo
                VStack(spacing: -50) {
                    Text("5")
                        .font(.custom("Carter One", size: 120))
                        .foregroundColor(.white)
                    Text("SEC")
                        .font(.custom("Carter One", size: 32))
                        .foregroundColor(.white)
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Middle: Birth Date Input
                VStack(spacing: 24) {
                    Text("Welcome!")
                        .font(.custom("Carter One", size: 24))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        Text("Please enter your birth date")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        DatePicker(
                            "Birth Date",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .frame(height: 44)
                        )
                        
                        if !isValidAge && birthDate < Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date() {
                            Text("You must be 18 or older to use 5SEC")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Bottom: Apple Sign In Button
                VStack(spacing: 20) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.nonce = sha256(nonce)
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 55)
                    .cornerRadius(28)
                    .disabled(!isValidAge)
                    .opacity(isValidAge ? 1.0 : 0.6)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    if !isValidAge {
                        Text("Select a valid birth date to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            
            // Loading indicator
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Apple Sign In Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                showError(message: "Failed to get Apple ID credential")
                return
            }
            
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                showError(message: "Failed to get identity token")
                return
            }
            
            guard let nonce = currentNonce else {
                showError(message: "Invalid authentication state")
                return
            }
            
            // Create Firebase credential with secure nonce
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            signInWithFirebase(credential: credential, appleCredential: appleIDCredential)
            
        case .failure(let error):
            showError(message: "Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func signInWithFirebase(credential: AuthCredential, appleCredential: ASAuthorizationAppleIDCredential) {
        isLoading = true
        
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                self.showError(message: "Firebase sign in failed: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            guard let user = authResult?.user else {
                self.showError(message: "No user returned from authentication")
                self.isLoading = false
                return
            }
            
            // Save user data to Firestore
            self.saveUserToFirestore(user: user, appleCredential: appleCredential) {
                DispatchQueue.main.async {
                    UserManager.shared.loadCurrentUser(uid: user.uid)
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func saveUserToFirestore(user: FirebaseAuth.User, appleCredential: ASAuthorizationAppleIDCredential, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        // First check if user already exists to preserve heartCount
        userRef.getDocument { document, error in
            let existingHeartCount = document?.data()?["heartCount"] as? Int
            
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": user.email ?? "",
                "displayName": user.displayName ?? self.formatPersonName(appleCredential.fullName) ?? "",
                "birthDate": Timestamp(date: self.birthDate),
                "heartCount": existingHeartCount ?? 3, // Keep existing or set to 3 if new
                "ageVerified": true,
                "authProvider": "apple.com",
                "createdAt": document?.exists == true ? (document?.data()?["createdAt"] as? Timestamp ?? Timestamp()) : Timestamp(),
                "updatedAt": Timestamp(),
                "blockedUsers": document?.data()?["blockedUsers"] as? [String] ?? []
            ]
            
            userRef.setData(userData, merge: true) { error in
                if let error = error {
                    print("❌ Failed to save user data: \(error.localizedDescription)")
                } else {
                    print("✅ User data saved successfully")
                }
                completion()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatPersonName(_ personName: PersonNameComponents?) -> String? {
        guard let personName = personName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        return formatter.string(from: personName)
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        isLoading = false
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}