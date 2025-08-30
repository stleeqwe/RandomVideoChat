import SwiftUI
import AgoraRtcKit
import AVFoundation

class AgoraManager: NSObject, ObservableObject {
    // Network monitoring
    private let networkMonitor = NetworkMonitor.shared
    static let shared = AgoraManager()
    
    // Agora 설정
    private let appId: String = {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "AGORA_APP_ID") as? String,
              !appId.isEmpty else {
            fatalError("⚠️ AGORA_APP_ID가 Info.plist에서 찾을 수 없습니다.")
        }
        return appId
    }()
    var agoraKit: AgoraRtcEngineKit?  // Changed from private to internal for VideoCallView access
    
    // 상태 관리
    @Published var isInCall = false
    @Published var remoteUserJoined = false
    @Published var remoteVideoEnabled = false
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
    
    // MARK: - Agora 엔진 설정 (수정됨)
    private func setupAgoraEngine() {
        print("🔧 Agora 엔진 초기화 시작")
        print("📱 App ID: \(appId)")
        
        // 엔진 초기화
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .communication
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        guard let agoraKit = agoraKit else {
            print("❌ Agora 엔진 초기화 실패!")
            return
        }
        
        print("✅ Agora 엔진 초기화 성공")
        
        // 클라이언트 역할 설정
        agoraKit.setClientRole(.broadcaster)
        print("✅ 클라이언트 역할: broadcaster")
        
        // 비디오 활성화 및 설정
        agoraKit.enableVideo()
        
        // 네트워크 적응형 비디오 설정
        updateVideoConfigForNetwork()
        
        // 네트워크 변경 감지 및 자동 조정
        setupNetworkAdaptation()
        
        // 비디오 품질 최적화 및 네트워크 적응 설정
        agoraKit.enableDualStreamMode(true)  // 듀얼 스트림 모드 활성화
        agoraKit.setParameters("{\"rtc.video.prefer_hw_encoder\":true}")  // 하드웨어 인코딩 우선
        agoraKit.setParameters("{\"che.video.videoCodecIndex\":2}")  // H.264 코덱 사용
        
        // 네트워크 적응 최적화
        agoraKit.setParameters("{\"che.video.quickAdaptNetwork\":true}")  // 빠른 네트워크 적응
        agoraKit.setParameters("{\"rtc.adaptive_bitrate\":true}")  // 적응형 비트레이트
        agoraKit.setParameters("{\"rtc.smoothness_first\":true}")  // 끊김없는 재생 우선
        
        print("✅ 비디오 설정 완료")
        
        // 오디오 설정 (중복 제거, 순서 최적화)
        setupAudioConfiguration()
        
        // 로컬 프리뷰는 필요 시에만 설정/시작 (메인 화면 카메라와 충돌 방지)
    }
    
    // MARK: - 오디오 설정 (새로 추가)
    private func setupAudioConfiguration() {
        guard let agoraKit = agoraKit else { return }
        
        // 오디오 세션 설정 (iOS) - 강화된 에코 캔슬레이션
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // videoChat 모드로 최적화된 에코 캔슬레이션 활성화
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .videoChat,  // 비디오 채팅용 에코 캔슬레이션
                                        options: [.defaultToSpeaker, .allowBluetooth])
            // mixWithOthers 제거하여 오디오 피드백 방지
            
            // 샘플레이트와 버퍼 크기 최적화
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms 버퍼로 지연 최소화
            try audioSession.setActive(true)
            print("✅ iOS 오디오 세션 설정 완료 (에코 캔슬레이션 강화)")
        } catch {
            print("❌ iOS 오디오 세션 설정 실패: \(error)")
        }
        
        // Agora 오디오 설정
        agoraKit.enableAudio()
        
        // 오디오 프로파일 - 에코 캔슬레이션 강화
        agoraKit.setAudioProfile(.speechStandard, scenario: .gameStreaming)
        // gameStreaming 시나리오는 더 강력한 에코 캔슬레이션 제공
        
        // 고급 오디오 처리 설정 - 최대 에코 캔슬레이션
        agoraKit.setParameters("{\"che.audio.enable.aec\":true}")
        agoraKit.setParameters("{\"che.audio.enable.aec3\":true}")  // AEC3 알고리즘 사용
        agoraKit.setParameters("{\"che.audio.aec.nlp_enabled\":true}")  // 비선형 처리 활성화
        agoraKit.setParameters("{\"che.audio.aec.delay_agnostic_enabled\":true}")  // 지연 무관 AEC
        agoraKit.setParameters("{\"che.audio.enable.ns\":true}")
        agoraKit.setParameters("{\"che.audio.enable.ns.mode\":2}")  // 더 강력한 노이즈 억제
        agoraKit.setParameters("{\"che.audio.enable.agc\":true}")
        agoraKit.setParameters("{\"che.audio.agc.mode\":2}")  // 적응형 AGC
        
        // 오디오 품질 향상 설정
        agoraKit.setParameters("{\"che.audio.ans.mode\":2}")  // 적응형 노이즈 억제
        agoraKit.setParameters("{\"che.audio.enable.vad\":true}")  // 음성 활동 감지
        agoraKit.setParameters("{\"che.audio.howling.control\":true}")  // 하울링 제어
        
        // 네트워크 적응형 설정
        agoraKit.setParameters("{\"che.audio.enable.dtx\":true}")  // 불연속 전송 (대역폭 절약)
        agoraKit.setParameters("{\"che.audio.enable.fec\":true}")  // 전방 오류 수정
        
        // 오디오 볼륨 설정 - 피드백 방지를 위해 더 낮게 조정
        agoraKit.adjustRecordingSignalVolume(70)  // 85에서 70으로 감소 (하울링 방지)
        agoraKit.adjustPlaybackSignalVolume(80)   // 90에서 80으로 감소
        agoraKit.adjustAudioMixingPlayoutVolume(70)  // 믹싱 볼륨도 제한
        
        // 스피커폰 기본 설정
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        agoraKit.setEnableSpeakerphone(true)
        
        print("✅ 고급 오디오 설정 완료")
    }
    
    // MARK: - 로컬 비디오 설정
    private func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .fit  // hidden 대신 fit 사용
        
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true  // 뷰 경계 처리
        videoCanvas.view = view
        
        agoraKit?.setupLocalVideo(videoCanvas)
        
        // 로컬 비디오 미러링 설정 (전면 카메라)
        agoraKit?.setLocalVideoMirrorMode(.enabled)
        
        DispatchQueue.main.async {
            self.localVideoView = view
        }
        
        print("✅ 로컬 비디오 설정 완료")
    }

    // MARK: - 로컬 프리뷰 제어 (필요 시 시작/중지)
    func ensureLocalPreviewStarted() {
        guard let engine = agoraKit else { return }
        if localVideoView == nil {
            setupLocalVideo()
        }
        engine.startPreview()
        print("▶️ Agora 로컬 프리뷰 시작")
    }
    
    func stopLocalPreviewIfIdle() {
        guard let engine = agoraKit, !isInCall else { return }
        engine.stopPreview()
        print("⏹️ Agora 로컬 프리뷰 중지 (통화 없음)")
    }
    
    // MARK: - 통화 시작 (수정됨)
    func startCall(channel: String, retryCount: Int = 0) {
        print("📱 AgoraManager: startCall - 채널: \(channel), 재시도: \(retryCount)")
        
        guard channel.count <= 64 && !channel.isEmpty else {
            print("❌ 유효하지 않은 채널 이름!")
            return
        }
        
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            print("❌ 네트워크 연결 없음 - 3초 후 재시도")
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        guard let engine = agoraKit else {
            print("❌ Agora 엔진이 초기화되지 않았습니다")
            setupAgoraEngine()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startCall(channel: channel, retryCount: retryCount)
            }
            return
        }
        
        self.channelName = channel
        
        // 오디오 세션 재활성화 (통화 시작 시)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
            print("✅ 오디오 세션 재활성화")
        } catch {
            print("❌ 오디오 세션 재활성화 실패: \(error)")
        }
        
        // 채널 참가 전 오디오/비디오 명시적 활성화
        engine.enableLocalVideo(true)
        engine.enableLocalAudio(true)
        engine.muteLocalAudioStream(false)
        engine.muteLocalVideoStream(false)
        
        // 네트워크 최적화 설정 (모든 네트워크 환경 대응)
        engine.setParameters("{\"rtc.enable_quick_udp_transport\":true}")  // QUIC 전송 활성화
        engine.setParameters("{\"rtc.network.tcp_cc\":true}")  // TCP 혼잡 제어
        engine.setParameters("{\"rtc.network.auto_adjust_target_bitrate\":true}")  // 자동 비트레이트 조정
        engine.setParameters("{\"che.network.adaptive_bitrate_adjust\":true}")  // 적응형 비트레이트
        engine.setParameters("{\"rtc.network.aggressive_report\":true}")  // 공격적 네트워크 리포팅
        engine.setParameters("{\"rtc.network.enable_ice_renomination\":true}")  // ICE 재지명 활성화
        
        // 채널 옵션 설정 (수정됨)
        let options = AgoraRtcChannelMediaOptions()
        options.publishCameraTrack = true
        options.publishMicrophoneTrack = true
        options.clientRoleType = .broadcaster
        options.autoSubscribeVideo = true
        options.autoSubscribeAudio = true
        options.channelProfile = .communication
        
        print("🎯 joinChannel 호출")
        
        let result = engine.joinChannel(
            byToken: nil,
            channelId: channel,
            uid: 0,
            mediaOptions: options
        ) { [weak self] channel, uid, elapsed in
            print("✅ 채널 참가 성공: \(channel), uid: \(uid)")
            self?.localUserId = uid
            DispatchQueue.main.async {
                self?.isInCall = true
                
                // 채널 참가 후 추가 최적화
                self?.agoraKit?.setRemoteDefaultVideoStreamType(.low)  // 초기에는 저화질 스트림
                
                // 네트워크 상태에 따라 고품질 전환 시간 조절
                let delay = self?.networkMonitor.connectionType == .wifi ? 2.0 : 3.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // 네트워크가 좋으면 고화질로 전환
                    if self?.networkMonitor.networkQuality == .excellent || 
                       self?.networkMonitor.networkQuality == .good {
                        self?.agoraKit?.setRemoteDefaultVideoStreamType(.high)
                    }
                }
            }
        }
        
        if result != 0 {
            print("❌ joinChannel 실패: \(result)")
            handleJoinError(result, channel: channel, retryCount: retryCount)
        } else {
            print("✅ joinChannel 호출 성공")
        }
    }
    
    // MARK: - 에러 처리 및 재시도
    private func handleJoinError(_ errorCode: Int32, channel: String, retryCount: Int) {
        switch errorCode {
        case -2:
            print("❌ 잘못된 매개변수")
        case -3:
            print("❌ SDK 초기화 실패")
            // SDK 재초기화 시도
            if retryCount < 3 {
                setupAgoraEngine()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            }
        case -7:
            print("❌ SDK 초기화되지 않음")
            // SDK 초기화 후 재시도
            if retryCount < 3 {
                setupAgoraEngine()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            }
        case -17:
            print("❌ 이미 채널에 참가중")
            // 기존 채널 나가고 재참가
            agoraKit?.leaveChannel(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startCall(channel: channel, retryCount: retryCount + 1)
            }
        default:
            print("❌ 알 수 없는 에러: \(errorCode)")
            // 일반적인 재시도
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            }
        }
    }
    
    // MARK: - 통화 종료
    func endCall() {
        print("📱 통화 종료")
        
        // 오디오 세션 비활성화
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ 오디오 세션 비활성화 실패: \(error)")
        }
        
        agoraKit?.leaveChannel(nil)
        agoraKit?.stopPreview()
        
        DispatchQueue.main.async {
            self.isInCall = false
            self.remoteUserJoined = false
            self.remoteVideoEnabled = false
            self.remoteUserId = 0
            self.channelName = ""
            self.remoteVideoView = nil
        }
    }
    
    // MARK: - 음소거 토글
    func toggleMute() -> Bool {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
        print("🎤 음소거: \(isMuted)")
        return isMuted
    }
    
    // MARK: - 카메라 전환
    func switchCamera() {
        agoraKit?.switchCamera()
        print("📷 카메라 전환")
    }
    
    // MARK: - 카메라 토글
    func toggleCamera() -> Bool {
        isCameraOff.toggle()
        agoraKit?.muteLocalVideoStream(isCameraOff)
        print("📹 카메라: \(isCameraOff ? "OFF" : "ON")")
        return isCameraOff
    }
    
    // MARK: - 디버깅 정보
    func printDebugInfo() {
        print("=== Agora Debug Info ===")
        print("Is In Call: \(isInCall)")
        print("Local User ID: \(localUserId)")
        print("Remote User ID: \(remoteUserId)")
        print("Remote User Joined: \(remoteUserJoined)")
        print("Remote Video Enabled: \(remoteVideoEnabled)")
        print("Channel Name: \(channelName)")
        print("Local Video View: \(localVideoView != nil)")
        print("Remote Video View: \(remoteVideoView != nil)")
        print("========================")
    }
}

// MARK: - Agora Delegate
extension AgoraManager: AgoraRtcEngineDelegate {
    
    // 로컬 사용자가 채널에 성공적으로 참가
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("🎊 채널 참가 완료 - 채널: \(channel), UID: \(uid)")
        
        localUserId = uid
        DispatchQueue.main.async {
            self.isInCall = true
        }
    }
    
    // 원격 사용자가 채널에 참가 (수정됨)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("👤 원격 사용자 참가: \(uid)")
        
        remoteUserId = uid
        
        DispatchQueue.main.async {
            // 먼저 상태를 업데이트
            self.remoteUserJoined = true
            
            // 원격 비디오 뷰 생성 및 설정
            let view = UIView()
            view.backgroundColor = .black
            view.clipsToBounds = true
            self.remoteVideoView = view
            
            // 원격 비디오 설정
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = uid
            videoCanvas.renderMode = .fit  // hidden 대신 fit 사용하여 비디오가 잘리지 않도록
            videoCanvas.view = view
            
            self.agoraKit?.setupRemoteVideo(videoCanvas)
            
            // 비디오 스트림 구독 명시적 설정
            self.agoraKit?.muteRemoteVideoStream(uid, mute: false)
            self.agoraKit?.muteRemoteAudioStream(uid, mute: false)
            
            // 비디오 활성화 상태 설정 (초기값 true로 설정)
            self.remoteVideoEnabled = true
            
            print("✅ 원격 비디오 설정 완료 - 비디오 구독 활성화")
        }
    }
    
    // 원격 사용자가 채널을 떠남
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("👤 원격 사용자 퇴장: \(uid), 이유: \(reason.rawValue)")
        
        if reason == .dropped {
            MatchingManager.shared.signalCallEnd()
        }
        
        DispatchQueue.main.async {
            self.remoteUserJoined = false
            self.remoteVideoEnabled = false
            self.remoteVideoView = nil
            self.remoteUserId = 0
        }
    }
    
    // 연결 상태 변경 및 자동 재연결
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        print("🔌 연결 상태: \(state.rawValue), 이유: \(reason.rawValue)")
        
        switch state {
        case .disconnected:
            print("   ➜ 연결 끊김")
            // 네트워크 문제로 끊긴 경우 재연결 시도
            // Check raw values for network-related disconnections
            // Common network issue codes: 8 (network unavailable), 14 (network interrupted)
            let networkRelatedReasons: [Int] = [8, 14, 9, 10] // networkUnavailable, interrupted, etc.
            if networkRelatedReasons.contains(reason.rawValue) {
                handleReconnection()
            }
        case .connecting:
            print("   ➜ 연결 중...")
        case .connected:
            print("   ➜ 연결됨")
            // 연결 성공 시 비디오 품질 재설정
            updateVideoConfigForNetwork()
        case .reconnecting:
            print("   ➜ 재연결 중...")
            // 재연결 중 낮은 품질로 전환
            agoraKit?.setVideoEncoderConfiguration(
                AgoraVideoEncoderConfiguration(
                    size: AgoraVideoDimension320x240,
                    frameRate: .fps15,
                    bitrate: 200,
                    orientationMode: .adaptative,
                    mirrorMode: .auto
                )
            )
        case .failed:
            print("   ➜ 연결 실패")
            // 연결 실패 시 재시도
            handleConnectionFailure()
        @unknown default:
            break
        }
    }
    
    // 재연결 처리
    private func handleReconnection() {
        print("🔄 재연결 시도 중...")
        // 네트워크 모니터 확인 후 재연결
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.networkMonitor.isConnected == true {
                // 자동으로 Agora가 재연결 시도함
                print("🔄 Agora 자동 재연결 대기 중...")
            }
        }
    }
    
    // 연결 실패 처리
    private func handleConnectionFailure() {
        print("❌ 연결 실패 - 재시도 준비")
        // 채널 정보가 있으면 재접속 시도
        if !channelName.isEmpty {
            endCall()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if self.networkMonitor.isConnected {
                    self.startCall(channel: self.channelName)
                }
            }
        }
    }
    
    // 에러 발생
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("❌ Agora 에러: \(errorCode.rawValue)")
    }
    
    // 경고 발생
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("⚠️ Agora 경고: \(warningCode.rawValue)")
    }
    
    // 원격 사용자의 비디오 상태 변경
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStateChangedOfUid uid: UInt, state: AgoraVideoRemoteState, reason: AgoraVideoRemoteReason, elapsed: Int) {
        print("📹 원격 비디오 상태 변경: UID \(uid), 상태: \(state.rawValue), 이유: \(reason.rawValue)")
        
        DispatchQueue.main.async {
            switch state {
            case .stopped, .failed:
                // frozen 상태는 일시적일 수 있으므로 즉시 비활성화하지 않음
                self.remoteVideoEnabled = false
                print("   ➜ 원격 비디오 비활성화")
            case .frozen:
                // frozen 상태에서는 3초 대기 후 여전히 frozen이면 비활성화
                print("   ➜ 원격 비디오 일시 정지 감지")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // 3초 후에도 여전히 frozen 상태인지 확인
                    if !self.remoteVideoEnabled {
                        print("   ➜ 원격 비디오 복구 실패 - 비활성화 유지")
                    }
                }
            case .starting, .decoding:
                self.remoteVideoEnabled = true
                print("   ➜ 원격 비디오 활성화")
            @unknown default:
                break
            }
        }
    }
    
    // 원격 사용자의 오디오 상태 변경 (새로 추가)
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState, reason: AgoraAudioRemoteReason, elapsed: Int) {
        print("🔊 원격 오디오 상태 변경: UID \(uid), 상태: \(state.rawValue)")
    }
    
    // 첫 원격 비디오 프레임 수신 (새로 추가)
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        print("🎥 첫 원격 비디오 프레임 수신: UID \(uid), 크기: \(size)")
        
        // 첫 프레임 수신 시 비디오 확실히 활성화
        DispatchQueue.main.async {
            self.remoteVideoEnabled = true
            
            // 원격 비디오 뷰가 없으면 다시 설정
            if self.remoteVideoView == nil {
                print("⚠️ 원격 비디오 뷰가 없음 - 재설정")
                let view = UIView()
                view.backgroundColor = .black
                self.remoteVideoView = view
                
                let videoCanvas = AgoraRtcVideoCanvas()
                videoCanvas.uid = uid
                videoCanvas.renderMode = .fit
                videoCanvas.view = view
                
                self.agoraKit?.setupRemoteVideo(videoCanvas)
            }
        }
    }
    
    // 네트워크 품질 보고 및 자동 조정
    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        if uid == 0 {
            print("📶 로컬 네트워크 품질 - TX: \(txQuality.rawValue), RX: \(rxQuality.rawValue)")
            
            // 네트워크 품질에 따른 자동 조정
            DispatchQueue.main.async { [weak self] in
                self?.adjustQualityBasedOnNetwork(txQuality: txQuality, rxQuality: rxQuality)
            }
        } else if uid == remoteUserId {
            print("📶 원격 네트워크 품질 - TX: \(txQuality.rawValue), RX: \(rxQuality.rawValue)")
        }
    }
}

// MARK: - Network Adaptation Methods
extension AgoraManager {
    // 네트워크 적응형 설정
    private func setupNetworkAdaptation() {
        // 네트워크 모니터 관찰
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateVideoConfigForNetwork()
        }
    }
    
    // 네트워크 상태에 따른 비디오 설정 업데이트
    private func updateVideoConfigForNetwork() {
        guard let agoraKit = agoraKit else { return }
        
        let config = networkMonitor.getAdaptiveVideoConfig()
        
        // 비디오 인코더 설정 업데이트
        let videoConfig: AgoraVideoEncoderConfiguration
        
        switch config.resolution {
        case .hd720:
            videoConfig = AgoraVideoEncoderConfiguration(
                size: AgoraVideoDimension1280x720,
                frameRate: AgoraVideoFrameRate(rawValue: config.frameRate) ?? .fps30,
                bitrate: config.bitrate,
                orientationMode: .adaptative,
                mirrorMode: .auto
            )
        case .vga480:
            videoConfig = AgoraVideoEncoderConfiguration(
                size: AgoraVideoDimension640x480,
                frameRate: AgoraVideoFrameRate(rawValue: config.frameRate) ?? .fps24,
                bitrate: config.bitrate,
                orientationMode: .adaptative,
                mirrorMode: .auto
            )
        case .cif360:
            videoConfig = AgoraVideoEncoderConfiguration(
                size: AgoraVideoDimension640x360,
                frameRate: AgoraVideoFrameRate(rawValue: config.frameRate) ?? .fps15,
                bitrate: config.bitrate,
                orientationMode: .adaptative,
                mirrorMode: .auto
            )
        case .qvga240:
            videoConfig = AgoraVideoEncoderConfiguration(
                size: AgoraVideoDimension320x240,
                frameRate: AgoraVideoFrameRate(rawValue: config.frameRate) ?? .fps15,
                bitrate: config.bitrate,
                orientationMode: .adaptative,
                mirrorMode: .auto
            )
        }
        
        videoConfig.degradationPreference = .balanced
        agoraKit.setVideoEncoderConfiguration(videoConfig)
        
        // 오디오 전용 모드 체크
        if networkMonitor.shouldUseAudioOnly() {
            print("⚠️ Poor network detected - switching to audio only mode")
            agoraKit.muteLocalVideoStream(true)
            agoraKit.enableLocalVideo(false)
        } else {
            agoraKit.muteLocalVideoStream(false)
            agoraKit.enableLocalVideo(true)
        }
        
        print("📶 Video config updated for \(networkMonitor.connectionType.description): \(config.bitrate)kbps, \(config.frameRate)fps")
    }
    
    // Agora 네트워크 품질에 따른 조정
    private func adjustQualityBasedOnNetwork(txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        guard let agoraKit = agoraKit else { return }
        
        let worstQuality = max(txQuality.rawValue, rxQuality.rawValue)
        
        switch worstQuality {
        case 0...2: // Excellent to Good
            // 고품질 유지
            break
        case 3...4: // Poor to Bad
            // 품질 감소
            agoraKit.setParameters("{\"che.video.lowBitRateStreamParameter\":{\"width\":320,\"height\":240,\"frameRate\":15,\"bitRate\":200}}")
            agoraKit.setRemoteDefaultVideoStreamType(.low)
        case 5...6: // Very Bad to Down
            // 최저 품질 또는 오디오 전용
            agoraKit.muteLocalVideoStream(true)
            print("⚠️ Network too poor - video disabled")
        default:
            break
        }
    }
}
