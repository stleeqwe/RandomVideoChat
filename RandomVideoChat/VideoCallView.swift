import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

@available(iOS 15.0, *)
struct VideoCallView: View {
    // 상태
    @State private var isCallActive = false
    @State private var timeRemaining = 60            // 기본 60초로 시작(기획서 표기와 동일)
    @State private var isTimerStarted = false
    @State private var timer: Timer?
    @State private var heartCount = 3
    @State private var showEndMessage = false
    @State private var endMessageText = "통화가 종료되었습니다"
    @State private var isCallEnding = false
    @State private var opponentUserId: String = ""
    @State private var showHeartPulse = false

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 1) 원격 비디오 풀스크린
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()

            // 2) 좌하단 워터마크 (임의 이미지 사용)
            VStack {
                Spacer()
                HStack {
                    Image("watermark_s")                 // IDE에 이미지 올려두면 자동 적용
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(0.9)
                        .shadow(radius: 2, x: 0, y: 1)
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 110)                   // 하단 바 위로 띄움
            }

            // 3) 우하단 PIP(내 카메라)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AgoraVideoView(isLocal: true)
                        .frame(width: 120, height: 160)  // 기획서 비율 유사
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 120)                   // 하단 바와 간격
            }

            // 4) 하단 컨트롤 바
            VStack {
                Spacer()
                ZStack {
                    // 반투명 바
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .frame(height: 110)
                        .ignoresSafeArea(edges: .bottom)

                    // 콘텐츠
                    HStack {
                        Spacer()

                        // 중앙: +60 버튼 + 남은시간(60s)
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

                                    // 하트 배지
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .offset(x: 16, y: -22)
                                        .scaleEffect(showHeartPulse ? 1.25 : 1.0)
                                        .opacity(heartCount > 0 ? 1 : 0.35)
                                }
                            }
                            .disabled(heartCount <= 0)
                            .opacity(heartCount <= 0 ? 0.5 : 1)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(timeRemaining)")
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                Text("s")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.top, 4)
                            }
                            .accessibilityLabel("남은 시간 \(timeRemaining)초")
                        }

                        Spacer()

                        // 우측: 카메라 아이콘 + 하트 x개
                        HStack(spacing: 18) {
                            Button(action: takeSnapshot) {
                                Image(systemName: "camera")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

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

            // 5) 통화 종료 오버레이 (기존 로직 유지)
            if showEndMessage {
                ZStack {
                    Color.black.opacity(0.88).ignoresSafeArea()
                    VStack(spacing: 22) {
                        Image(systemName: timeRemaining <= 0 ? "clock.badge.xmark.fill" : "phone.down.circle.fill")
                            .font(.system(size: 64, weight: .medium))
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

    // MARK: - Actions
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
        withAnimation(.easeInOut(duration: 0.25)) {
            showHeartPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.25)) { showHeartPulse = false }
        }
    }

    private func takeSnapshot() {
        // TODO: 필요 시 Agora 캡처 함수 연결
        // 예: agoraManager.captureRemoteFrame()
        // 현재는 UI만 반영
    }

    private func onAppearTasks() {
        startVideoCall()

        // 사용자 데이터 로드 및 하트 관찰
        if let uid = Auth.auth().currentUser?.uid {
            userManager.loadCurrentUser(uid: uid)
            observeHeartCount(uid: uid)
            observeNewHeartNotification()
            if let currentHeartCount = userManager.currentUser?.heartCount {
                heartCount = currentHeartCount
            }
        }

        // 매칭된 상대방 ID
        if let matchedUserId = MatchingManager.shared.matchedUserId {
            opponentUserId = matchedUserId
            UserManager.shared.addRecentMatch(matchedUserId)
        }

        // 타이머 동기화 관찰
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MatchingManager.shared.observeCallTimer { syncedTime in
                if syncedTime > timeRemaining {
                    timeRemaining = syncedTime
                    if isTimerStarted { startTimer() }
                }
            }
        }

        // 상대 종료 관찰
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MatchingManager.shared.observeCallEnd {
                guard !isCallEnding else { return }
                isCallEnding = true
                timer?.invalidate()
                AgoraManager.shared.endCall()
                MatchingManager.shared.cancelMatching()
                MatchingManager.shared.cleanupCallObservers()
                endMessageText = "통화가 종료되었습니다"
                showEndMessage = true
            }
        }
    }

    private func onDisappearTasks() {
        if !isCallEnding {
            isCallEnding = true
            MatchingManager.shared.signalCallEnd()
        }
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
    }

    // MARK: - 기존 로직 유지
    private func startVideoCall() {
        isCallActive = true
        if let channelName = UserDefaults.standard.string(forKey: "currentChannelName") {
            AgoraManager.shared.startCall(channel: channelName)
        }
    }

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

    private func endVideoCall() {
        if !isCallEnding {
            isCallEnding = true
            MatchingManager.shared.signalCallEnd()
            MatchingManager.shared.cancelMatching()
        }
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        endMessageText = timeRemaining <= 0 ? "시간이 종료되었습니다" : "통화가 종료되었습니다"
        showEndMessage = true
    }

    // MARK: - 하트 실시간 관찰
    private func observeHeartCount(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid)
            .addSnapshotListener { documentSnapshot, _ in
                guard let document = documentSnapshot, let data = document.data(),
                      let newHeartCount = data["heartCount"] as? Int else { return }
                if newHeartCount != heartCount {
                    DispatchQueue.main.async {
                        heartCount = newHeartCount
                        UserDefaults.standard.set(newHeartCount, forKey: "heartCount")
                    }
                }
            }
    }

    // MARK: - 새 하트 알림 관찰
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
}
