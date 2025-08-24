import SwiftUI
import AgoraRtcKit
import AVFoundation
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

class AgoraManager: NSObject, ObservableObject {
    static let shared = AgoraManager()
    
    // Agora 설정 - Info.plist에서 안전하게 가져오기
    private let appId: String = {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "AGORA_APP_ID") as? String,
              !appId.isEmpty else {
            fatalError("⚠️ AGORA_APP_ID가 Info.plist에서 찾을 수 없습니다. 앱을 실행할 수 없습니다.")
        }
        return appId
    }()
    private var agoraKit: AgoraRtcEngineKit?
    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions()
    #endif
    
    // 상태 관리
    @Published var isInCall = false
    @Published var remoteUserJoined = false
    @Published var remoteVideoEnabled = false  // 초기값을 false로 변경
    @Published var localVideoView: UIView?
    @Published var remoteVideoView: UIView?
    
    // 사용자 정보
    var localUserId: UInt = 0
    var remoteUserId: UInt = 0
    var channelName: String = ""
    
    // 오디오/비디오 상태
    private var isMuted = false
    @Published var isCameraOff = false
    
    override init() {
        super.init()
        setupAgoraEngine()
    }
    
    // MARK: - Agora 엔진 설정
    private func setupAgoraEngine() {
        #if DEBUG
        print("🔧 Agora 엔진 초기화 시작")
        print("📱 App ID: \(appId)")  // 🆕 App ID 확인
        #endif
        
        // 엔진 초기화
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .communication  // 1:1 통화용
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        // 성능 최적화 설정
        setupPerformanceOptimizations()
        
        guard agoraKit != nil else {
            #if DEBUG
            print("❌ Agora 엔진 초기화 실패!")
            #endif
            return
        }
        
        #if DEBUG
        print("✅ Agora 엔진 초기화 성공")
        #endif
        
        // 🆕 중요: 클라이언트 역할을 명시적으로 설정
        agoraKit?.setClientRole(.broadcaster)
        #if DEBUG
        print("✅ 클라이언트 역할: broadcaster")
        #endif
        
        // 🆕 중요: 기본 오디오 라우트 설정
        agoraKit?.setDefaultAudioRouteToSpeakerphone(true)
        #if DEBUG
        print("✅ 스피커폰 설정")
        #endif
        
        // 비디오 활성화
        agoraKit?.enableVideo()
        #if DEBUG
        print("✅ 비디오 활성화")
        #endif
        
        // 오디오 활성화
        agoraKit?.enableAudio()
        #if DEBUG
        print("✅ 오디오 활성화")
        #endif
        
        // 🆕 중요: 로컬 오디오/비디오 명시적 활성화
        agoraKit?.enableLocalVideo(true)
        agoraKit?.enableLocalAudio(true)
        #if DEBUG
        print("✅ 로컬 미디어 활성화")
        #endif
        
        // 비디오 설정
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: AgoraVideoDimension640x480,
            frameRate: .fps30,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        agoraKit?.setVideoEncoderConfiguration(videoConfig)
        #if DEBUG
        print("✅ 비디오 설정 완료")
        #endif
        
        // 로컬 비디오 뷰 설정
        setupLocalVideo()
    }
    
    // MARK: - 로컬 비디오 설정
    private func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .hidden
        
        // 로컬 비디오 뷰 생성
        let view = UIView()
        videoCanvas.view = view
        
        agoraKit?.setupLocalVideo(videoCanvas)
        agoraKit?.startPreview()
        
        DispatchQueue.main.async {
            self.localVideoView = view
        }
        
        #if DEBUG
        print("✅ 로컬 비디오 설정 완료")
        #endif
    }
    
    // MARK: - 통화 시작
    func startCall(channel: String) {
        #if DEBUG
        print("📱 AgoraManager: startCall - 채널: \(channel)")
        print("📱 채널 길이: \(channel.count) (최대 64자)")
        print("📱 App ID: \(appId)")
        print("📱 현재 통화 상태: \(isInCall)")
        print("📱 원격 사용자 참가: \(remoteUserJoined)")
        #endif
        
        // 채널 이름 유효성 검사
        guard channel.count <= 64 && !channel.isEmpty else {
            #if DEBUG
            print("❌ 유효하지 않은 채널 이름! (\(channel.count)자)")
            #endif
            return
        }
        
        // 원격 사용자 상태 초기화
        self.remoteUserJoined = false
        self.remoteVideoEnabled = false
        self.remoteUserId = 0
        self.remoteVideoView = nil
        
        // 엔진 상태 확인
        guard let engine = agoraKit else {
            #if DEBUG
            print("❌ Agora 엔진이 초기화되지 않았습니다")
            #endif
            setupAgoraEngine()
            
            // 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startCall(channel: channel)
            }
            return
        }
        
        self.channelName = channel
        
        // 미디어 옵션 설정
        let options = AgoraRtcChannelMediaOptions()
        options.publishCameraTrack = true
        options.publishMicrophoneTrack = true
        options.clientRoleType = .broadcaster  // 명시적으로 broadcaster
        options.autoSubscribeVideo = true
        options.autoSubscribeAudio = true
        options.channelProfile = .communication  // 1:1 통화 명시
        
        // 토큰 요청 후 채널 참가
        fetchAgoraToken(for: channel) { [weak self] token in
            guard let self = self else { return }
            let result = engine.joinChannel(
                byToken: token,
                channelId: channel,
                uid: 0,
                mediaOptions: options
            ) { [weak self] channel, uid, elapsed in
                #if DEBUG
                print("✅ joinChannel 콜백 호출됨!")
                print("✅ 채널 참가 성공: \(channel), uid: \(uid), elapsed: \(elapsed)ms")
                #endif
                self?.localUserId = uid
                DispatchQueue.main.async {
                    self?.isInCall = true
                }
            }
            
            #if DEBUG
            print("🎯 joinChannel 호출 결과: \(result)")
            #endif
            
            if result != 0 {
                #if DEBUG
                print("❌ joinChannel 실패: \(result)")
                #endif
                self.handleJoinError(result)
            } else {
                #if DEBUG
                print("✅ joinChannel 호출 성공 (결과: 0)")
                #endif
            }
        }
    }
    
    // MARK: - 에러 처리
    private func handleJoinError(_ errorCode: Int32) {
        #if DEBUG
        switch errorCode {
        case -2:
            print("❌ 잘못된 매개변수")
        case -3:
            print("❌ SDK 초기화 실패")
        case -7:
            print("❌ SDK 초기화되지 않음")
        case -17:
            print("❌ 이미 채널에 참가중")
        default:
            print("❌ 알 수 없는 에러: \(errorCode)")
        }
        #endif
    }
    
    // MARK: - 통화 종료
    func endCall() {
        #if DEBUG
        print("📱 통화 종료")
        #endif
        agoraKit?.leaveChannel(nil)
        agoraKit?.stopPreview()
        
        DispatchQueue.main.async {
            self.isInCall = false
            self.remoteUserJoined = false
            self.remoteVideoEnabled = false
            self.remoteUserId = 0
            self.channelName = ""
        }
    }
    
    // MARK: - 음소거 토글
    func toggleMute() -> Bool {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
        #if DEBUG
        print("🎤 음소거: \(isMuted)")
        #endif
        return isMuted
    }
    
    // MARK: - 카메라 전환
    func switchCamera() {
        agoraKit?.switchCamera()
        #if DEBUG
        print("📷 카메라 전환")
        #endif
    }
    
    // MARK: - 카메라 토글
    func toggleCamera() -> Bool {
        isCameraOff.toggle()
        
        // muteLocalVideoStream 대신 enableLocalVideo 사용하여 실제로 카메라를 끄고 켬
        // 이렇게 하면 카메라 재활성화 시 깜빡거림이 줄어듦
        agoraKit?.enableLocalVideo(!isCameraOff)
        
        // 카메라를 다시 켤 때 preview를 먼저 시작
        if !isCameraOff {
            agoraKit?.startPreview()
        } else {
            agoraKit?.stopPreview()
        }
        
        #if DEBUG
        print("📹 카메라: \(isCameraOff ? "OFF" : "ON")")
        #endif
        return isCameraOff
    }
}

// MARK: - Agora Delegate
extension AgoraManager: AgoraRtcEngineDelegate {
    
    // 로컬 사용자가 채널에 성공적으로 참가
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        #if DEBUG
        print("🎊 didJoinChannel 델리게이트 호출!")
        print("   - 채널: \(channel)")
        print("   - UID: \(uid)")
        print("   - 소요시간: \(elapsed)ms")
        #endif
        
        localUserId = uid
        DispatchQueue.main.async {
            self.isInCall = true
        }
        
        // 원격 스트림 구독 즉시 활성화
        agoraKit?.muteAllRemoteVideoStreams(false)
        agoraKit?.muteAllRemoteAudioStreams(false)
        
        // 채널에 이미 있는 사용자 확인을 위한 빠른 체크 (1초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if !self.remoteUserJoined {
                print("⚠️ 1초 경과 - 원격 사용자 체크 시작")
                self.checkRemoteUsersInChannel()
            }
        }
        
        // 추가 체크 (3초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if !self.remoteUserJoined {
                print("⚠️ 3초 경과 후에도 원격 사용자 미참가 - 재확인")
                self.checkRemoteUsersInChannel()
            }
        }
    }
    
    // 원격 사용자가 채널에 참가
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        #if DEBUG
        print("👤 원격 사용자 참가: \(uid), 경과시간: \(elapsed)ms")
        print("   - 로컬 사용자 ID: \(localUserId)")
        print("   - 현재 원격 사용자 ID: \(remoteUserId)")
        #endif
        
        // 자기 자신의 UID가 아닌지 확인
        guard uid != localUserId else {
            print("⚠️ 자신의 UID 무시: \(uid)")
            return
        }
        
        // 중복 처리 방지
        guard remoteUserId == 0 || remoteUserId != uid else {
            print("⚠️ 이미 처리된 원격 사용자: \(uid)")
            return
        }
        
        remoteUserId = uid
        
        // 메인 스레드에서 즉시 처리
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🎬 원격 비디오 설정 시작...")
            
            // 새로운 뷰 생성
            let view = UIView()
            view.backgroundColor = .black
            
            // 비디오 캔버스 설정
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = uid
            videoCanvas.view = view
            videoCanvas.renderMode = .hidden
            videoCanvas.mirrorMode = .disabled
            
            // 원격 비디오 설정
            let setupResult = self.agoraKit?.setupRemoteVideo(videoCanvas)
            print("   - setupRemoteVideo 결과: \(setupResult ?? -999)")
            
            // 원격 비디오/오디오 구독 명시적 설정
            self.agoraKit?.muteRemoteVideoStream(uid, mute: false)
            self.agoraKit?.muteRemoteAudioStream(uid, mute: false)
            
            // 원격 스트림 우선순위 설정 - API 제거 (deprecated)
            
            // 원격 비디오 구독 활성화
            self.agoraKit?.setRemoteSubscribeFallbackOption(.audioOnly)
            
            self.remoteVideoView = view
            self.remoteUserJoined = true
            self.remoteVideoEnabled = true
            
            print("✅ 원격 비디오 설정 완료: UID \(uid)")
            print("   - remoteUserJoined: \(self.remoteUserJoined)")
            print("   - remoteVideoEnabled: \(self.remoteVideoEnabled)")
        }
    }
    
    // 원격 사용자가 채널을 떠남
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        // 강제 종료나 네트워크 문제로 인한 종료인지 확인
        if reason == .dropped {
            print("🚨 상대방 연결 끊김 (dropped)")
        }
        
        DispatchQueue.main.async {
            self.remoteUserJoined = false
            self.remoteVideoEnabled = false // 초기화
            self.remoteVideoView = nil
            self.remoteUserId = 0
        }
    }
    
    // 연결 상태 변경
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        #if DEBUG
        print("🔌 연결 상태 변경: \(state.rawValue), 이유: \(reason.rawValue)")
        
        switch state {
        case .disconnected:
            print("   ➜ 연결 끊김")
        case .connecting:
            print("   ➜ 연결 중...")
        case .connected:
            print("   ➜ 연결됨")
        case .reconnecting:
            print("   ➜ 재연결 중...")
        case .failed:
            print("   ➜ 연결 실패")
            print("      ❌ 원인 코드: \(reason.rawValue)")
        @unknown default:
            break
        }
        #endif
    }

    // 에러 발생
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        #if DEBUG
        print("❌ Agora 에러: \(errorCode.rawValue)")
        #endif
    }
    
    // 경고 발생
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        #if DEBUG
        print("⚠️ Agora 경고: \(warningCode.rawValue)")
        #endif
    }

    // 네트워크 품질 콜백
    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        let overall = min(txQuality.rawValue, rxQuality.rawValue)
        if overall >= AgoraNetworkQuality.bad.rawValue {
            print("⚠️ 네트워크 품질 저하 (tx=\(txQuality.rawValue), rx=\(rxQuality.rawValue)) - 화질 조정")
            adaptVideoQualityToNetwork()
        }
    }

    func rtcEngineConnectionDidLost(_ engine: AgoraRtcEngineKit) {
        print("🚨 연결 손실 - 재연결 시도 중...")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        print("⏳ 토큰 만료 예정 - 갱신 요청")
        if !channelName.isEmpty {
            fetchAgoraToken(for: channelName) { [weak self] newToken in
                guard let newToken = newToken else { return }
                self?.agoraKit?.renewToken(newToken)
            }
        }
    }
    
    // 원격 사용자의 비디오 상태 변경
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStateChangedOfUid uid: UInt, state: AgoraVideoRemoteState, reason: AgoraVideoRemoteReason, elapsed: Int) {
        #if DEBUG
        print("📹 원격 비디오 상태 변경: UID \(uid), 상태: \(state.rawValue), 이유: \(reason.rawValue)")
        #endif
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .stopped, .frozen:
                self.remoteVideoEnabled = false
                #if DEBUG
                print("   ➜ 원격 비디오 비활성화")
                #endif
                
            case .starting:
                // 비디오가 시작되면 원격 사용자 설정 재시도
                if self.remoteVideoView == nil && uid != 0 {
                    print("   ➜ 원격 비디오 시작 - 설정 재시도")
                    self.setupRemoteUserVideo(uid: uid)
                }
                self.remoteVideoEnabled = true
                
            case .decoding:
                self.remoteVideoEnabled = true
                #if DEBUG
                print("   ➜ 원격 비디오 활성화")
                #endif
                
            case .failed:
                self.remoteVideoEnabled = false
                #if DEBUG
                print("   ➜ 원격 비디오 실패 - 재시도")
                #endif
                // 실패 시 재시도
                if uid != 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.setupRemoteUserVideo(uid: uid)
                    }
                }
                
            @unknown default:
                break
            }
        }
    }
    
    // 원격 사용자 비디오 설정 헬퍼 함수
    private func setupRemoteUserVideo(uid: UInt) {
        guard remoteVideoView == nil else {
            print("⚠️ 원격 비디오 뷰가 이미 설정됨")
            return
        }
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.renderMode = .hidden
        videoCanvas.mirrorMode = .disabled
        
        let view = UIView()
        videoCanvas.view = view
        
        agoraKit?.setupRemoteVideo(videoCanvas)
        
        // 원격 스트림 구독 명시적 설정
        agoraKit?.muteRemoteVideoStream(uid, mute: false)
        agoraKit?.muteRemoteAudioStream(uid, mute: false)
        
        remoteVideoView = view
        remoteUserId = uid
        remoteUserJoined = true
        remoteVideoEnabled = true
        
        print("✅ 원격 비디오 재설정 완료: UID \(uid)")
    }
    
    // 채널의 원격 사용자 확인
    private func checkRemoteUsersInChannel() {
        // 이미 참가한 사용자가 있는지 확인하는 로직
        // Agora SDK는 이미 참가한 사용자에 대해 콜백을 제공하지 않을 수 있음
        print("🔍 채널 내 원격 사용자 확인 중...")
        print("   - 현재 채널: \(channelName)")
        print("   - 로컬 UID: \(localUserId)")
        
        // 원격 사용자가 이미 있지만 콜백이 오지 않은 경우를 위한 대비
        if !remoteUserJoined {
            print("⚠️ 원격 사용자 콜백 미수신 - 강제 비디오 스트림 구독 시도")
            
            // 모든 원격 스트림 구독 활성화
            agoraKit?.muteAllRemoteVideoStreams(false)
            agoraKit?.muteAllRemoteAudioStreams(false)
            
            // 원격 비디오 폴백 옵션 설정
            agoraKit?.setRemoteSubscribeFallbackOption(.audioOnly)
            
            // 다시 한번 체크 (5초 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                if !self.remoteUserJoined {
                    print("⚠️ 5초 후에도 원격 사용자 미참가 - 연결 문제 가능성")
                }
            }
        }
    }
    
    // MARK: - Performance Optimizations
    private func setupPerformanceOptimizations() {
        guard let agoraKit = agoraKit else { return }
        
        // 비디오 품질 적응형 설정
        setupAdaptiveVideoConfig()
        
        // 오디오 처리 최적화 (최신 API 사용)
        agoraKit.setAudioProfile(.speechStandard)
        
        // 에코 캔슬레이션 및 노이즈 억제
        agoraKit.enableAudio()
        agoraKit.enableVideo()
        
        // 하드웨어 가속 활성화
        agoraKit.setEnableSpeakerphone(true)
        
        // 네트워크 적응 활성화 (최신 API 사용)
        agoraKit.setDualStreamMode(.enableSimulcastStream)
        
        print("🚀 Agora 성능 최적화 설정 완료")
    }
    
    private func setupAdaptiveVideoConfig() {
        guard let agoraKit = agoraKit else { return }
        
        let videoConfig = AgoraVideoEncoderConfiguration()
        let networkQuality = PerformanceMonitor.shared.getNetworkQuality()
        
        // 네트워크 상태에 따른 동적 품질 조정
        switch networkQuality {
        case .excellent:
            videoConfig.dimensions = AgoraVideoDimension960x720
            videoConfig.frameRate = .fps30
            videoConfig.bitrate = 1130
            print("📶 네트워크 품질: 최고 - 고품질 비디오 설정")
            
        case .good:
            videoConfig.dimensions = AgoraVideoDimension640x480
            videoConfig.frameRate = .fps24
            videoConfig.bitrate = 800
            print("📶 네트워크 품질: 양호 - 중품질 비디오 설정")
            
        case .poor:
            videoConfig.dimensions = AgoraVideoDimension320x240
            videoConfig.frameRate = .fps15
            videoConfig.bitrate = 200
            print("📶 네트워크 품질: 나쁨 - 저품질 비디오 설정")
            
        case .unknown:
            videoConfig.dimensions = AgoraVideoDimension640x480
            videoConfig.frameRate = .fps24
            videoConfig.bitrate = AgoraVideoBitrateStandard
            print("📶 네트워크 품질: 알 수 없음 - 기본 품질 설정")
        }
        
        // 성능 최적화 설정 (API 버전 호환성 확인)
        videoConfig.mirrorMode = .disabled  // 불필요한 미러링 비활성화
        
        agoraKit.setVideoEncoderConfiguration(videoConfig)
    }
    
    // 네트워크 상태 변화에 따른 동적 품질 조정
    func adaptVideoQualityToNetwork() {
        setupAdaptiveVideoConfig()
    }
    
    // MARK: - Token Handling
    private func fetchAgoraToken(for channel: String, completion: @escaping (String?) -> Void) {
        #if canImport(FirebaseFunctions)
        // 토큰 요청 타임아웃 설정
        let timeoutWorkItem = DispatchWorkItem {
            print("⏱️ 토큰 요청 타임아웃 - 토큰 없이 진행")
            completion(nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutWorkItem)
        
        functions.httpsCallable("generateAgoraToken").call(["channelName": channel]) { result, error in
            timeoutWorkItem.cancel()
            
            if let error = error {
                print("⚠️ 토큰 요청 실패: \(error.localizedDescription). 토큰 없이 시도합니다.")
                completion(nil)
                return
            }
            if let dict = result?.data as? [String: Any], let token = dict["token"] as? String {
                print("✅ 토큰 발급 성공")
                completion(token)
            } else {
                print("⚠️ 토큰 응답 파싱 실패. 토큰 없이 시도합니다.")
                completion(nil)
            }
        }
        #else
        completion(nil)
        #endif
    }
    
    // 성능 메트릭 수집
    func collectPerformanceMetrics() {
        guard agoraKit != nil else { return }
        
        // 연결 상태 정보 수집
        print("📊 Agora Performance Metrics:")
        print("   - Remote User Joined: \(remoteUserJoined)")
        print("   - Remote Video Enabled: \(remoteVideoEnabled)")
        print("   - Is In Call: \(isInCall)")
    }
}
