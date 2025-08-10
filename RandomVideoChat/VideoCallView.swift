import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

@available(iOS 15.0, *)
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
    @State private var showHeartAnimation = false

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 원격 비디오 전체 화면
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()
            
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
            VStack {
                HStack {
                    Spacer()
                    AgoraVideoView(isLocal: true)
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
                }
                Spacer()
            }

            // 상단 UI (타이머 & 하트)
            VStack {
                HStack {
                    // 타이머 (좌상단)
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
                    .background(.ultraThinMaterial, in: Capsule())
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
                    
                    // 단순한 하트 카운터
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                        Text("X\(heartCount)")
                            .font(.custom("Carter One", size: 16))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()

                // Modern control buttons with glassmorphism
                HStack(spacing: 28) {
                    // Enhanced mute button
                    Button(action: toggleMute) {
                        ZStack {
                            Circle()
                                .fill(
                                    isMuted ? 
                                    LinearGradient(
                                        colors: [
                                            Color(.sRGB, red: 0.9, green: 0.2, blue: 0.2),
                                            Color(.sRGB, red: 1.0, green: 0.3, blue: 0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
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
                            
                            ZStack {
                                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .blur(radius: 6)
                                
                                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                        .scaleEffect(isMuted ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMuted)
                    }

                    // 커스텀 60초 추가 버튼
                    Button(action: {
                        if heartCount > 0 && !opponentUserId.isEmpty {
                            heartCount -= 1
                            UserDefaults.standard.set(heartCount, forKey: "heartCount")
                            timeRemaining += 60
                            MatchingManager.shared.updateCallTimer(timeRemaining)
                            userManager.sendHeartToOpponent(opponentUserId)
                            
                            if let uid = Auth.auth().currentUser?.uid {
                                userManager.updateHeartCount(uid: uid, newCount: heartCount)
                            }
                            if isTimerStarted {
                                startTimer()
                            }
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                                .frame(width: 80, height: 60)
                            VStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                Text("+60s")
                                    .font(.custom("Carter One", size: 12))
                                    .foregroundColor(.white)
                            }
                        }
                            .opacity(heartCount <= 0 ? 0.5 : 1.0)
                    }
                    .disabled(heartCount <= 0)

                    // Enhanced camera flip button
                    Button(action: switchCamera) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
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
                            
                            ZStack {
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .blur(radius: 6)
                                
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                    }

                    // Enhanced end call button
                    Button(action: endVideoCall) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(.sRGB, red: 0.9, green: 0.2, blue: 0.2), location: 0.0),
                                            .init(color: Color(.sRGB, red: 1.0, green: 0.3, blue: 0.3), location: 0.6),
                                            .init(color: Color(.sRGB, red: 0.85, green: 0.15, blue: 0.25), location: 1.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.8
                                        )
                                )
                            
                            ZStack {
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .blur(radius: 8)
                                
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .shadow(color: Color(.sRGB, red: 0.9, green: 0.2, blue: 0.2).opacity(0.5), radius: 20, x: 0, y: 10)
                    }
                }
                .padding(.bottom, 55)
            }

            // Modern end call message overlay
            if showEndMessage {
                ZStack {
                    Color.black.opacity(0.88)
                        .ignoresSafeArea()
                        .blur(radius: 25)
                    
                    VStack(spacing: 30) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .blur(radius: 20)
                            
                            Image(systemName: timeRemaining <= 0 ? "clock.badge.xmark.fill" : "phone.down.circle.fill")
                                .font(.system(size: 65, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color.white.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text(endMessageText)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showEndMessage = false
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("확인")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 45)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(.sRGB, red: 0.2, green: 0.4, blue: 1.0).opacity(0.7),
                                                    Color(.sRGB, red: 0.4, green: 0.6, blue: 1.0).opacity(0.5)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
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
                        }
                        .shadow(color: Color(.sRGB, red: 0.3, green: 0.5, blue: 1.0).opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .padding(45)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 28)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
                }
            }
        }
        .onAppear {
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
        .onChange(of: agoraManager.remoteUserJoined) { joined in
            if joined && !isTimerStarted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startTimer()
                }
            }
        }
        .onDisappear {
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

    // MARK: - 새 하트 알림 관찰
    func observeNewHeartNotification() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Database.database().reference()
            .child("notifications")
            .child(uid)
            .child("newHeart")
            .observe(.childAdded) { snapshot in
                heartCount += 1
                if let uid = Auth.auth().currentUser?.uid {
                    userManager.updateHeartCount(uid: uid, newCount: heartCount)
                }
                snapshot.ref.removeValue()
            }
    }

    // MARK: - Video Call Functions
    func startVideoCall() {
        isCallActive = true
        if let channelName = UserDefaults.standard.string(forKey: "currentChannelName") {
            AgoraManager.shared.startCall(channel: channelName)
        }
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

    func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    func switchCamera() {
        AgoraManager.shared.switchCamera()
    }
}