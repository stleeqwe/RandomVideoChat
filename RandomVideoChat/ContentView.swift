import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var showSplash = true
    @State private var isAuthenticated = Auth.auth().currentUser != nil
    @State private var isCheckingAuth = true
    
    var body: some View {
        ZStack {
            if isCheckingAuth {
                // 로딩 화면
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                    )
            } else if !isAuthenticated {
                // 로그인 화면
                if #available(iOS 15.0, *) {
                    AuthenticationView(isAuthenticated: $isAuthenticated)
                } else {
                    Text("iOS 15.0+ required").foregroundColor(.white)
                }
            } else if showSplash {
                // 스플래시 화면
                if #available(iOS 15.0, *) {
                    SplashView(showSplash: $showSplash)
                } else {
                    Color.black.ignoresSafeArea()
                }
            } else {
                // 메인 화면
                if #available(iOS 15.0, *) {
                    MainView()
                } else {
                    Text("iOS 15.0+ required").foregroundColor(.white)
                }
            }
        }
        .onAppear {
            // 임시: 이전 채널 정보 삭제
            UserDefaults.standard.removeObject(forKey: "currentChannelName")
            UserDefaults.standard.removeObject(forKey: "currentMatchId")
            checkAuthStatus()
        }
    }
    
    func checkAuthStatus() {
        // 기존 사용자 확인
        if let user = Auth.auth().currentUser {
            print("✅ 기존 사용자 발견: \(user.uid)")
            UserManager.shared.loadCurrentUser(uid: user.uid)
            isAuthenticated = true
            isCheckingAuth = false
        } else {
            // 자동 익명 로그인
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("❌ 자동 익명 로그인 실패: \(error)")
                    isCheckingAuth = false
                    return
                }
                
                if let user = authResult?.user {
                    print("✅ 자동 익명 로그인 성공: \(user.uid)")
                    // createOrUpdateUser 대신 loadCurrentUser 사용
                    // loadCurrentUser가 내부적으로 문서가 없으면 createUserDocument를 호출함
                    UserManager.shared.loadCurrentUser(uid: user.uid)
                    isAuthenticated = true
                }
                isCheckingAuth = false
            }
        }
    }
}
