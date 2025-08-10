import SwiftUI
import FirebaseAuth
import AVFoundation

@available(iOS 15.0, *)
struct MainView: View {
    @State private var isCameraOn = true
    @State private var heartCount = 3  // 기본 하트 개수
    @State private var showMatchingView = false
    @StateObject private var userManager = UserManager.shared
    @State private var permissionsGranted = false
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeHint = true
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        ZStack {
            if isCameraOn {
                // 실제 카메라 프리뷰
                CameraPreview(isOn: $isCameraOn)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 카메라 off 상태 기본 프로필 화면
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 200))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            
            // 전체 화면 카메라 오버레이 (상단과 하단에 그라데이션 적용)
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(0.4), location: 0.0),  // 상단 어두움
                    .init(color: Color.black.opacity(0.05), location: 0.25), // 중간 위쪽 밝음
                    .init(color: Color.black.opacity(0.02), location: 0.5),  // 중앙 완전 밝음
                    .init(color: Color.black.opacity(0.05), location: 0.75), // 중간 아래쪽 밝음
                    .init(color: Color.black.opacity(0.7), location: 1.0)    // 하단 어두움
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // 카메라 아이콘과 하트 카운터 (우측 상단)
                    VStack(spacing: 12) {
                        Button(action: {
                            isCameraOn.toggle()
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                            Text("X  \(heartCount)")
                                .font(.custom("Carter One", size: 22))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 30)
                
                // 인터랙티브 스와이프 인디케이터 (중앙 하단)
                VStack(spacing: 16) {
                    // 순차적으로 나타나는 상향 화살표
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "chevron.up")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(showSwipeHint ? 1.0 : 0.3)
                                .scaleEffect(showSwipeHint ? 1.0 : 0.7)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: showSwipeHint
                                )
                        }
                    }
                    .offset(y: swipeOffset)
                    
                    Text("SWIPE UP & START")
                        .font(.custom("Carter One", size: 20))
                        .foregroundColor(.white)
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
