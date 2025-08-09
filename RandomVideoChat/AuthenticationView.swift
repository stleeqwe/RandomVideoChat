import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit

struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false
    @State private var currentNonce: String?
    
    var body: some View {
        ZStack {
            // 배경
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 50) {
                // 앱 로고/타이틀
                VStack(spacing: 10) {
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("Random")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Video Chat")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
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
                
                // 개발용 테스트 버튼
                Button(action: {
                    print("익명 로그인 시도")
                    signInAnonymously()
                }) {
                    Text("시작하기")  // 텍스트도 변경
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
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
        
        Auth.auth().signInAnonymously { authResult, error in  // [weak self] 제거!
            if let error = error {
                print("❌ 익명 로그인 실패: \(error)")
                self.isLoading = false  // self?가 아닌 self 사용
                return
            }
            
            print("✅ 익명 로그인 성공!")
            print("User ID: \(authResult?.user.uid ?? "")")
            
            // 사용자 정보 저장 - loadCurrentUser 사용
            if let user = authResult?.user {
                UserManager.shared.loadCurrentUser(uid: user.uid)
            }
            
            self.isAuthenticated = true  // self?가 아닌 self 사용
            self.isLoading = false       // self?가 아닌 self 사용
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
