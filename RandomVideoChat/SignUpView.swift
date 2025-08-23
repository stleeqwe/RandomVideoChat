import SwiftUI
import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

@available(iOS 15.0, *)
struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @State private var selectedYear: Int = 2000  // 기본값을 2000년으로 설정
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var currentNonce: String?
    @State private var showYearPicker = false
    
    private let minimumAge = 18
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    // Computed properties
    private var birthDate: Date {
        let components = DateComponents(year: selectedYear, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var userAge: Int {
        currentYear - selectedYear
    }
    
    private var isValidAge: Bool {
        userAge >= minimumAge
    }
    
    private var minYear: Int {
        currentYear - 100  // 최대 100세까지
    }
    
    private var maxYear: Int {
        currentYear - minimumAge  // 18세 이상만 가능
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
                
                // Middle: Birth Year Input
                VStack(spacing: 24) {
                    Text("Welcome!")
                        .font(.custom("Carter One", size: 24))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        Text("출생연도를 선택해주세요")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Birth Year Button
                        Button(action: {
                            showYearPicker = true
                        }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(selectedYear)년")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("(\(userAge)세)")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                        
                        if !isValidAge {
                            Text("18세 이상만 이용 가능합니다")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Bottom: Apple Sign In Button and Guest Login
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
                    
                    // Guest Login Button (for testing)
                    Button(action: {
                        handleGuestLogin()
                    }) {
                        Text("게스트로 시작하기")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .underline()
                    }
                    .disabled(!isValidAge)
                    .opacity(isValidAge ? 1.0 : 0.5)
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
        .sheet(isPresented: $showYearPicker) {
            YearPickerSheet(selectedYear: $selectedYear, minYear: minYear, maxYear: maxYear, isPresented: $showYearPicker)
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
    
    
    // MARK: - Guest Login
    private func handleGuestLogin() {
        isLoading = true
        
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                self.showError(message: "게스트 로그인 실패: \(error.localizedDescription)")
                return
            }
            
            guard let user = authResult?.user else {
                self.showError(message: "사용자 정보를 가져올 수 없습니다.")
                return
            }
            
            // Save guest user to Firestore
            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "uid": user.uid,
                "displayName": "Guest",
                "birthDate": Timestamp(date: self.birthDate),
                "heartCount": 10, // 게스트에게 더 많은 하트 제공
                "ageVerified": true,
                "authProvider": "anonymous",
                "createdAt": Timestamp(),
                "updatedAt": Timestamp(),
                "blockedUsers": [],
                "isGuest": true
            ]
            
            db.collection("users").document(user.uid).setData(userData) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.showError(message: "사용자 데이터 저장 실패: \(error.localizedDescription)")
                    } else {
                        UserManager.shared.loadCurrentUser(uid: user.uid)
                        self.isAuthenticated = true
                    }
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Year Picker Sheet
@available(iOS 15.0, *)
struct YearPickerSheet: View {
    @Binding var selectedYear: Int
    let minYear: Int
    let maxYear: Int
    @Binding var isPresented: Bool
    
    @State private var tempYear: Int
    
    init(selectedYear: Binding<Int>, minYear: Int, maxYear: Int, isPresented: Binding<Bool>) {
        self._selectedYear = selectedYear
        self.minYear = minYear
        self.maxYear = maxYear
        self._isPresented = isPresented
        self._tempYear = State(initialValue: selectedYear.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("출생연도 선택")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 30)
                    
                    // 현재 나이 표시
                    Text("\(Calendar.current.component(.year, from: Date()) - tempYear)세")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Year Picker
                    Picker("", selection: $tempYear) {
                        ForEach((minYear...maxYear).reversed(), id: \.self) { year in
                            Text("\(year)년")
                                .tag(year)
                                .font(.system(size: 20))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedYear = tempYear
                        isPresented = false
                    }) {
                        Text("완료")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}