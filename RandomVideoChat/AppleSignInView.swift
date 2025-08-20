import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@available(iOS 15.0, *)
struct AppleSignInView: View {
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false
    @State private var showAgeVerification = false
    @State private var birthDate = Date()
    @State private var showAgeError = false
    @State private var currentCredential: AuthCredential?
    
    private let minimumAge = 18
    
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
            }
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 앱 브랜딩
                VStack(spacing: 30) {
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
                .padding(.top, 100)
                
                Spacer()
                
                if !showAgeVerification {
                    // Apple Sign In 버튼
                    VStack(spacing: 20) {
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result: result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 55)
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                    }
                    .padding(.horizontal, 40)
                } else {
                    // 연령 확인 화면
                    ageVerificationView
                }
                
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
    
    private var ageVerificationView: some View {
        VStack(spacing: 30) {
            // 앱 브랜딩
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
                .font(.system(size: 24, weight: .bold))
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
                        .font(.system(size: 18, weight: .semibold))
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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 40)
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ Apple ID 자격 증명을 가져올 수 없습니다")
                return
            }
            
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                print("❌ Identity Token을 가져올 수 없습니다")
                return
            }
            
            // Firebase 자격 증명 생성
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nil
            )
            
            // 자격 증명 저장하고 연령 확인 화면으로
            currentCredential = credential
            showAgeVerification = true
            
        case .failure(let error):
            print("❌ Apple Sign In 실패: \(error.localizedDescription)")
        }
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
}

#Preview {
    AppleSignInView(isAuthenticated: .constant(false))
}