import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@available(iOS 15.0, *)
struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false
    @State private var showAppleSignIn = false
    
    var body: some View {
        ZStack {
            // Gradient background
            GradientBackgroundView(style: .purple)

            // Floating particles
            FloatingParticlesView(style: .auth, animationTrigger: $isLoading)

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
                        
                        Text("익명으로 안전하게 시작하기")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 100)
                
                Spacer()
                
                // 로그인 옵션들
                VStack(spacing: 16) {
                    // Apple Sign In 버튼
                    Button(action: {
                        showAppleSignIn = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.white)
                            
                            Text("Apple로 로그인")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
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
                    
                    // 익명 로그인 버튼
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
                        
                        Text("게스트로 시작")
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
                    
                    // 연령 제한 안내
                    Text("18세 이상만 이용 가능")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 10)
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
        .fullScreenCover(isPresented: $showAppleSignIn) {
            AppleSignInView(isAuthenticated: $isAuthenticated)
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
}

#Preview {
    AuthenticationView(isAuthenticated: .constant(false))
}