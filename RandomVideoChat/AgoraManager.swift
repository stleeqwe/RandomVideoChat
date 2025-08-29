import SwiftUI
import AgoraRtcKit
import AVFoundation

class AgoraManager: NSObject, ObservableObject {
    static let shared = AgoraManager()
    
    // Agora 설정
    private let appId: String = {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "AGORA_APP_ID") as? String,
              !appId.isEmpty else {
            fatalError("⚠️ AGORA_APP_ID가 Info.plist에서 찾을 수 없습니다.")
        }
        return appId
    }()
    private var agoraKit: AgoraRtcEngineKit?
    
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
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: AgoraVideoDimension640x480,
            frameRate: .fps30,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        agoraKit.setVideoEncoderConfiguration(videoConfig)
        print("✅ 비디오 설정 완료")
        
        // 오디오 설정 (중복 제거, 순서 최적화)
        setupAudioConfiguration()
        
        // 로컬 비디오 뷰 설정
        setupLocalVideo()
    }
    
    // MARK: - 오디오 설정 (새로 추가)
    private func setupAudioConfiguration() {
        guard let agoraKit = agoraKit else { return }
        
        // 오디오 세션 설정 (iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("✅ iOS 오디오 세션 설정 완료")
        } catch {
            print("❌ iOS 오디오 세션 설정 실패: \(error)")
        }
        
        // Agora 오디오 설정
        agoraKit.enableAudio()
        
        // 오디오 프로파일 설정 (음질과 에코 캔슬레이션)
        agoraKit.setAudioProfile(.musicHighQualityStereo, scenario: .chatRoom)
        
        // 에코 캔슬레이션 및 노이즈 억제 강화
        agoraKit.setParameters("{\"che.audio.enable.aec\":true}")
        agoraKit.setParameters("{\"che.audio.enable.ns\":true}")
        agoraKit.setParameters("{\"che.audio.enable.agc\":true}")
        
        // 오디오 볼륨 설정
        agoraKit.adjustRecordingSignalVolume(100)
        agoraKit.adjustPlaybackSignalVolume(100)
        
        // 스피커폰 기본 설정
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        
        print("✅ 오디오 설정 완료")
    }
    
    // MARK: - 로컬 비디오 설정
    private func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .hidden
        
        let view = UIView()
        view.backgroundColor = .black
        videoCanvas.view = view
        
        agoraKit?.setupLocalVideo(videoCanvas)
        agoraKit?.startPreview()
        
        DispatchQueue.main.async {
            self.localVideoView = view
        }
        
        print("✅ 로컬 비디오 설정 완료")
    }
    
    // MARK: - 통화 시작 (수정됨)
    func startCall(channel: String) {
        print("📱 AgoraManager: startCall - 채널: \(channel)")
        
        guard channel.count <= 64 && !channel.isEmpty else {
            print("❌ 유효하지 않은 채널 이름!")
            return
        }
        
        guard let engine = agoraKit else {
            print("❌ Agora 엔진이 초기화되지 않았습니다")
            setupAgoraEngine()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startCall(channel: channel)
            }
            return
        }
        
        self.channelName = channel
        
        // 채널 참가 전 오디오/비디오 명시적 활성화
        engine.enableLocalVideo(true)
        engine.enableLocalAudio(true)
        
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
            }
        }
        
        if result != 0 {
            print("❌ joinChannel 실패: \(result)")
            handleJoinError(result)
        } else {
            print("✅ joinChannel 호출 성공")
        }
    }
    
    // MARK: - 에러 처리
    private func handleJoinError(_ errorCode: Int32) {
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
            self.remoteVideoView = view
            
            // 원격 비디오 설정
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = uid
            videoCanvas.renderMode = .hidden
            videoCanvas.view = view
            
            self.agoraKit?.setupRemoteVideo(videoCanvas)
            
            // 비디오 활성화 상태 설정
            self.remoteVideoEnabled = true
            
            print("✅ 원격 비디오 설정 완료")
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
    
    // 연결 상태 변경
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        print("🔌 연결 상태: \(state.rawValue), 이유: \(reason.rawValue)")
        
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
        @unknown default:
            break
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
        print("📹 원격 비디오 상태 변경: UID \(uid), 상태: \(state.rawValue)")
        
        DispatchQueue.main.async {
            switch state {
            case .stopped, .frozen, .failed:
                self.remoteVideoEnabled = false
            case .starting, .decoding:
                self.remoteVideoEnabled = true
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
    }
    
    // 네트워크 품질 보고 (새로 추가)
    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        if uid == 0 {
            print("📶 로컬 네트워크 품질 - TX: \(txQuality.rawValue), RX: \(rxQuality.rawValue)")
        } else if uid == remoteUserId {
            print("📶 원격 네트워크 품질 - TX: \(txQuality.rawValue), RX: \(rxQuality.rawValue)")
        }
    }
}