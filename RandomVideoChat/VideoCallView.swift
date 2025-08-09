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
<<<<<<< HEAD
=======
    @State private var showHeartAnimation = false
>>>>>>> fefefa2 (Initial Commit)

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 원격 비디오 전체 화면
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()
<<<<<<< HEAD

            // 로컬 비디오 (작은 화면)
=======
            
            // 그라데이션 오버레이 (상단/하단)
            VStack {
                // 상단 그라데이션
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 150)
                .ignoresSafeArea(edges: .top)
                
                Spacer()
                
                // 하단 그라데이션
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .ignoresSafeArea(edges: .bottom)
            }

            // Modern PIP local video with glassmorphism
>>>>>>> fefefa2 (Initial Commit)
            VStack {
                HStack {
                    Spacer()
                    AgoraVideoView(isLocal: true)
<<<<<<< HEAD
                        .frame(width: 100, height: 150)
                        .cornerRadius(10)
                        .padding()
=======
                        .frame(width: 120, height: 175)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                        .padding()
                        .padding(.top, 55)
>>>>>>> fefefa2 (Initial Commit)
                }
                Spacer()
            }

<<<<<<< HEAD
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
=======
            // 상단 UI (타이머 & 하트)
            VStack {
                HStack {
                    // Modern timer with enhanced styling
                    HStack(spacing: 8) {
                        ZStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .blur(radius: 4)
                            
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.white)
                        }
                        
                        Text("\(timeRemaining)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                timeRemaining <= 10 ? 
                                LinearGradient(
                                    colors: [
                                        Color(.sRGB, red: 1.0, green: 0.3, blue: 0.3),
                                        Color(.sRGB, red: 1.0, green: 0.5, blue: 0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .monospacedDigit()
                        
                        Text("sec")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
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
                                lineWidth: 1.5
                            )
                    )
                    .scaleEffect(timeRemaining <= 10 ? 1.08 : 1.0)
                    .shadow(
                        color: timeRemaining <= 10 ? 
                            Color(.sRGB, red: 1.0, green: 0.3, blue: 0.3).opacity(0.4) :
                            Color.black.opacity(0.2),
                        radius: timeRemaining <= 10 ? 15 : 10,
                        x: 0,
                        y: 6
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: timeRemaining <= 10)
                    
                    Spacer()
                    
                    // Enhanced heart counter
                    HStack(spacing: 10) {
                        ZStack {
                            ForEach(0..<2, id: \.self) { index in
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
                                    .blur(radius: index == 0 ? 0 : 6)
                                    .opacity(index == 0 ? 1 : 0.6)
                            }
                        }
                        .scaleEffect(showHeartAnimation ? 1.3 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showHeartAnimation)
                        
                        Text("\(heartCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
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
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()

                // 하단 컨트롤 버튼들 (개선된 디자인)
                HStack(spacing: 25) {
                    // 음소거 버튼
                    Button(action: toggleMute) {
                        ZStack {
                            Circle()
                                .fill(isMuted ? Color.red.opacity(0.9) : Color.white.opacity(0.2))
                                .frame(width: 55, height: 55)
                            
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .frame(width: 55, height: 55)
                            
                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }

                    // 60초 추가 버튼 (개선된 디자인)
                    Button(action: {
                        if heartCount > 0 && !opponentUserId.isEmpty {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showHeartAnimation = true
                            }
                            
>>>>>>> fefefa2 (Initial Commit)
                            heartCount -= 1
                            UserDefaults.standard.set(heartCount, forKey: "heartCount")
                            timeRemaining += 60
                            MatchingManager.shared.updateCallTimer(timeRemaining)
                            userManager.sendHeartToOpponent(opponentUserId)
<<<<<<< HEAD
                            // 현재 사용자의 Firestore 하트 개수 업데이트
=======
                            
>>>>>>> fefefa2 (Initial Commit)
                            if let uid = Auth.auth().currentUser?.uid {
                                userManager.updateHeartCount(uid: uid, newCount: heartCount)
                            }
                            if isTimerStarted {
                                startTimer()
                            }
<<<<<<< HEAD
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
=======
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showHeartAnimation = false
                            }
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            heartCount > 0 ? Color(red: 0.6, green: 0.2, blue: 0.8) : Color.gray.opacity(0.3),
                                            heartCount > 0 ? Color(red: 0.8, green: 0.3, blue: 0.9) : Color.gray.opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 65)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .frame(width: 90, height: 65)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                
                                Text("+60s")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(heartCount <= 0)
                    .scaleEffect(heartCount <= 0 ? 0.95 : 1)

                    // 카메라 전환 버튼
                    Button(action: switchCamera) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 55, height: 55)
                            
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .frame(width: 55, height: 55)
                            
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
>>>>>>> fefefa2 (Initial Commit)
                    }

                    // 통화 종료 버튼
                    Button(action: endVideoCall) {
<<<<<<< HEAD
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
=======
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.9, green: 0.2, blue: 0.2),
                                            Color(red: 1, green: 0.3, blue: 0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 65, height: 65)
                            
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 50)
            }

            // 통화 종료 메시지 (개선된 디자인)
            if showEndMessage {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .blur(radius: 20)
                    
                    VStack(spacing: 25) {
                        Image(systemName: timeRemaining <= 0 ? "clock.badge.xmark" : "phone.down.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(endMessageText)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            showEndMessage = false
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("확인")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
>>>>>>> fefefa2 (Initial Commit)
                }
            }
        }
        .onAppear {
            startVideoCall()

            // 사용자 데이터 로드 및 하트 관찰
            if let uid = Auth.auth().currentUser?.uid {
                userManager.loadCurrentUser(uid: uid)
                observeHeartCount(uid: uid)
<<<<<<< HEAD
                observeNewHeartNotification()   // 하트 알림 관찰 추가
=======
                observeNewHeartNotification()
>>>>>>> fefefa2 (Initial Commit)
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
<<<<<<< HEAD
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
=======
            
            // 통화 종료 관찰
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MatchingManager.shared.observeCallEnd {
                    guard !isCallEnding else { return }
                    isCallEnding = true
                    timer?.invalidate()
                    AgoraManager.shared.endCall()
>>>>>>> fefefa2 (Initial Commit)
                    MatchingManager.shared.cancelMatching()
                    MatchingManager.shared.cleanupCallObservers()
                    endMessageText = "통화가 종료되었습니다"
                    showEndMessage = true
                }
            }
        }
<<<<<<< HEAD
        // 상대방 입장 후 타이머 시작
=======
>>>>>>> fefefa2 (Initial Commit)
        .onChange(of: agoraManager.remoteUserJoined) { joined in
            if joined && !isTimerStarted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startTimer()
                }
            }
        }
        .onDisappear {
<<<<<<< HEAD
            // 화면을 떠날 때 정리
=======
>>>>>>> fefefa2 (Initial Commit)
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

<<<<<<< HEAD
    // MARK: - 새 하트 알림 관찰 (상대방이 보낸 하트 수신)
=======
    // MARK: - 새 하트 알림 관찰
>>>>>>> fefefa2 (Initial Commit)
    func observeNewHeartNotification() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Database.database().reference()
            .child("notifications")
            .child(uid)
            .child("newHeart")
            .observe(.childAdded) { snapshot in
<<<<<<< HEAD
                // 하트 +1
=======
>>>>>>> fefefa2 (Initial Commit)
                heartCount += 1
                if let uid = Auth.auth().currentUser?.uid {
                    userManager.updateHeartCount(uid: uid, newCount: heartCount)
                }
<<<<<<< HEAD
                // 사용한 알림 삭제
=======
>>>>>>> fefefa2 (Initial Commit)
                snapshot.ref.removeValue()
            }
    }

    // MARK: - Video Call Functions
    func startVideoCall() {
        isCallActive = true
        if let channelName = UserDefaults.standard.string(forKey: "currentChannelName") {
            AgoraManager.shared.startCall(channel: channelName)
        }
<<<<<<< HEAD
        // 타이머는 agoraManager.remoteUserJoined가 true일 때 시작
=======
>>>>>>> fefefa2 (Initial Commit)
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
<<<<<<< HEAD
        // 본인이 종료할 때 호출
        if !isCallEnding {
            isCallEnding = true
            // 상대방에게 통화 종료 신호 전송
            MatchingManager.shared.signalCallEnd()
            // 🆕 매칭 큐에서 현재 사용자를 제거하고 상태 초기화
=======
        if !isCallEnding {
            isCallEnding = true
            MatchingManager.shared.signalCallEnd()
>>>>>>> fefefa2 (Initial Commit)
            MatchingManager.shared.cancelMatching()
        }
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        endMessageText = timeRemaining <= 0 ? "시간이 종료되었습니다" : "통화가 종료되었습니다"
        showEndMessage = true
    }

<<<<<<< HEAD

=======
>>>>>>> fefefa2 (Initial Commit)
    func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    func switchCamera() {
        AgoraManager.shared.switchCamera()
    }
}
<<<<<<< HEAD

=======
>>>>>>> fefefa2 (Initial Commit)
