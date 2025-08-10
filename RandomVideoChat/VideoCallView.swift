import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

@available(iOS 15.0, *)
struct VideoCallView: View {
    // 타이머
    @State private var timeRemaining = 5
    @State private var isTimerStarted = false
    @State private var timer: Timer?

    // 상태
    @State private var heartCount = 3
    @State private var isMuted = false
    @State private var isVideoOff = false
    @State private var isCallEnding = false
    @State private var showEndMessage = false
    @State private var endMessageText = "통화가 종료되었습니다"
    @State private var opponentUserId: String = ""

    // 콜 싱크
    @State private var channelName: String = ""
    @State private var callRef: DatabaseReference?
    @State private var callStatusRef: DatabaseReference?
    @State private var callStatusHandle: UInt?

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 원격 비디오
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()

            // 좌하단 워터마크
            VStack {
                Spacer()
                HStack {
                    Image("watermark_s")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(0.9)
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 110)
            }

            // 우하단 PIP(내 비디오)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        AgoraVideoView(isLocal: true)
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                            )
                        if isVideoOff {
                            Color.black.opacity(0.6)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            Image(systemName: "video.slash.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 28, weight: .semibold))
                        }
                    }
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 120)
            }

            // 하단 바
            VStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .frame(height: 110)
                        .ignoresSafeArea(edges: .bottom)

                    HStack {
                        Spacer()

                        // 중앙: +60 버튼과 "60s" 라벨
                        VStack(spacing: 10) {
                            Button(action: addSixtySeconds) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.white, lineWidth: 2)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.08))
                                        )
                                    Image(systemName: "plus")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)

                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .offset(x: 16, y: -22)
                                }
                            }
                            .disabled(heartCount <= 0)
                            .opacity(heartCount <= 0 ? 0.5 : 1)

                            Text("60s")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // 우측: 토글 버튼 + 하트 수
                        HStack(spacing: 14) {
                            // 카메라 ON/OFF
                            Button(action: toggleVideo) {
                                Image(systemName: isVideoOff ? "video.slash.fill" : "video.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            // 마이크 ON/OFF
                            Button(action: toggleMute) {
                                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            // ❤️ xN
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                Text("x\(heartCount)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                }
            }

            // 종료 오버레이
            if showEndMessage {
                ZStack {
                    Color.black.opacity(0.88).ignoresSafeArea()
                    VStack(spacing: 22) {
                        Image(systemName: timeRemaining <= 0 ? "clock.badge.xmark.fill" : "phone.down.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        Text(endMessageText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        Button("확인") {
                            showEndMessage = false
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    .padding(28)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 28)
                }
            }
        }
        .onAppear(perform: onAppearTasks)
        .onChange(of: agoraManager.remoteUserJoined) { joined in
            if joined && !isTimerStarted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { startTimer() }
            }
        }
        .onDisappear(perform: onDisappearTasks)
    }

    // MARK: - lifecycle
    private func onAppearTasks() {
        startVideoCall()

        if let uid = Auth.auth().currentUser?.uid {
            userManager.loadCurrentUser(uid: uid)
            observeHeartCount(uid: uid)
            observeNewHeartNotification()
            if let currentHeartCount = userManager.currentUser?.heartCount {
                heartCount = currentHeartCount
            }
        }

        if let matchedUserId = MatchingManager.shared.matchedUserId {
            opponentUserId = matchedUserId
            UserManager.shared.addRecentMatch(matchedUserId)
        }

        // 채널명 확보 후 콜 동기화
        if let ch = UserDefaults.standard.string(forKey: "currentChannelName") {
            channelName = ch
            setupCallSync(for: ch) // 한쪽 종료 시 반대편도 종료
        }

        // 서버 타이머가 더 길면 동기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MatchingManager.shared.observeCallTimer { syncedTime in
                if syncedTime > timeRemaining {
                    timeRemaining = syncedTime
                    if isTimerStarted { startTimer() }
                }
            }
        }
    }

    private func onDisappearTasks() {
        // 종료 신호 송신
        if !isCallEnding {
            isCallEnding = true
            signalRemoteEnd()
            MatchingManager.shared.signalCallEnd()
        }
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        cleanupCallSyncObservers()
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
    }

    // MARK: - Timer
    private func startTimer() {
        timer?.invalidate()
        isTimerStarted = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                endVideoCall()
            }
        }
    }

    private func addSixtySeconds() {
        guard heartCount > 0, !opponentUserId.isEmpty else { return }
        heartCount -= 1
        UserDefaults.standard.set(heartCount, forKey: "heartCount")
        timeRemaining += 60
        MatchingManager.shared.updateCallTimer(timeRemaining)
        userManager.sendHeartToOpponent(opponentUserId)
        if let uid = Auth.auth().currentUser?.uid {
            userManager.updateHeartCount(uid: uid, newCount: heartCount)
        }
        if isTimerStarted { startTimer() }
    }

    private func endVideoCall() {
        if !isCallEnding {
            isCallEnding = true
            signalRemoteEnd()                   // 상대에게 종료 반영
            MatchingManager.shared.signalCallEnd()
            MatchingManager.shared.cancelMatching()
        }
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        endMessageText = timeRemaining <= 0 ? "시간이 종료되었습니다" : "통화가 종료되었습니다"
        showEndMessage = true
    }

    // MARK: - 하트 관찰
    private func observeHeartCount(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid)
            .addSnapshotListener { documentSnapshot, _ in
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let newHeartCount = data["heartCount"] as? Int else { return }
                if newHeartCount != heartCount {
                    DispatchQueue.main.async {
                        heartCount = newHeartCount
                        UserDefaults.standard.set(newHeartCount, forKey: "heartCount")
                    }
                }
            }
    }

    private func observeNewHeartNotification() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Database.database().reference()
            .child("notifications").child(uid).child("newHeart")
            .observe(.childAdded) { snapshot in
                heartCount += 1
                if let uid = Auth.auth().currentUser?.uid {
                    userManager.updateHeartCount(uid: uid, newCount: heartCount)
                }
                snapshot.ref.removeValue()
            }
    }

    // MARK: - Agora
    private func startVideoCall() {
        if let ch = UserDefaults.standard.string(forKey: "currentChannelName") {
            AgoraManager.shared.startCall(channel: ch)
        }
    }

    private func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    private func toggleVideo() {
        isVideoOff = AgoraManager.shared.toggleVideo()
    }

    // MARK: - Call Sync (상대 동시 종료)
    private func setupCallSync(for channel: String) {
        let base = Database.database().reference().child("callSessions").child(channel)
        callRef = base
        let statusRef = base.child("status")
        callStatusRef = statusRef

        statusRef.setValue("active")
        statusRef.onDisconnectSetValue("ended") // 강제 종료 대비

        callStatusHandle = statusRef.observe(.value) { snapshot in
            guard let val = snapshot.value as? String else { return }
            if val == "ended", !isCallEnding {
                isCallEnding = true
                timer?.invalidate()
                AgoraManager.shared.endCall()
                MatchingManager.shared.cancelMatching()
                MatchingManager.shared.cleanupCallObservers()
                endMessageText = "상대가 통화를 종료했습니다"
                showEndMessage = true
            }
        }
    }

    private func signalRemoteEnd() {
        callStatusRef?.setValue("ended")
    }

    private func cleanupCallSyncObservers() {
        if let handle = callStatusHandle, let ref = callStatusRef {
            ref.removeObserver(withHandle: handle)
        }
        callStatusHandle = nil
        callStatusRef = nil
        callRef = nil
    }
}
