import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit

@available(iOS 15.0, *)
struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false
    @State private var currentNonce: String?
    
    var body: some View {
        ZStack {
            // Enhanced dynamic gradient background
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.sRGB, red: 0.02, green: 0.02, blue: 0.08), location: 0.0),
                        .init(color: Color(.sRGB, red: 0.08, green: 0.03, blue: 0.15), location: 0.3),
                        .init(color: Color(.sRGB, red: 0.15, green: 0.05, blue: 0.25), location: 0.6),
                        .init(color: Color(.sRGB, red: 0.05, green: 0.02, blue: 0.12), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Animated mesh gradient overlay
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 0.3, green: 0.1, blue: 0.4).opacity(0.3),
                        Color.clear
                    ]),
                    center: .topTrailing,
                    startRadius: 50,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            
            // Enhanced floating particles with varied animations
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    let size = CGFloat.random(in: 20...100)
                    let opacity = Double.random(in: 0.03...0.08)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(opacity),
                                    Color.white.opacity(opacity * 0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)
                        .position(
                            x: CGFloat.random(in: -size...geometry.size.width + size),
                            y: CGFloat.random(in: -size...geometry.size.height + size)
                        )
                        .blur(radius: CGFloat.random(in: 15...25))
                        .animation(
                            .easeInOut(duration: Double.random(in: 4...8))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: currentNonce
                        )
                }
            }
            
            VStack(spacing: 50) {
                // Modern app branding with enhanced effects
                VStack(spacing: 25) {
                    ZStack {
                        // Multiple layered glow effects
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(.sRGB, red: 0.8, green: 0.3, blue: 1.0),
                                            Color(.sRGB, red: 0.5, green: 0.6, blue: 1.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120 + CGFloat(index * 20), height: 120 + CGFloat(index * 20))
                                .blur(radius: 25 + CGFloat(index * 10))
                                .opacity(0.3 - Double(index) * 0.1)
                        }
                        
                        // Modern app logo with inline implementation
                        ZStack {
                            // Gradient background with multiple layers
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(.sRGB, red: 0.8, green: 0.3, blue: 1.0).opacity(0.6 - Double(index) * 0.2),
                                                Color(.sRGB, red: 0.5, green: 0.6, blue: 1.0).opacity(0.4 - Double(index) * 0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 110 + CGFloat(index * 10), height: 110 + CGFloat(index * 10))
                                    .blur(radius: CGFloat(index * 5))
                            }
                            
                            // Main logo container
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 110, height: 110)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.6),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                            
                            // App name with glow
                            ZStack {
                                Text("5SEC")
                                    .font(.system(size: 27, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blur(radius: 8)
                                
                                Text("5SEC")
                                    .font(.system(size: 27, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.white,
                                                Color(.sRGB, red: 0.9, green: 0.9, blue: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        }
                        .shadow(color: Color(.sRGB, red: 0.6, green: 0.3, blue: 0.9).opacity(0.4), radius: 25, x: 0, y: 12)
                    }
                    
                    VStack(spacing: 8) {
                        Text("5SEC")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(.sRGB, red: 0.9, green: 0.9, blue: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Text("Random Video Chat")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .padding(.top, 100)
                
                Spacer()
                
                // Apple Sign In 버튼
                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    },
                    onCompletion: { result in
                        handleSignIn(result: result)
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 55)
                .padding(.horizontal, 40)
                
                // Modern start button with glassmorphism
                Button(action: {
                    print("익명 로그인 시도")
                    signInAnonymously()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .blur(radius: 6)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                        
                        Text("시작하기")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 32)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color(.sRGB, red: 0.2, green: 0.4, blue: 1.0).opacity(0.6), location: 0.0),
                                        .init(color: Color(.sRGB, red: 0.3, green: 0.5, blue: 1.0).opacity(0.4), location: 0.5),
                                        .init(color: Color(.sRGB, red: 0.4, green: 0.6, blue: 1.0).opacity(0.7), location: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color(.sRGB, red: 0.3, green: 0.5, blue: 1.0).opacity(0.4), radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 25)
            }
            
            // 로딩 인디케이터
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
    }
    
    // 익명 로그인 함수
    func signInAnonymously() {
        isLoading = true
        
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("❌ 익명 로그인 실패: \(error)")
                self.isLoading = false
                return
            }
            
            print("✅ 익명 로그인 성공!")
            print("User ID: \(authResult?.user.uid ?? "")")
            
            // 사용자 정보 저장 - loadCurrentUser 사용
            if let user = authResult?.user {
                UserManager.shared.loadCurrentUser(uid: user.uid)
            }
            
            self.isAuthenticated = true
            self.isLoading = false
        }
    }
    
    // Nonce 생성 함수
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
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
    
    // SHA256 해시 함수
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Sign In 처리
    func handleSignIn(result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authResults):
            switch authResults.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                
                guard let nonce = currentNonce else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("Unable to fetch identity token")
                    isLoading = false
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                    isLoading = false
                    return
                }
                
                // Firebase 인증
                let credential = OAuthProvider.credential(
                    withProviderID: "apple.com",
                    idToken: idTokenString,
                    rawNonce: nonce
                )
                
                Auth.auth().signIn(with: credential) { (authResult, error) in
                    if let error = error {
                        print("Firebase 로그인 에러: \(error.localizedDescription)")
                        isLoading = false
                        return
                    }
                    
                    print("Firebase 로그인 성공!")
                    print("User ID: \(authResult?.user.uid ?? "")")
                    
                    // 사용자 정보 저장
                    saveUserData(authResult?.user)
                    
                    isAuthenticated = true
                    isLoading = false
                }
                
            default:
                break
            }
            
        case .failure(let error):
            print("Apple Sign In 실패: \(error)")
            isLoading = false
        }
    }
    
    // 사용자 데이터 저장
    func saveUserData(_ user: FirebaseAuth.User?) {
        guard let user = user else { return }
        
        // UserManager를 통해 Firestore에 저장 - loadCurrentUser 사용
        UserManager.shared.loadCurrentUser(uid: user.uid)
    }
}

#Preview {
    AuthenticationView(isAuthenticated: .constant(false))
}