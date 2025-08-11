import SwiftUI
import UIKit
import Foundation
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
    @State private var isCallEnding = false
    @State private var opponentUserId: String = ""
    @State private var showHeartAnimation = false
    @State private var isCameraOn = true
    @State private var heartCountAnimation = false
    
    // 앱 상태 및 백그라운드 감지를 위한 프로퍼티
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBackground = false
    @State private var backgroundTerminationWorkItem: DispatchWorkItem?

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 원격 비디오 전체 화면
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()
            
            // 상단 그라데이션
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 120)
                .ignoresSafeArea(edges: .top)
                
                Spacer()
            }

            
            // 우측 하단 PIP와 컨트롤들
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // PIP 비디오
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
                        
                        // 카메라 아이콘과 마이크 아이콘
                        HStack(spacing: 12) {
                            // 카메라 아이콘
                            Button(action: {
                                // 실제 비디오 스트림 제어
                                let isCameraOff = AgoraManager.shared.toggleCamera()
                                isCameraOn = !isCameraOff
                                // 카메라 상태를 UserDefaults에 저장
                                UserDefaults.standard.set(isCameraOn, forKey: "isCameraOn")
                            }) {
                                ZStack {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                    
                                    // 카메라 꺼진 상태에서 사선 표시
                                    if !isCameraOn {
                                        Rectangle()
                                            .frame(width: 35, height: 2)
                                            .foregroundColor(.red)
                                            .rotationEffect(.degrees(45))
                                            .offset(x: 0, y: -2)
                                    }
                                }
                            }
                            
                            // 마이크 아이콘
                            Button(action: toggleMute) {
                                ZStack {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                    
                                    // 마이크 꺼진 상태에서 사선 표시
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
                        
                        // 하트 개수 표시
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
            
            // 좌측 하단 타이머 (카메라/마이크 아이콘의 대각선 반대편)
            VStack {
                Spacer()
                
                HStack {
                    Text("\(timeRemaining)")
                        .font(.custom("Carter One", size: 36))
                        .foregroundColor(timeRemaining <= 5 ? .red : .white)
                        .monospacedDigit()
                        .padding(.leading, 20)
                        .padding(.bottom, 180)
                    
                    Spacer()
                }
            }
            
            // 하단 가운데 +60초 버튼
            VStack {
                Spacer()
                
                Button(action: {
                    if heartCount > 0 && !opponentUserId.isEmpty {
                        withAnimation {
                            heartCountAnimation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            heartCountAnimation = false
                        }
                        
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
            
            // 우측 하단 통화종료 버튼
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
        .onAppear {
            // 메인화면에서 설정한 카메라 상태 복원
            isCameraOn = UserDefaults.standard.bool(forKey: "isCameraOn")
            // 기본값이 false이므로 한번도 설정하지 않았다면 true로 설정
            if UserDefaults.standard.object(forKey: "isCameraOn") == nil {
                isCameraOn = true
                UserDefaults.standard.set(true, forKey: "isCameraOn")
            }
            
            startVideoCall()
            
            // Agora 카메라 상태도 동기화
            if !isCameraOn {
                _ = AgoraManager.shared.toggleCamera()
            }

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
                
                // 상대방 presence 감시 시작
                MatchingManager.shared.observeOpponentPresence(opponentId: matchedUserId) {
                    // 상대방 연결 끊김 감지시 통화 종료 (단, 백그라운드 상태가 아닐 때만)
                    DispatchQueue.main.async {
                        print("🔍 상대방 연결 끊김 감지됨 - 백그라운드 상태: \(self.isBackground), 종료 중: \(self.isCallEnding)")
                        guard !self.isCallEnding && !self.isBackground else { 
                            print("⏸ 통화 종료 건너뜀 (백그라운드이거나 이미 종료 중)")
                            return 
                        }
                        print("🛑 상대방 연결 끊김으로 인한 통화 종료")
                        self.endVideoCall()
                    }
                }
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
                    guard !isCallEnding else { 
                        return 
                    }
                    isCallEnding = true
                    timer?.invalidate()
                    AgoraManager.shared.endCall()
                    MatchingManager.shared.cancelMatching()
                    MatchingManager.shared.cleanupCallObservers()
                    // 바로 매칭 화면으로 이동
                    presentationMode.wrappedValue.dismiss()
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            handleAppTermination()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            onDisappearTasks()
        }
    }
    
    private func handleAppTermination() {
        guard !isCallEnding else { return }
        
        isCallEnding = true
        
        // 예약된 백그라운드 작업 취소
        backgroundTerminationWorkItem?.cancel()
        backgroundTerminationWorkItem = nil
        
        // 통화 종료 신호 전송
        MatchingManager.shared.signalCallEnd()
        
        // 타이머 정리
        timer?.invalidate()
        
        // Agora 연결 종료
        AgoraManager.shared.endCall()
        
        // Firebase 리스너 정리
        MatchingManager.shared.cleanupCallObservers()
        
        // UserDefaults 정리
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
    }
    
    private func onDisappearTasks() {
        // 백그라운드로 이동했다면 즉시 종료하지 않음
        if isBackground {
            return
        }
        
        // 종료 신호 송신
        if !isCallEnding {
            isCallEnding = true
            MatchingManager.shared.signalCallEnd()
        }
        
        timer?.invalidate()
        AgoraManager.shared.endCall()
        MatchingManager.shared.cleanupCallObservers()
        cleanupCallSyncObservers()
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
        
        // 예약된 백그라운드 작업도 취소
        backgroundTerminationWorkItem?.cancel()
        backgroundTerminationWorkItem = nil
    }
    
    private func cleanupCallSyncObservers() {
        // 기존 MatchingManager의 cleanupCallObservers와 중복되지 않는 추가 정리 작업
        // 현재는 MatchingManager에서 대부분 처리하므로 빈 함수로 둠
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        print("📱 scenePhase 변경: \(newPhase) (이전 백그라운드 상태: \(isBackground))")
        
        if newPhase == .background {
            print("🔄 백그라운드 진입 - 5초 지연 타이머 시작")
            isBackground = true
            
            // 5초 후 통화 종료를 예약
            let workItem = DispatchWorkItem {
                print("⏰ 백그라운드 5초 경과 - 통화 종료 실행")
                if self.isBackground && !self.isCallEnding {
                    self.endVideoCall()
                    // 콜 동기화 옵저버 및 UserDefaults 정리
                    self.cleanupCallSyncObservers()
                    UserDefaults.standard.removeObject(forKey: "currentChannelName")
                    UserDefaults.standard.removeObject(forKey: "currentMatchId")
                } else {
                    print("⏰ 백그라운드 타이머 실행되었지만 조건 불충족 (백그라운드: \(self.isBackground), 종료중: \(self.isCallEnding))")
                }
            }
            backgroundTerminationWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
            
        } else if newPhase == .active {
            print("🔄 앱 활성화 - 백그라운드 타이머 취소")
            // 앱이 다시 활성화되면 예약된 작업 취소
            isBackground = false
            backgroundTerminationWorkItem?.cancel()
            backgroundTerminationWorkItem = nil
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
        // 바로 매칭 화면으로 이동
        presentationMode.wrappedValue.dismiss()
    }

    func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    func switchCamera() {
        AgoraManager.shared.switchCamera()
    }
}
