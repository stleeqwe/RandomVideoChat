import SwiftUI
import FirebaseAuth
import AVFoundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var heartCount: Int = 3
    @Published var showMatchingView = false
    @Published var permissionsGranted = false
    @Published var showPermissionAlert = false
    @Published var permissionMessage = ""
    @Published var showSettings = false
    @Published var showDailyRewardAlert = false
    @Published var dailyRewardMessage = ""
    @Published var myGender: Gender?
    @Published var preferredGender: Gender?

    // MARK: - Dependencies

    private let userManager = UserManager.shared
    private let permissionManager = PermissionManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var debugSessionExcludedCount: Int {
        UserManager.shared.getRecentMatchesCount()
    }

    var debugBlockedCount: Int {
        UserManager.shared.currentUser?.blockedUsers.count ?? 0
    }

    var debugPreferenceRate: Double {
        UserManager.shared.currentUser?.preferenceRate ?? 50.0
    }

    var debugTotalCalls: Int {
        UserManager.shared.currentUser?.totalCallCount ?? 0
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        userManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self else { return }
                if let user = user {
                    self.heartCount = user.heartCount
                    self.myGender = user.gender
                    self.preferredGender = user.preferredGender
                } else {
                    self.heartCount = 3
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func onAppear(isMainPreviewOn: Bool) {
        // 로컬 상태를 UserManager의 현재 값으로 초기화
        myGender = userManager.currentUser?.gender
        preferredGender = userManager.currentUser?.preferredGender

        // 현재 사용자 데이터 로드
        if let uid = Auth.auth().currentUser?.uid {
            userManager.loadCurrentUser(uid: uid)
        }

        // 권한 요청
        requestCameraAndMicrophonePermissions()

        // Agora 로컬 프리뷰 중지
        AgoraManager.shared.stopLocalPreviewIfIdle()

        // 카메라 매니저 시작
        if isMainPreviewOn {
            CameraManager.shared.resumeSession()
        }

        // 일일 출석 보상 체크
        DailyRewardManager.shared.checkAndGrantDailyReward { [weak self] granted, message in
            if granted, let message = message {
                DispatchQueue.main.async {
                    self?.dailyRewardMessage = message
                    self?.showDailyRewardAlert = true
                }
            }
        }
    }

    func handleScenePhase(_ phase: ScenePhase, isMainPreviewOn: Bool) {
        switch phase {
        case .active:
            #if DEBUG
            print("📱 ScenePhase: active (main preview on: \(isMainPreviewOn))")
            #endif
            if isMainPreviewOn && !showMatchingView {
                CameraManager.shared.resumeSession()
            }
        case .inactive:
            #if DEBUG
            print("📱 ScenePhase: inactive (no-op)")
            #endif
        case .background:
            #if DEBUG
            print("📱 ScenePhase: background -> stop camera session")
            #endif
            CameraManager.shared.stopSession()
        @unknown default:
            break
        }
    }

    func handleSwipeUp() {
        #if DEBUG
        print("⬆️ 스와이프 감지 - 검증 중...")
        #endif

        if userManager.currentUser?.gender != nil {
            #if DEBUG
            print("✅ 모든 조건 충족 - 매칭 화면 표시")
            #endif
            showMatchingView = true
        } else {
            #if DEBUG
            print("❌ 성별 선택 필요 - 알림 표시")
            #endif
            permissionMessage = "매칭을 시작하려면 먼저 성별을 선택해주세요."
            showPermissionAlert = true
        }
    }

    func updateMyGender(_ gender: Gender) {
        myGender = gender
        userManager.updateGender(gender)
    }

    func updatePreferredGender(_ gender: Gender) {
        if preferredGender == gender {
            preferredGender = nil
            userManager.updatePreferredGender(nil)
        } else {
            preferredGender = gender
            userManager.updatePreferredGender(gender)
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Permission Handling

    func requestCameraAndMicrophonePermissions() {
        // Check if already granted
        if permissionManager.areAllPermissionsGranted() {
            permissionsGranted = true
            return
        }

        // Request all permissions
        permissionManager.requestAllPermissions { [weak self] granted, errorMessage in
            guard let self = self else { return }

            self.permissionsGranted = granted

            if !granted, let message = errorMessage {
                self.permissionMessage = message
                self.showPermissionAlert = true
            }
        }
    }
}
