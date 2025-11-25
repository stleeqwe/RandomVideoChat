import SwiftUI
import UIKit
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

// MARK: - VideoCallView
/// Production-grade Video Call View
/// Features:
/// - Robust connection state handling
/// - Network quality indicators
/// - Graceful error recovery
/// - Proper lifecycle management
@available(iOS 15.0, *)
struct VideoCallView: View {
    // MARK: - State
    @State private var isCallActive = false
    @State private var timeRemaining = 5
    @State private var isTimerStarted = false
    @State private var timer: Timer?
    @State private var isMuted = false
    @State private var heartCount = 3
    @State private var isCallEnding = false
    @State private var opponentUserId: String = ""
    @State private var showHeartAnimation = false
    @State private var isCameraOn = true
    @State private var heartCountAnimation = false

    // Report/Block states
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var reportReason = ""

    // Error handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    // Background handling
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBackground = false
    @State private var backgroundTerminationWorkItem: DispatchWorkItem?
    @State private var backgroundStartTime: Date?

    // Managers
    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var matchingManager = MatchingManager.shared
    @StateObject private var networkManager = NetworkManager.shared

    @Environment(\.presentationMode) var presentationMode

    // MARK: - Body
    var body: some View {
        ZStack {
            // Remote video (fullscreen)
            remoteVideoLayer

            // Gradient overlay
            gradientOverlay

            // Connection status banner
            connectionStatusBanner

            // Network quality indicator
            networkQualityIndicator

            // Report/Block buttons
            reportBlockButtons

            // PIP and controls (right side)
            pipAndControls

            // Timer (left bottom)
            timerDisplay

            // +60s button (center bottom)
            addTimeButton

            // End call button (right bottom)
            endCallButton
        }
        .onAppear(perform: setupVideoCall)
        .onChange(of: agoraManager.remoteUserJoined, perform: handleRemoteUserJoined)
        .onChange(of: agoraManager.isInCall, perform: handleCallStateChange)
        .onChange(of: agoraManager.connectionState, perform: handleConnectionStateChange)
        .onChange(of: scenePhase, perform: handleScenePhaseChange)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            handleAppTermination()
        }
        .onDisappear(perform: onDisappearTasks)
        .alert("사용자 신고", isPresented: $showReportAlert) {
            reportAlertButtons
        } message: {
            Text("이 사용자를 신고하는 이유를 선택해주세요.")
        }
        .alert("사용자 차단", isPresented: $showBlockAlert) {
            blockAlertButtons
        } message: {
            Text("이 사용자를 차단하시겠습니까? 차단된 사용자와는 다시 매칭되지 않습니다.")
        }
        .alert("연결 오류", isPresented: $showErrorAlert) {
            Button("확인") {
                endVideoCall()
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - View Components

    private var remoteVideoLayer: some View {
        ZStack {
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()

            // Remote camera off overlay
            if agoraManager.remoteCameraMuted {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("상대방 카메라 꺼짐")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    )
            }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.6), location: 0.0),
                .init(color: Color.black.opacity(0.05), location: 0.25),
                .init(color: Color.clear, location: 0.5),
                .init(color: Color.black.opacity(0.05), location: 0.75),
                .init(color: Color.black.opacity(0.7), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var connectionStatusBanner: some View {
        VStack {
            if case .reconnecting = agoraManager.connectionState {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("재연결 중...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.9))
                .cornerRadius(12)
                .padding(.top, 50)
            } else if case .failed = agoraManager.connectionState {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text("연결 실패")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.9))
                .cornerRadius(12)
                .padding(.top, 50)
            }
            Spacer()
        }
    }

    private var networkQualityIndicator: some View {
        VStack {
            HStack {
                Spacer()

                // Network quality badge
                HStack(spacing: 4) {
                    networkQualityIcon
                    if networkManager.networkQuality == .poor || networkManager.networkQuality == .bad {
                        Text("불안정")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(networkQualityColor.opacity(0.8))
                .cornerRadius(8)
                .padding(.top, 50)
                .padding(.trailing, 20)
            }
            Spacer()
        }
    }

    private var networkQualityIcon: some View {
        Image(systemName: networkQualityIconName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
    }

    private var networkQualityIconName: String {
        switch networkManager.networkQuality {
        case .excellent, .good:
            return "wifi"
        case .fair:
            return "wifi.exclamationmark"
        case .poor, .bad:
            return "wifi.slash"
        default:
            return "questionmark.circle"
        }
    }

    private var networkQualityColor: Color {
        switch networkManager.networkQuality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .poor, .bad:
            return .red
        default:
            return .gray
        }
    }

    private var reportBlockButtons: some View {
        VStack {
            HStack {
                VStack(spacing: 12) {
                    Button(action: { showReportAlert = true }) {
                        Circle()
                            .fill(Color.orange.opacity(0.4))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }

                    Button(action: { showBlockAlert = true }) {
                        Circle()
                            .fill(Color.red.opacity(0.4))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "nosign")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 45)

                Spacer()
            }

            Spacer()
        }
    }

    private var pipAndControls: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: 12) {
                    // PIP video
                    ZStack {
                        if isCameraOn {
                            AgoraVideoView(isLocal: true)
                                .frame(width: 100, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                                .frame(width: 100, height: 140)
                                .overlay(
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.5))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }

                    // Camera and mic controls
                    HStack(spacing: 12) {
                        Button(action: toggleCamera) {
                            Image(systemName: isCameraOn ? "camera.fill" : "camera")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        Button(action: toggleMute) {
                            ZStack {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)

                                if isMuted {
                                    Rectangle()
                                        .frame(width: 35, height: 2)
                                        .foregroundColor(.red)
                                        .rotationEffect(.degrees(45))
                                        .offset(x: 0, y: -2)
                                }
                            }
                        }
                    }

                    // Heart count
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                        Text("X  \(heartCount)")
                            .font(.custom("Carter One", size: 22))
                            .foregroundColor(.white)
                            .scaleEffect(heartCountAnimation ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.4), value: heartCountAnimation)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 180)
            }
        }
    }

    private var timerDisplay: some View {
        VStack {
            Spacer()

            HStack {
                Text("\(timeRemaining)")
                    .font(.custom("Carter One", size: 36))
                    .foregroundColor(timeRemaining <= 10 ? .red : .white)
                    .monospacedDigit()
                    .padding(.leading, 20)
                    .padding(.bottom, 180)

                Spacer()
            }
        }
    }

    private var addTimeButton: some View {
        VStack {
            Spacer()

            Button(action: addTime) {
                VStack(spacing: 4) {
                    Image("plus.square")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                    Text("60s")
                        .font(.custom("Carter One", size: 16))
                        .foregroundColor(.white)
                }
            }
            .disabled(heartCount <= 0)
            .opacity(heartCount <= 0 ? 0.5 : 1.0)
            .padding(.bottom, 50)
        }
    }

    private var endCallButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button(action: endVideoCall) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        )
                }
                .padding(.trailing, 40)
            }
            .padding(.bottom, 65)
        }
    }

    @ViewBuilder
    private var reportAlertButtons: some View {
        Button("스팸/광고") { reportUser(reason: "스팸/광고") }
        Button("부적절한 콘텐츠") { reportUser(reason: "부적절한 콘텐츠") }
        Button("욕설/괴롭힘") { reportUser(reason: "욕설/괴롭힘") }
        Button("기타") { reportUser(reason: "기타") }
        Button("취소", role: .cancel) { }
    }

    @ViewBuilder
    private var blockAlertButtons: some View {
        Button("차단", role: .destructive) { blockUser() }
        Button("취소", role: .cancel) { }
    }

    // MARK: - Actions

    private func toggleCamera() {
        let isCameraOff = AgoraManager.shared.toggleCamera()
        isCameraOn = !isCameraOff
        MatchingManager.shared.signalCameraStatus(isOn: isCameraOn)
        UserDefaults.standard.set(isCameraOn, forKey: "isCameraOn")
    }

    private func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    private func addTime() {
        guard heartCount > 0, !opponentUserId.isEmpty else { return }

        withAnimation {
            heartCountAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            heartCountAnimation = false
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }

        heartCount -= 1
        UserDefaults.standard.set(heartCount, forKey: "heartCount")

        timeRemaining += 60
        MatchingManager.shared.updateCallTimer(timeRemaining)

        userManager.changeHeartCount(uid: uid, delta: -1)
        userManager.sendHeartToOpponent(opponentUserId)

        if isTimerStarted {
            startTimer()
        }
    }

    // MARK: - Setup

    private func setupVideoCall() {
        #if DEBUG
        print("🔴 [VideoCallView] onAppear")
        #endif

        setupCameraState()
        networkManager.startMonitoring()

        guard let channelName = UserDefaults.standard.string(forKey: "currentChannelName"),
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            setupCallObservers()
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

        userManager.loadCurrentUser(uid: uid)
        observeHeartCount(uid: uid)
        observeNewHeartNotification()

        if let currentHeartCount = userManager.currentUser?.heartCount {
            heartCount = currentHeartCount
        }
    }

    private func setupOpponentObservation() {
        guard let matchedUserId = MatchingManager.shared.matchedUserId else {
            #if DEBUG
            print("❌ [VideoCallView] No matchedUserId")
            #endif
            return
        }

        #if DEBUG
        print("🔴 [VideoCallView] setupOpponentObservation - opponent: \(matchedUserId)")
        #endif

        opponentUserId = matchedUserId
        UserManager.shared.addRecentMatch(matchedUserId)

        MatchingManager.shared.observeOpponentPresence(opponentId: matchedUserId) {
            DispatchQueue.main.async {
                guard !isCallEnding, !isBackground else { return }
                endVideoCall()
            }
        }

        MatchingManager.shared.observeOpponentCameraStatus(opponentId: matchedUserId) { isOn in
            DispatchQueue.main.async {
                AgoraManager.shared.applyRemoteCameraMuted(!isOn)
            }
        }
    }

    private func setupCallObservers() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MatchingManager.shared.observeCallTimer { syncedTime in
                if syncedTime > timeRemaining {
                    timeRemaining = syncedTime
                    if isTimerStarted {
                        startTimer()
                    }
                }
            }
        }

        func registerCallEndObserver() {
            if let matchId = UserDefaults.standard.string(forKey: "currentMatchId"), !matchId.isEmpty {
                MatchingManager.shared.observeCallEnd {
                    guard !isCallEnding else { return }
                    cleanupAfterCallEnd(signalEnd: false)
                    DispatchQueue.main.async {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                MatchingManager.shared.observeCallStatusEnded {
                    guard !isCallEnding else { return }
                    cleanupAfterCallEnd(signalEnd: false)
                    DispatchQueue.main.async {
                        presentationMode.wrappedValue.dismiss()
                    }
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

        guard let channelName = UserDefaults.standard.string(forKey: "currentChannelName"),
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

    private func startTimer() {
        timer?.invalidate()
        timer = nil

        isTimerStarted = true

        #if DEBUG
        print("⏱ Timer started: \(timeRemaining)s")
        #endif

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1

                if timeRemaining % 5 == 0 {
                    MatchingManager.shared.updateCallTimer(timeRemaining)
                }
            } else {
                #if DEBUG
                print("⏱ Timer expired - ending call")
                #endif
                endVideoCall()
            }
        }

        RunLoop.current.add(timer!, forMode: .common)
    }

    func endVideoCall() {
        cleanupAfterCallEnd(signalEnd: true)
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Event Handlers

    private func handleRemoteUserJoined(_ joined: Bool) {
        if joined && !isTimerStarted {
            #if DEBUG
            print("✅ Remote user joined - starting timer in 1s")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if agoraManager.remoteUserJoined && !isTimerStarted {
                    startTimer()
                }
            }
        }
    }

    private func handleCallStateChange(_ inCall: Bool) {
        if inCall {
            MatchingManager.shared.signalCameraStatus(isOn: isCameraOn)
        }
    }

    private func handleConnectionStateChange(_ state: AgoraConnectionState) {
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

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background || newPhase == .inactive {
            if !isBackground {
                isBackground = true
                backgroundStartTime = Date()

                #if DEBUG
                print("📱 Background - pausing timer")
                #endif

                timer?.invalidate()
                backgroundTerminationWorkItem?.cancel()

                let workItem = DispatchWorkItem {
                    if isBackground && !isCallEnding {
                        #if DEBUG
                        print("📱 Background 60s elapsed - ending call")
                        #endif
                        cleanupAfterCallEnd(signalEnd: true)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                backgroundTerminationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: workItem)
            }
        } else if newPhase == .active {
            if isBackground {
                let duration = backgroundStartTime.map { Date().timeIntervalSince($0) } ?? 0

                #if DEBUG
                print("📱 Foreground - background duration: \(String(format: "%.1f", duration))s")
                #endif

                isBackground = false
                backgroundStartTime = nil
                backgroundTerminationWorkItem?.cancel()
                backgroundTerminationWorkItem = nil

                if isTimerStarted && !isCallEnding {
                    startTimer()
                }

                if AgoraManager.shared.isInCall {
                    AgoraManager.shared.agoraKit?.enableLocalVideo(true)
                    AgoraManager.shared.agoraKit?.startPreview()
                }
            }
        }
    }

    private func handleAppTermination() {
        guard !isCallEnding else { return }
        cleanupAfterCallEnd(signalEnd: true)
    }

    private func onDisappearTasks() {
        if isBackground { return }
        cleanupAfterCallEnd(signalEnd: true)
    }

    // MARK: - Cleanup

    private func cleanupAfterCallEnd(signalEnd: Bool) {
        guard !isCallEnding else { return }

        isCallEnding = true

        backgroundTerminationWorkItem?.cancel()
        backgroundTerminationWorkItem = nil
        backgroundStartTime = nil
        isBackground = false

        #if DEBUG
        print("📱 Call ending - cleanup started")
        #endif

        if signalEnd {
            if let matchId = UserDefaults.standard.string(forKey: "currentMatchId") {
                MatchingManager.shared.signalCallEnd(matchId: matchId)
            } else {
                MatchingManager.shared.signalCallEnd()
            }
        }

        MatchingManager.shared.cancelMatching()

        if !signalEnd {
            MatchingManager.shared.callEndedByOpponent = true
        }

        timer?.invalidate()
        timer = nil

        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()

        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
    }

    // MARK: - Heart Observation

    private func observeHeartCount(uid: String) {
        Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let newCount = data["heartCount"] as? Int,
                      newCount != heartCount else { return }

                DispatchQueue.main.async {
                    heartCount = newCount
                    UserDefaults.standard.set(newCount, forKey: "heartCount")
                }
            }
    }

    private func observeNewHeartNotification() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Database.database().reference()
            .child("notifications")
            .child(uid)
            .child("newHeart")
            .observe(.childAdded) { snapshot in
                DispatchQueue.main.async {
                    heartCount += 1
                    UserDefaults.standard.set(heartCount, forKey: "heartCount")
                }

                userManager.changeHeartCount(uid: uid, delta: +1)
                snapshot.ref.removeValue()
            }
    }

    // MARK: - Report/Block

    private func reportUser(reason: String) {
        guard !opponentUserId.isEmpty else { return }

        ContentModerationManager.shared.reportUser(reportedUserId: opponentUserId, reason: reason) { success in
            DispatchQueue.main.async {
                if success {
                    #if DEBUG
                    print("✅ Report submitted: \(reason)")
                    #endif
                    endVideoCall()
                }
            }
        }
    }

    private func blockUser() {
        guard !opponentUserId.isEmpty else { return }

        UserManager.shared.reportAndBlockUser(opponentUserId, reason: "사용자 차단")
        #if DEBUG
        print("✅ User blocked: \(opponentUserId)")
        #endif

        endVideoCall()
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
