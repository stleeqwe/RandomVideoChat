import SwiftUI
import Combine
import FirebaseAuth

/// ViewModel for VideoCallView - coordinates all call-related state and logic
@MainActor
class VideoCallViewModel: ObservableObject {
    // MARK: - Published Properties

    // Call state
    @Published var isCallActive = false
    @Published var isCallEnding = false
    @Published var opponentUserId: String = ""

    // Timer (delegated to CallTimerManager)
    @Published var timeRemaining: Int = 5
    @Published var isTimerStarted: Bool = false

    // Heart (delegated to HeartObserverManager)
    @Published var heartCount: Int = 0
    @Published var showHeartAnimation = false

    // Audio/Video controls
    @Published var isMuted = false
    @Published var isCameraOn = true

    // Report/Block
    @Published var showReportAlert = false
    @Published var showBlockAlert = false

    // Error handling
    @Published var showErrorAlert = false
    @Published var errorMessage = ""

    // MARK: - Managers
    let timerManager: CallTimerManager
    let heartManager: HeartObserverManager

    // MARK: - Callbacks
    var onCallEnd: (() -> Void)?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(initialTime: Int = 5) {
        self.timerManager = CallTimerManager(initialTime: initialTime)
        self.heartManager = HeartObserverManager()

        setupBindings()
        setupCallbacks()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind timer manager state
        timerManager.$timeRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: &$timeRemaining)

        timerManager.$isTimerStarted
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTimerStarted)

        // Bind heart manager state
        heartManager.$heartCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$heartCount)

        heartManager.$showHeartAnimation
            .receive(on: DispatchQueue.main)
            .assign(to: &$showHeartAnimation)
    }

    private func setupCallbacks() {
        timerManager.onTimerExpired = { [weak self] in
            self?.endCall()
        }

        timerManager.onTimeUpdated = { [weak self] time in
            MatchingManager.shared.updateCallTimer(time)
        }
    }

    /// Main setup called when view appears
    func setupCall() {
        #if DEBUG
        print("🔴 [VideoCallViewModel] setupCall")
        #endif

        // Stop CameraManager session to avoid conflict with Agora
        CameraManager.shared.stopSession()

        setupCameraState()
        NetworkManager.shared.startMonitoring()

        guard let channelName = KeychainManager.loadString(forKey: .currentChannelName),
              !channelName.isEmpty else {
            #if DEBUG
            print("❌ No channel name - cannot start call")
            #endif
            showError("채널 정보가 없습니다.")
            return
        }

        startVideoCall()
        setupUserData()
        setupOpponentObservation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupCallObservers()
        }
    }

    private func setupCameraState() {
        isCameraOn = UserDefaults.standard.bool(forKey: "isCameraOn")
        if UserDefaults.standard.object(forKey: "isCameraOn") == nil {
            isCameraOn = true
            UserDefaults.standard.set(true, forKey: "isCameraOn")
        }

        if !isCameraOn {
            _ = AgoraManager.shared.toggleCamera()
        }
    }

    private func setupUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        UserManager.shared.loadCurrentUser(uid: uid)
        heartManager.startObserving(userId: uid)

        if let currentHeartCount = UserManager.shared.currentUser?.heartCount {
            heartManager.heartCount = currentHeartCount
        }
    }

    private func setupOpponentObservation() {
        guard let matchedUserId = MatchingManager.shared.matchedUserId else {
            #if DEBUG
            print("❌ [VideoCallViewModel] No matchedUserId")
            #endif
            return
        }

        #if DEBUG
        print("🔴 [VideoCallViewModel] setupOpponentObservation - opponent: \(matchedUserId)")
        #endif

        opponentUserId = matchedUserId
        UserManager.shared.addRecentMatch(matchedUserId)

        MatchingManager.shared.observeOpponentPresence(opponentId: matchedUserId) { [weak self] in
            guard let self = self, !self.isCallEnding else { return }
            self.endCall()
        }

        MatchingManager.shared.observeOpponentCameraStatus(opponentId: matchedUserId) { isOn in
            DispatchQueue.main.async {
                AgoraManager.shared.applyRemoteCameraMuted(!isOn)
            }
        }
    }

    private func setupCallObservers() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            MatchingManager.shared.observeCallTimer { syncedTime in
                self?.timerManager.syncTime(syncedTime)
            }
        }

        func registerCallEndObserver() {
            if let matchId = KeychainManager.loadString(forKey: .currentMatchId), !matchId.isEmpty {
                MatchingManager.shared.observeCallEnd { [weak self] in
                    guard let self = self, !self.isCallEnding else { return }
                    self.cleanup(signalEnd: false)
                    self.onCallEnd?()
                }

                MatchingManager.shared.observeCallStatusEnded { [weak self] in
                    guard let self = self, !self.isCallEnding else { return }
                    self.cleanup(signalEnd: false)
                    self.onCallEnd?()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    registerCallEndObserver()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            registerCallEndObserver()
        }
    }

    // MARK: - Call Management

    private func startVideoCall() {
        isCallActive = true

        guard let channelName = KeychainManager.loadString(forKey: .currentChannelName),
              !channelName.isEmpty else {
            #if DEBUG
            print("❌ No channel name")
            #endif
            return
        }

        #if DEBUG
        print("📺 Starting video call: \(channelName)")
        #endif

        if let userId = Auth.auth().currentUser?.uid {
            MatchingManager.shared.removeFromQueueIfNeeded(userId: userId)
        }

        AgoraManager.shared.startCall(channel: channelName)
    }

    func endCall() {
        cleanup(signalEnd: true)
        onCallEnd?()
    }

    // MARK: - Actions

    func toggleCamera() {
        let isCameraOff = AgoraManager.shared.toggleCamera()
        isCameraOn = !isCameraOff
        MatchingManager.shared.signalCameraStatus(isOn: isCameraOn)
        UserDefaults.standard.set(isCameraOn, forKey: "isCameraOn")
    }

    func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    func addTime() {
        guard heartCount > 0, !opponentUserId.isEmpty else { return }

        heartManager.deductHeart { [weak self] success in
            guard success, let self = self else { return }

            self.timerManager.addTime(60)
            MatchingManager.shared.updateCallTimer(self.timeRemaining)
            self.heartManager.sendHeartToOpponent(self.opponentUserId)
        }
    }

    func reportUser(reason: String) {
        guard !opponentUserId.isEmpty else { return }

        ContentModerationManager.shared.reportUser(reportedUserId: opponentUserId, reason: reason) { [weak self] success in
            if success {
                #if DEBUG
                print("✅ Report submitted: \(reason)")
                #endif
                self?.endCall()
            }
        }
    }

    func blockUser() {
        guard !opponentUserId.isEmpty else { return }

        UserManager.shared.reportAndBlockUser(opponentUserId, reason: "사용자 차단")
        #if DEBUG
        print("✅ User blocked: \(opponentUserId)")
        #endif

        endCall()
    }

    // MARK: - Event Handlers

    func handleRemoteUserJoined(_ joined: Bool) {
        if joined && !isTimerStarted {
            #if DEBUG
            print("✅ Remote user joined - starting timer in 1s")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if AgoraManager.shared.remoteUserJoined && !self.isTimerStarted {
                    self.timerManager.startTimer()
                }
            }
        }
    }

    func handleCallStateChange(_ inCall: Bool) {
        if inCall {
            MatchingManager.shared.signalCameraStatus(isOn: isCameraOn)
        }
    }

    func handleConnectionStateChange(_ state: AgoraConnectionState) {
        if case .failed(let error) = state {
            switch error {
            case .tokenExpired, .tokenInvalid:
                showError("인증이 만료되었습니다.")
            case .networkError:
                // Will retry automatically
                break
            default:
                break
            }
        }
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            timerManager.handleEnterBackground()

        case .active:
            timerManager.handleEnterForeground()

            if AgoraManager.shared.isInCall {
                AgoraManager.shared.agoraKit?.enableLocalVideo(true)
                AgoraManager.shared.agoraKit?.startPreview()
            }

        @unknown default:
            break
        }
    }

    func handleAppTermination() {
        guard !isCallEnding else { return }
        cleanup(signalEnd: true)
    }

    func handleDisappear(isBackground: Bool) {
        if isBackground { return }
        cleanup(signalEnd: true)
    }

    // MARK: - Cleanup

    func cleanup(signalEnd: Bool) {
        guard !isCallEnding else { return }

        isCallEnding = true

        #if DEBUG
        print("📱 Call ending - cleanup started")
        #endif

        // 통화가 실제로 성립했으면 (상대방이 참가했으면) 통화 횟수 증가
        if AgoraManager.shared.remoteUserJoined {
            UserManager.shared.incrementCallCount()
            #if DEBUG
            print("📊 통화 횟수 증가 (preferenceRate 갱신)")
            #endif
        }

        // Timer cleanup
        timerManager.cleanup()

        // Heart observer cleanup
        heartManager.stopObserving()

        // Signal call end
        if signalEnd {
            if let matchId = KeychainManager.loadString(forKey: .currentMatchId) {
                MatchingManager.shared.signalCallEnd(matchId: matchId)
            } else {
                MatchingManager.shared.signalCallEnd()
            }
        }

        MatchingManager.shared.cancelMatching()

        if !signalEnd {
            MatchingManager.shared.callEndedByOpponent = true
        }

        // Agora cleanup
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()

        // Clear sensitive data
        KeychainManager.delete(forKey: .currentChannelName)
        KeychainManager.delete(forKey: .currentMatchId)
    }

    // MARK: - Error Handling

    func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
