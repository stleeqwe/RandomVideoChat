import SwiftUI
import FirebaseAuth
import AVFoundation

struct MainView: View {
    @State private var isCameraOn = true
    @State private var heartCount = 3  // 기본 하트 개수
    @State private var showMatchingView = false
    @StateObject private var userManager = UserManager.shared
    @State private var permissionsGranted = false
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        ZStack {
            // 실제 카메라 프리뷰
            CameraPreview(isOn: $isCameraOn)
            
            VStack {
                Spacer()
                
                // 하단 UI 요소들
                HStack {
                    Spacer()
                    
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
                    }
                    .padding(.trailing, 20)
                }
                
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
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 20)
                
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
