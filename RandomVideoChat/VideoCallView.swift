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
    
    // 신고/차단 관련 상태
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var reportReason = ""
    
    // 앱 상태 및 백그라운드 감지를 위한 프로퍼티
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBackground = false
    @State private var backgroundTerminationWorkItem: DispatchWorkItem?
    @State private var backgroundStartTime: Date?

    @StateObject private var userManager = UserManager.shared
    @StateObject private var agoraManager = AgoraManager.shared

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // 원격 비디오 전체 화면
            AgoraVideoView(isLocal: false)
                .ignoresSafeArea()
            
            // 전체 화면 상하단 그라데이션
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(0.6), location: 0.0),   // 상단 어두움
                    .init(color: Color.black.opacity(0.05), location: 0.25), // 상단 중간 밝음
                    .init(color: Color.clear, location: 0.5),                // 중앙 완전 투명
                    .init(color: Color.black.opacity(0.05), location: 0.75), // 하단 중간 밝음
                    .init(color: Color.black.opacity(0.7), location: 1.0)    // 하단 어두움
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 상단 좌측 신고/차단 버튼
            VStack {
                HStack {
                    VStack(spacing: 12) {
                        // 신고 버튼
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
                        
                        // 차단 버튼 - 더 직관적인 아이콘으로 변경
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
                                Image(systemName: isCameraOn ? "camera.fill" : "camera")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
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
                        
                        if let uid = Auth.auth().currentUser?.uid {
                            // 1) UI를 즉시 업데이트
                            heartCount -= 1
                            UserDefaults.standard.set(heartCount, forKey: "heartCount")
                            
                            // 2) 타이머 +60초
                            timeRemaining += 60
                            MatchingManager.shared.updateCallTimer(timeRemaining)
                            
                            // 3) 서버에 원자적으로 하트 감소 (FieldValue.increment 사용)
                            userManager.changeHeartCount(uid: uid, delta: -1)
                            
                            // 4) 상대방에게 하트 알림 전송
                            userManager.sendHeartToOpponent(opponentUserId)
                            
                            if isTimerStarted {
                                startTimer()
                            }
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
                    
                    // 통화종료 버튼
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
            setupVideoCall()
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
        .alert("사용자 신고", isPresented: $showReportAlert) {
            Button("스팸/광고") { reportUser(reason: "스팸/광고") }
            Button("부적절한 콘텐츠") { reportUser(reason: "부적절한 콘텐츠") }
            Button("욕설/괴롭힘") { reportUser(reason: "욕설/괴롭힘") }
            Button("기타") { reportUser(reason: "기타") }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이 사용자를 신고하는 이유를 선택해주세요.")
        }
        .alert("사용자 차단", isPresented: $showBlockAlert) {
            Button("차단", role: .destructive) { blockUser() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이 사용자를 차단하시겠습니까? 차단된 사용자와는 다시 매칭되지 않습니다.")
        }
    }
    
    private func handleAppTermination() {
        guard !isCallEnding else { return }
        cleanupAfterCallEnd(signalEnd: true)
    }
    
    private func onDisappearTasks() {
        // 백그라운드로 이동했다면 즉시 종료하지 않음
        if isBackground {
            return
        }
        
        cleanupAfterCallEnd(signalEnd: true)
    }
    
    private func cleanupCallSyncObservers() {
        // 기존 MatchingManager의 cleanupCallObservers와 중복되지 않는 추가 정리 작업
        // 현재는 MatchingManager에서 대부분 처리하므로 빈 함수로 둠
    }
    
    // MARK: - 통합된 정리 함수
    private func cleanupAfterCallEnd(signalEnd: Bool) {
        guard !isCallEnding else { return }
        
        isCallEnding = true
        
        // 백그라운드 타이머 및 상태 완전 정리
        backgroundTerminationWorkItem?.cancel()
        backgroundTerminationWorkItem = nil
        backgroundStartTime = nil
        isBackground = false
        
        #if DEBUG
        print("📱 통화 종료 - 백그라운드 관련 상태 모두 초기화")
        #endif
        
        if signalEnd {
            // 내가 종료하는 경우에만 통화 종료 신호 전송 (matchId 삭제 전에 실행)
            if let matchId = UserDefaults.standard.string(forKey: "currentMatchId") {
                MatchingManager.shared.signalCallEnd(matchId: matchId)
                print("📡 통화 종료 신호 전송 시도: matchId = \(matchId)")
            } else {
                print("❌ 통화 종료 신호 전송 실패: matchId가 없음")
                // matchId가 없어도 일단 기본 함수 시도
                MatchingManager.shared.signalCallEnd()
            }
        }
        
        // 매칭 상태를 항상 초기화 (signalEnd 후에 실행하여 matchId 삭제)
        MatchingManager.shared.cancelMatching()
        
        if !signalEnd {
            // 상대방이 종료한 경우 MATCHED! 플래시 방지를 위해 플래그 설정
            MatchingManager.shared.callEndedByOpponent = true
        }
        
        // 타이머 정리
        timer?.invalidate()
        
        // Agora 연결 종료
        AgoraManager.shared.endCall()
        
        // Firebase 리스너 정리
        MatchingManager.shared.cleanupCallObservers()
        cleanupCallSyncObservers()
        
        // UserDefaults 정리
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background || newPhase == .inactive {
            // 백그라운드 진입
            if !isBackground {
                isBackground = true
                backgroundStartTime = Date()
                
                #if DEBUG
                print("📱 백그라운드 진입 - 5초 타이머 시작")
                #endif
                
                // 기존 타이머가 있다면 취소 (안전장치)
                backgroundTerminationWorkItem?.cancel()
                
                // 5초 후 통화 종료를 예약
                let workItem = DispatchWorkItem {
                    if self.isBackground && !self.isCallEnding {
                        #if DEBUG
                        print("📱 백그라운드 5초 경과 - 통화 종료")
                        #endif
                        self.cleanupAfterCallEnd(signalEnd: true)
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
                backgroundTerminationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
            }
            
        } else if newPhase == .active {
            // 앱이 다시 활성화
            if isBackground {
                let backgroundDuration = backgroundStartTime.map { Date().timeIntervalSince($0) } ?? 0
                
                #if DEBUG
                print("📱 포어그라운드 복귀 - 백그라운드 소요시간: \(String(format: "%.1f", backgroundDuration))초")
                #endif
                
                isBackground = false
                backgroundStartTime = nil
                
                // 예약된 종료 작업 취소 및 초기화
                backgroundTerminationWorkItem?.cancel()
                backgroundTerminationWorkItem = nil
                
                #if DEBUG
                print("📱 백그라운드 타이머 완전 초기화 완료")
                #endif
            }
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
                
                // 로컬 UI에서 즉시 반영
                DispatchQueue.main.async {
                    heartCount += 1
                    UserDefaults.standard.set(heartCount, forKey: "heartCount")
                }
                
                // 서버에 +1 원자적 증가 (FieldValue.increment 사용)
                userManager.changeHeartCount(uid: uid, delta: +1)
                
                // 알림 데이터 삭제
                snapshot.ref.removeValue()
            }
    }

    // MARK: - Video Call Setup and Management
    private func setupVideoCall() {
        setupCameraState()
        startVideoCall()
        setupUserData()
        setupOpponentObservation()
        setupCallObservers()
    }
    
    private func setupCameraState() {
        // 메인화면에서 설정한 카메라 상태 복원
        isCameraOn = UserDefaults.standard.bool(forKey: "isCameraOn")
        // 기본값이 false이므로 한번도 설정하지 않았다면 true로 설정
        if UserDefaults.standard.object(forKey: "isCameraOn") == nil {
            isCameraOn = true
            UserDefaults.standard.set(true, forKey: "isCameraOn")
        }
        
        // Agora 카메라 상태도 동기화
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
        guard let matchedUserId = MatchingManager.shared.matchedUserId else { return }
        
        opponentUserId = matchedUserId
        UserManager.shared.addRecentMatch(matchedUserId)
        
        // 상대방 presence 감시 시작
        MatchingManager.shared.observeOpponentPresence(opponentId: matchedUserId) {
            DispatchQueue.main.async {
                guard !isCallEnding && !isBackground else { return }
                endVideoCall()
            }
        }
    }
    
    private func setupCallObservers() {
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
        
        // 1) 통화 종료 관찰 등록 함수 정의
        func registerCallEndObserver() {
            if let matchId = UserDefaults.standard.string(forKey: "currentMatchId"), !matchId.isEmpty {
                // endedBy 필드 기반 관찰
                MatchingManager.shared.observeCallEnd {
                    guard !isCallEnding else { return }
                    cleanupAfterCallEnd(signalEnd: false)
                    // 뷰 반영 후 dismiss
                    DispatchQueue.main.async {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                // status 필드 기반 관찰 (이중 안전장치)
                MatchingManager.shared.observeCallStatusEnded {
                    guard !isCallEnding else { return }
                    cleanupAfterCallEnd(signalEnd: false)
                    DispatchQueue.main.async {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } else {
                // matchId가 없으면 0.3초 후 재시도
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    registerCallEndObserver()
                }
            }
        }
        
        // 옵저버 등록 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            registerCallEndObserver()
        }
    }
    
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
        cleanupAfterCallEnd(signalEnd: true)
        presentationMode.wrappedValue.dismiss()
    }

    func toggleMute() {
        isMuted = AgoraManager.shared.toggleMute()
    }

    func switchCamera() {
        AgoraManager.shared.switchCamera()
    }
    
    // MARK: - Enhanced Report and Block Functions
    private func reportUser(reason: String) {
        guard !opponentUserId.isEmpty else {
            print("❌ 신고 실패: 상대방 ID가 없음")
            return
        }
        
        ContentModerationManager.shared.reportUser(reportedUserId: opponentUserId, reason: reason) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ 신고 완료: \(reason)")
                    // 신고 완료 후 통화 종료
                    self.endVideoCall()
                } else {
                    print("❌ 신고 실패")
                }
            }
        }
    }
    
    private func blockUser() {
        guard !opponentUserId.isEmpty else {
            print("❌ 차단 실패: 상대방 ID가 없음")
            return
        }
        
        // 강화된 신고 및 차단 (자동 신고 포함)
        UserManager.shared.reportAndBlockUser(opponentUserId, reason: "사용자 차단")
        print("✅ 사용자 신고 및 차단: \(opponentUserId)")
        
        // 차단 후 즉시 통화 종료
        endVideoCall()
    }
}
