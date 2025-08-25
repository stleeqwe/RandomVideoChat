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
    @AppStorage("heartCount") private var heartCount: Int = 3
    @State private var isCallEnding = false
    @State private var opponentUserId: String = ""
    @State private var showHeartAnimation = false
    @AppStorage("isCameraOn") private var isCameraOn: Bool = true
    @State private var heartCountAnimation = false
    
    // 신고/차단 관련 상태
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var reportReason = ""
    
    // Firestore 리스너
    @State private var heartCountListener: ListenerRegistration?
    
    // 앱 상태 및 백그라운드 감지를 위한 프로퍼티
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBackground = false
    @State private var backgroundTerminationWorkItem: DispatchWorkItem?
    @State private var backgroundStartTime: Date?

    @StateObject private var userManager = UserManager.shared
    @EnvironmentObject var agoraManager: AgoraManager
    @EnvironmentObject var matchingManager: MatchingManager

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
                                let isCameraOff = agoraManager.toggleCamera()
                                isCameraOn = !isCameraOff
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
                            // 1) AppStorage를 통해 UI 자동 업데이트
                            heartCount -= 1
                            
                            // 2) 타이머 +60초
                            timeRemaining += 60
                            matchingManager.updateCallTimer(timeRemaining)
                            
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
            // Agora 사용 전 커스텀 카메라 세션 중지 (충돌 방지)
            CameraView.CameraSessionManager.shared.stop()
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
        
        // DB에서 ready 상태 및 callStartAt 정리
        if let matchId = UserDefaults.standard.string(forKey: "currentMatchId"),
           let currentUserId = Auth.auth().currentUser?.uid {
            
            let matchRef = Database.database().reference().child("matches").child(matchId)
            
            // 매치 정보에서 내가 user1인지 user2인지 확인
            matchRef.observeSingleEvent(of: .value) { snapshot in
                if let data = snapshot.value as? [String: Any],
                   let user1 = data["user1"] as? String {
                    
                    let isUser1 = (user1 == currentUserId)
                    let myReadyKey = isUser1 ? "user1Ready" : "user2Ready"
                    
                    // ready 상태와 callStartAt 초기화
                    let cleanupUpdates: [String: Any] = [
                        myReadyKey: false,
                        "callStartAt": NSNull()
                    ]
                    
                    matchRef.updateChildValues(cleanupUpdates) { error, _ in
                        if let error = error {
                            print("❌ DB 상태 정리 실패: \(error)")
                        } else {
                            print("✅ DB 상태 정리 완료 (ready: false, callStartAt: null)")
                        }
                    }
                }
            }
            
            if signalEnd {
                // 내가 종료하는 경우 통화 종료 신호 전송
                MatchingManager.shared.signalCallEnd(matchId: matchId)
                #if DEBUG
                print("📡 통화 종료 신호 전송: matchId = \(matchId)")
                #endif
            }
        }
        
        // 매칭 상태를 항상 초기화
        MatchingManager.shared.cancelMatching()
        
        if !signalEnd {
            // 상대방이 종료한 경우 MATCHED! 플래시 방지를 위해 플래그 설정
            MatchingManager.shared.callEndedByOpponent = true
        }
        
        // 타이머 정리
        timer?.invalidate()
        
        // Agora 연결 종료
        agoraManager.endCall()
        
        // Firebase 리스너 정리
        matchingManager.cleanupCallObservers()
        cleanupCallSyncObservers()
        
        // Firestore heartCount 리스너 해제
        heartCountListener?.remove()
        heartCountListener = nil
        
        // UserDefaults 정리
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
        PerformanceMonitor.shared.stopPerformanceMonitoring()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background || newPhase == .inactive {
            // 백그라운드 진입
            if !isBackground {
                isBackground = true
                backgroundStartTime = Date()
                
                #if DEBUG
                print("📱 백그라운드 진입 - 30초 타이머 시작")
                #endif
                
                // 기존 타이머가 있다면 취소 (안전장치)
                backgroundTerminationWorkItem?.cancel()
                
                // 30초 후 통화 종료를 예약
                let workItem = DispatchWorkItem {
                    if self.isBackground && !self.isCallEnding {
                        #if DEBUG
                        print("📱 백그라운드 30초 경과 - 통화 종료")
                        #endif
                        self.cleanupAfterCallEnd(signalEnd: true)
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
                backgroundTerminationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
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
                
                // 예약된 종료 작업 안전하게 취소
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
        heartCountListener = db.collection("users").document(uid)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else { return }
                if let data = document.data(),
                   let newHeartCount = data["heartCount"] as? Int {
                    if newHeartCount != heartCount {
                        DispatchQueue.main.async {
                            heartCount = newHeartCount
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
                
                // AppStorage를 통해 UI 자동 업데이트
                DispatchQueue.main.async {
                    heartCount += 1
                }
                
                // 서버에 +1 원자적 증가 (FieldValue.increment 사용)
                userManager.changeHeartCount(uid: uid, delta: +1)
                
                // 고유 하트 발신자 기록 및 선호도 갱신
                if let dict = snapshot.value as? [String: Any],
                   let fromId = dict["from"] as? String {
                    UserManager.shared.recordHeartReceived(from: fromId)
                }
                
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
        // AppStorage를 통해 자동으로 동기화되므로 추가 설정 불필요
        // Agora 카메라 상태만 동기화
        if !isCameraOn {
            _ = agoraManager.toggleCamera()
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
        
        guard let channelName = UserDefaults.standard.string(forKey: "currentChannelName"),
              let matchId = UserDefaults.standard.string(forKey: "currentMatchId"),
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ 채널 정보 또는 사용자 정보 없음")
            return
        }
        
        let matchRef = Database.database().reference().child("matches").child(matchId)
        
        // 매치 정보 읽기
        matchRef.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let user1 = data["user1"] as? String,
                  let _ = data["user2"] as? String else {
                print("❌ 매치 정보 읽기 실패")
                return
            }
            
            let isUser1 = (user1 == currentUserId)
            let myReadyKey = isUser1 ? "user1Ready" : "user2Ready"
            let otherReadyKey = isUser1 ? "user2Ready" : "user1Ready"
            
            print("🔍 내 역할: \(isUser1 ? "user1" : "user2")")
            print("🔍 채널명: \(channelName)")
            
            // 기존 ready 상태 및 callStartAt 초기화 (현재 사용하지 않음)
            // let updates: [String: Any] = [
            //     myReadyKey: true,
            //     "user1Ready": isUser1 ? true : NSNull(),
            //     "user2Ready": isUser1 ? NSNull() : true
            // ]
            
            // 내 준비 상태 설정
            matchRef.child(myReadyKey).setValue(true) { error, _ in
                if let error = error {
                    print("❌ Ready 상태 설정 실패: \(error)")
                    return
                }
                
                print("✅ 내 준비 상태 설정 완료")
                
                // callStartAt 관찰 시작
                var callStartObserver: DatabaseHandle?
                callStartObserver = matchRef.child("callStartAt").observe(.value) { snapshot in
                    if let startTime = snapshot.value as? TimeInterval {
                        print("🕐 통화 시작 시간 감지: \(startTime)")
                        
                        // 리스너 제거
                        if let handle = callStartObserver {
                            matchRef.child("callStartAt").removeObserver(withHandle: handle)
                        }
                        matchRef.child(otherReadyKey).removeAllObservers()
                        
                        // 지정된 시간까지 대기
                        let currentTime = Date().timeIntervalSince1970 * 1000
                        let delay = max(0, (startTime - currentTime) / 1000)
                        
                        print("⏱ \(delay)초 후 채널 입장 예정")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            print("🎬 채널 입장 시작: \(channelName)")
                            self.agoraManager.startCall(channel: channelName)
                        }
                    }
                }
                
                // 상대방 준비 상태 체크
                var otherReadyObserver: DatabaseHandle?
                otherReadyObserver = matchRef.child(otherReadyKey).observe(.value) { snapshot in
                    if let isReady = snapshot.value as? Bool, isReady {
                        print("✅ 상대방도 준비 완료 - 시작 시간 설정")
                        
                        // 리스너 제거
                        if let handle = otherReadyObserver {
                            matchRef.child(otherReadyKey).removeObserver(withHandle: handle)
                        }
                        
                        // callStartAt이 아직 설정되지 않았다면 설정
                        matchRef.child("callStartAt").observeSingleEvent(of: .value) { snapshot in
                            if snapshot.value == nil || snapshot.value is NSNull {
                                // 현재 시간 + 2초 후로 설정 (밀리초 단위)
                                let startTime = (Date().timeIntervalSince1970 + 2) * 1000
                                
                                print("📝 통화 시작 시간 설정: \(startTime)")
                                matchRef.child("callStartAt").setValue(startTime)
                            }
                        }
                    }
                }
                
                // 상대방이 이미 준비되었는지 즉시 확인
                matchRef.child(otherReadyKey).observeSingleEvent(of: .value) { snapshot in
                    if let isReady = snapshot.value as? Bool, isReady {
                        print("✅ 상대방이 이미 준비되어 있음")
                        
                        // callStartAt 확인 및 설정
                        matchRef.child("callStartAt").observeSingleEvent(of: .value) { snapshot in
                            if snapshot.value == nil || snapshot.value is NSNull {
                                let startTime = (Date().timeIntervalSince1970 + 2) * 1000
                                print("📝 통화 시작 시간 설정: \(startTime)")
                                matchRef.child("callStartAt").setValue(startTime)
                            }
                        }
                    }
                }
            }
        }
        
        // 통화 시작 시 통화 횟수 증가
        UserManager.shared.incrementCallCount()
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
        isMuted = agoraManager.toggleMute()
    }

    func switchCamera() {
        agoraManager.switchCamera()
    }
    
    // MARK: - Enhanced Report and Block Functions
    private func reportUser(reason: String) {
        guard !opponentUserId.isEmpty else {
            #if DEBUG
            print("❌ 신고 실패: 상대방 ID가 없음")
            #endif
            return
        }
        
        ContentModerationManager.shared.reportUser(reportedUserId: opponentUserId, reason: reason) { success in
            DispatchQueue.main.async {
                if success {
                    #if DEBUG
                    print("✅ 신고 완료: \(reason)")
                    #endif
                    // 신고 완료 후 통화 종료
                    self.endVideoCall()
                } else {
                    #if DEBUG
                    print("❌ 신고 실패")
                    #endif
                }
            }
        }
    }
    
    private func blockUser() {
        guard !opponentUserId.isEmpty else {
            #if DEBUG
            print("❌ 차단 실패: 상대방 ID가 없음")
            #endif
            return
        }
        
        // 강화된 신고 및 차단 (자동 신고 포함)
        UserManager.shared.reportAndBlockUser(opponentUserId, reason: "사용자 차단")
        #if DEBUG
        print("✅ 사용자 신고 및 차단: \(opponentUserId)")
        #endif
        
        // 차단 후 즉시 통화 종료
        endVideoCall()
    }
}

// MARK: - Preview for VideoCallView
struct VideoCallView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCallView()
            .environmentObject(AgoraManager.shared)
            .environmentObject(MatchingManager.shared)
    }
}
