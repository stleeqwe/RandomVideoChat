import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

struct VideoCallView: View {
    @State private var isCallActive = false
    @State private var timeRemaining = 5
    @State private var isTimerStarted = false
    @State private var timer: Timer?
    @State private var isMuted = false
    @State private var heartCount = 3
    @State private var showEndMessage = false
    @State private var endMessageText = "통화가 종료되었습니다"
    @State private var isCallEnding = false
    @State private var opponentUserId: String = ""

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 원격 비디오 전체 화면
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()

            // 로컬 비디오 (작은 화면)
            VStack {
                HStack {
                    Spacer()
                    AgoraVideoView(isLocal: true)
                        .frame(width: 100, height: 150)
                        .cornerRadius(10)
                        .padding()
                }
                Spacer()
            }

            // 좌측 하단 타이머/하트 오버레이
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .foregroundColor(.white)
                    Text("\(timeRemaining)초")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(heartCount)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .bottom], 20)

            // 하단 컨트롤 버튼들
            VStack {
                Spacer()
                HStack(spacing: 30) {
                    // 음소거 버튼
                    Button(action: toggleMute) {
                        Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(isMuted ? Color.red : Color.gray.opacity(0.6))
                            .clipShape(Circle())
                    }

                    // 60초 추가 버튼
                    Button(action: {
                        if heartCount > 0 && !opponentUserId.isEmpty {
                            heartCount -= 1
                            UserDefaults.standard.set(heartCount, forKey: "heartCount")
                            timeRemaining += 60
                            MatchingManager.shared.updateCallTimer(timeRemaining)
                            userManager.sendHeartToOpponent(opponentUserId)
                            // 현재 사용자의 Firestore 하트 개수 업데이트
                            if let uid = Auth.auth().currentUser?.uid {
                                userManager.updateHeartCount(uid: uid, newCount: heartCount)
                            }
                            if isTimerStarted {
                                startTimer()
                            }
                        }
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                            Text("60초 추가")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 60)
                        .background(heartCount > 0 ? Color.purple : Color.gray.opacity(0.3))
                        .cornerRadius(15)
                    }
                    .disabled(heartCount <= 0)

                    // 카메라 전환 버튼
                    Button(action: switchCamera) {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.6))
                            .clipShape(Circle())
                    }

                    // 통화 종료 버튼
                    Button(action: endVideoCall) {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 30)
            }

            // 통화 종료 메시지
            if showEndMessage {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(endMessageText)
                        .font(.title2)
                        .foregroundColor(.white)
                    Button("확인") {
                        // 팝업 상태 초기화 후 모달 닫기
                        showEndMessage = false
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .onAppear {
            startVideoCall()

            // 사용자 데이터 로드 및 하트 관찰
            if let uid = Auth.auth().currentUser?.uid {
                userManager.loadCurrentUser(uid: uid)
                observeHeartCount(uid: uid)
                observeNewHeartNotification()   // 하트 알림 관찰 추가
                if let currentHeartCount = userManager.currentUser?.heartCount {
                    heartCount = currentHeartCount
                }
            }

            // 매칭된 상대방 ID 저장
            if let matchedUserId = MatchingManager.shared.matchedUserId {
                opponentUserId = matchedUserId
                UserManager.shared.addRecentMatch(matchedUserId)
            }

            // 타이머 동기화 관찰
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
            // 통화 종료 관찰
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MatchingManager.shared.observeCallEnd {
                    // 상대방이 종료한 경우
                    guard !isCallEnding else { return }
                    isCallEnding = true
                    // 타이머 및 통화 종료 처리
                    timer?.invalidate()
                    AgoraManager.shared.endCall()
                    // 🆕 매칭 큐 제거 및 상태 초기화
                    MatchingManager.shared.cancelMatching()
                    MatchingManager.shared.cleanupCallObservers()
                    endMessageText = "통화가 종료되었습니다"
                    showEndMessage = true
                }
            }
        }
        // 상대방 입장 후 타이머 시작
        .onChange(of: agoraManager.remoteUserJoined) { joined in
            if joined && !isTimerStarted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startTimer()
                }
            }
        }
        .onDisappear {
            // 화면을 떠날 때 정리
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
    }

    // MARK: - 하트 실시간 관찰
    func observeHeartCount(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else { return }
                if let data = document.data(),
                   let newHeartCount = data["heartCount"] as? Int {
                    if newHeartCount != heartCount {
                        DispatchQueue.main.async {
                            heartCount = newHeartCount
                            UserDefaults.standard.set(newHeartCount, forKey: "heartCount")
                        }
                    }
                }
            }
    }

    // MARK: - 새 하트 알림 관찰 (상대방이 보낸 하트 수신)
    func observeNewHeartNotification() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Database.database().reference()
            .child("notifications")
            .child(uid)
            .child("newHeart")
            .observe(.childAdded) { snapshot in
                // 하트 +1
                heartCount += 1
                if let uid = Auth.auth().currentUser?.uid {
                    userManager.updateHeartCount(uid: uid, newCount: heartCount)
                }
                // 사용한 알림 삭제
                snapshot.ref.removeValue()
            }
    }

    // MARK: - Video Call Functions
    func startVideoCall() {
        isCallActive = true
        if let channelName = UserDefaults.standard.string(forKey: "currentChannelName") {
            AgoraManager.shared.startCall(channel: channelName)
        }
        // 타이머는 agoraManager.remoteUserJoined가 true일 때 시작
    }

    func startTimer() {
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

    func endVideoCall() {
        // 본인이 종료할 때 호출
        if !isCallEnding {
            isCallEnding = true
            // 상대방에게 통화 종료 신호 전송
            MatchingManager.shared.signalCallEnd()
            // 🆕 매칭 큐에서 현재 사용자를 제거하고 상태 초기화
            MatchingManager.shared.cancelMatching()
        }
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        endMessageText = timeRemaining <= 0 ? "시간이 종료되었습니다" : "통화가 종료되었습니다"
        showEndMessage = true
    }


    func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    func switchCamera() {
        AgoraManager.shared.switchCamera()
    }
}

