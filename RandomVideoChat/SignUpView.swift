import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@available(iOS 15.0, *)
struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @State private var showAgeVerification = false
    @State private var birthDate = Date()
    @State private var showAgeError = false
    @State private var currentCredential: AuthCredential?
    @State private var isLoading = false
    @State private var authController: ASAuthorizationController?
    @State private var authCoordinator: AppleSignInCoordinator?
    
    private let minimumAge = 18
    
    var body: some View {
        ZStack {
            // SplashView와 동일한 배경
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
                
                // Very subtle radial accent
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
                // 상단 로고 및 타이틀
                VStack(spacing: 30) {
                    // 5SEC 로고
                    VStack(spacing: -50) {
                        Text("5")
                            .font(.custom("Carter One", size: 120))
                            .foregroundColor(.white)
                        Text("SEC")
                            .font(.custom("Carter One", size: 32))
                            .foregroundColor(.white)
                    }
                    
                    Text("Welcome!")
                        .font(.custom("Carter One", size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 80)
                
                Spacer()
                
                // 회원가입 옵션들
                VStack(spacing: 20) {
                    if !showAgeVerification {
                        // Apple Sign In 버튼
                        Button(action: {
                            handleAppleSignInRequest()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "apple.logo")
                                    .font(.custom("GoogleSansCode", size: 18).weight(.semibold))
                                    .foregroundStyle(Color.white)
                                
                                Text("Sign in with Apple")
                                    .font(.custom("GoogleSansCode", size: 19).weight(.bold))
                                    .foregroundStyle(Color.white)
                            }
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                            .background(
                                .black.opacity(0.8),
                                in: RoundedRectangle(cornerRadius: 32)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 게스트 로그인 버튼 (작게)
                        HStack {
                            Spacer()
                            Button(action: {
                                proceedAsGuest()
                            }) {
                                Text("Continue as Guest")
                                    .font(.custom("GoogleSansCode", size: 12).weight(.medium))
                                    .foregroundStyle(Color.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Color.gray.opacity(0.3),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            Spacer()
                        }
                        
                    } else {
                        // 연령 확인 화면
                        ageVerificationView
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
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
        .alert("Age Restriction", isPresented: $showAgeError) {
            Button("OK") {
                showAgeVerification = false
                currentCredential = nil
            }
        } message: {
            Text("You must be 18 or older to use 5SEC.")
        }
    }
    
    // MARK: - 연령 확인 뷰
    private var ageVerificationView: some View {
        VStack(spacing: 30) {
            // 5SEC 브랜딩
            VStack(spacing: -50) {
                Text("5")
                    .font(.custom("Carter One", size: 120))
                    .foregroundColor(.white)
                Text("SEC")
                    .font(.custom("Carter One", size: 32))
                    .foregroundColor(.white)
            }
            .padding(.top, 40)
            
            Text("생년월일 확인")
                .font(.custom("GoogleSansCode", size: 24).weight(.bold))
                .foregroundColor(.white)
                .padding(.top, 60)
            
            // 생년월일 선택기
            DatePicker(
                "생년월일",
                selection: $birthDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
            
            // 버튼들
            VStack(spacing: 16) {
                Button(action: verifyAge) {
                    Text("Confirm")
                        .font(.custom("GoogleSansCode", size: 18).weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(.sRGB, red: 0.2, green: 0.4, blue: 1.0),
                                    Color(.sRGB, red: 0.4, green: 0.6, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                }
                
                Button(action: {
                    showAgeVerification = false
                    currentCredential = nil
                }) {
                    Text("Cancel")
                        .font(.custom("GoogleSansCode", size: 16).weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Apple Sign In Functions
    private func handleAppleSignInRequest() {
        #if targetEnvironment(simulator)
        print("⚠️ Apple Sign In은 시뮬레이터에서 지원되지 않습니다. 실제 디바이스에서 테스트해주세요.")
        // 시뮬레이터에서는 게스트 로그인으로 대체
        proceedAsGuest()
        return
        #endif
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Coordinator와 Controller를 State로 유지
        let coordinator = AppleSignInCoordinator(
            onSuccess: { credential in
                DispatchQueue.main.async {
                    self.currentCredential = credential
                    self.showAgeVerification = true
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    print("❌ Apple Sign In 실패: \(error.localizedDescription)")
                }
            }
        )
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        
        // State에 저장하여 메모리에서 해제되지 않도록 함
        authCoordinator = coordinator
        authController = controller
        
        controller.performRequests()
    }
    
    private func verifyAge() {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        let age = ageComponents.year ?? 0
        
        if age >= minimumAge {
            // 연령 요건 충족 - Firebase 로그인 진행
            proceedWithFirebaseSignIn()
        } else {
            // 연령 미달
            showAgeError = true
        }
    }
    
    private func proceedWithFirebaseSignIn() {
        guard let credential = currentCredential else {
            print("❌ 저장된 자격 증명이 없습니다")
            return
        }
        
        isLoading = true
        
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                print("❌ Firebase 로그인 실패: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            print("✅ Apple Sign In 및 연령 확인 완료!")
            
            // 사용자 정보 저장
            if let user = authResult?.user {
                saveUserInfo(user: user, birthDate: birthDate)
            }
            
            self.isAuthenticated = true
            self.isLoading = false
        }
    }
    
    private func saveUserInfo(user: FirebaseAuth.User, birthDate: Date) {
        let db = Firestore.firestore()
        
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "birthDate": Timestamp(date: birthDate),
            "ageVerified": true,
            "heartCount": 3,
            "blockedUsers": [],
            "createdAt": Timestamp(date: Date()),
            "authProvider": "apple.com"
        ]
        
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("❌ 사용자 정보 저장 실패: \(error.localizedDescription)")
            } else {
                print("✅ 사용자 정보 저장 완료")
                UserManager.shared.loadCurrentUser(uid: user.uid)
            }
        }
    }
    
    private func proceedAsGuest() {
        isLoading = true
        
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("❌ 익명 로그인 실패: \(error)")
                self.isLoading = false
                return
            }
            
            print("✅ 게스트 로그인 성공!")
            
            // 사용자 정보 저장
            if let user = authResult?.user {
                UserManager.shared.loadCurrentUser(uid: user.uid)
            }
            
            self.isAuthenticated = true
            self.isLoading = false
        }
    }
}

// MARK: - Apple Sign In Coordinator
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let onSuccess: (AuthCredential) -> Void
    private let onFailure: (Error) -> Void
    
    init(onSuccess: @escaping (AuthCredential) -> Void, onFailure: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            onFailure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple ID 자격 증명을 가져올 수 없습니다"]))
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            onFailure(NSError(domain: "AppleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Identity Token을 가져올 수 없습니다"]))
            return
        }
        
        // Firebase 자격 증명 생성
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nil
        )
        
        onSuccess(credential)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onFailure(error)
    }
    
    // ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}