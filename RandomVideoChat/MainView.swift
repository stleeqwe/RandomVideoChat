import SwiftUI
import FirebaseAuth
import AVFoundation

struct MainView: View {
    @State private var isCameraOn = true
    @State private var heartCount = 3  // 기본 하트 개수
    @State private var showMatchingView = false
    @StateObject private var userManager = UserManager.shared
    @State private var permissionsGranted = false
<<<<<<< HEAD
=======
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeHint = true
>>>>>>> fefefa2 (Initial Commit)
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        ZStack {
            // 실제 카메라 프리뷰
            CameraPreview(isOn: $isCameraOn)
            
<<<<<<< HEAD
=======
            // Enhanced gradient overlay with multiple layers
            ZStack {
                // Top gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.6), location: 0.0),
                        .init(color: Color.clear, location: 0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .ignoresSafeArea(edges: .top)
                
                VStack {
                    Spacer()
                    // Bottom gradient with modern curve
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.black.opacity(0.2), location: 0.4),
                            .init(color: Color.black.opacity(0.7), location: 0.8),
                            .init(color: Color.black.opacity(0.9), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 300)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            
>>>>>>> fefefa2 (Initial Commit)
            VStack {
                Spacer()
                
                // 하단 UI 요소들
                HStack {
                    Spacer()
                    
<<<<<<< HEAD
                    // 카메라 ON/OFF 버튼
                    Button(action: {
                        isCameraOn.toggle()
                    }) {
                        Image(systemName: isCameraOn ? "camera.fill" : "camera")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
=======
                    // Modern camera toggle button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isCameraOn.toggle()
                        }
                    }) {
                        ZStack {
                            // Glassmorphism background
                            Circle()
                                .fill(
                                    .ultraThinMaterial,
                                    in: Circle()
                                )
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
                                            lineWidth: 1.5
                                        )
                                )
                                .frame(width: 64, height: 64)
                                .shadow(
                                    color: Color.black.opacity(0.2),
                                    radius: 15,
                                    x: 0,
                                    y: 8
                                )
                            
                            // Icon with subtle glow
                            ZStack {
                                Image(systemName: isCameraOn ? "camera.fill" : "camera")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .blur(radius: 8)
                                
                                Image(systemName: isCameraOn ? "camera.fill" : "camera")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color.white)
                                    .scaleEffect(isCameraOn ? 1.0 : 0.85)
                            }
                        }
>>>>>>> fefefa2 (Initial Commit)
                    }
                    .padding(.trailing, 20)
                }
                
<<<<<<< HEAD
                // 하트 개수 표시
                HStack {
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(heartCount)")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
=======
                // Modern heart counter with glassmorphism
                HStack {
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // Animated heart icon
                        ZStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(.sRGB, red: 1.0, green: 0.4, blue: 0.5),
                                            Color(.sRGB, red: 0.9, green: 0.2, blue: 0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blur(radius: 4)
                                .opacity(0.8)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(.sRGB, red: 1.0, green: 0.4, blue: 0.5),
                                            Color(.sRGB, red: 0.9, green: 0.2, blue: 0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text("\(heartCount)")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
>>>>>>> fefefa2 (Initial Commit)
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 20)
                
<<<<<<< HEAD
                // SWIPE & START 텍스트
                VStack(spacing: 10) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    Text("SWIPE & START")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 50)
=======
                // Modern swipe indicator with enhanced animations
                VStack(spacing: 16) {
                    // Floating chevron with trail effect
                    ZStack {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "chevron.up")
                                .font(.system(size: 24 - CGFloat(index * 4), weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.9 - Double(index) * 0.3),
                                            Color.white.opacity(0.5 - Double(index) * 0.2)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .offset(y: swipeOffset + CGFloat(index * 8))
                                .blur(radius: CGFloat(index))
                        }
                    }
                    .opacity(showSwipeHint ? 1 : 0.6)
                    
                    // Styled action text
                    Text("SWIPE UP TO START")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .tracking(2.5)
                        .opacity(showSwipeHint ? 0.9 : 0.5)
                    
                    // Subtle indicator dots
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 4, height: 4)
                                .scaleEffect(showSwipeHint ? 1 : 0.7)
                                .animation(
                                    .easeInOut(duration: 1.2)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: showSwipeHint
                                )
                        }
                    }
                    .opacity(0.7)
                }
                .padding(.bottom, 70)
                .onAppear {
                    // Enhanced floating animation
                    withAnimation(
                        .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        swipeOffset = -15
                    }
                    
                    // Pulsing hint animation
                    withAnimation(
                        .easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        showSwipeHint.toggle()
                    }
                }
>>>>>>> fefefa2 (Initial Commit)
            }
            
            // 🆕 디버그 정보 (개발용)
            #if DEBUG
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("세션 제외: \(UserManager.shared.getRecentMatchesCount())명")
                            .font(.caption2)
                        
                        let blockedCount = UserManager.shared.currentUser?.blockedUsers.count ?? 0
                        Text("영구 차단: \(blockedCount)명")
                            .font(.caption2)
                    }
                    .padding(5)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.horizontal)
                
                Spacer()
            }
            #endif
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 위로 스와이프 감지
                    if value.translation.height < -50 {
                        print("⬆️ 스와이프 감지 - 매칭 화면 표시")
                        showMatchingView = true
                    }
                }
        )
        .alert(isPresented: $showPermissionAlert) {
            Alert(title: Text("권한 필요"),
                  message: Text(permissionMessage),
                  primaryButton: .default(Text("설정 열기"), action: {
                      openSettings()
                  }),
                  secondaryButton: .cancel(Text("닫기")))
        }
        .onAppear {
            // 권한 요청
            checkPermissions()
            requestPermissions()
            
            // 현재 사용자 데이터 로드
            if let uid = Auth.auth().currentUser?.uid {
                userManager.loadCurrentUser(uid: uid)
            }
        }
        .onReceive(userManager.$currentUser) { user in
            // Firestore에서 가져온 값 우선 사용
            if let user = user {
                heartCount = user.heartCount
                UserDefaults.standard.set(heartCount, forKey: "heartCount")
            } else {
                // Firestore에 데이터가 없으면 UserDefaults 확인
                let saved = UserDefaults.standard.integer(forKey: "heartCount")
                heartCount = saved > 0 ? saved : 3
            }
        }
        // 🆕 중요: fullScreenCover 추가!!!
        .fullScreenCover(isPresented: $showMatchingView) {
            MatchingView(isPresented: $showMatchingView)
        }
    }
    
    func checkPermissions() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus    = AVCaptureDevice.authorizationStatus(for: .audio)

        // 카메라 권한 처리
        switch cameraStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.checkPermissions()
                    } else {
                        self.permissionMessage = "카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                        self.showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            self.permissionMessage = "카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            self.showPermissionAlert = true
        default:
            break
        }

        // 마이크 권한 처리
        switch micStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.permissionMessage = "마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                        self.showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            self.permissionMessage = "마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            self.showPermissionAlert = true
        default:
            break
        }
    }
    
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    
    func requestPermissions() {
        // 카메라 권한
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("📷 카메라 권한: \(granted)")
            if granted {
                checkMicrophonePermission()
            }
        }
    }
    
    func checkMicrophonePermission() {
        // 마이크 권한
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("🎤 마이크 권한: \(granted)")
            DispatchQueue.main.async {
                self.permissionsGranted = granted
            }
        }
    }
}

#Preview {
    MainView()
}
