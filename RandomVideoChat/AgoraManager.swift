import SwiftUI
import AgoraRtcKit
import AVFoundation
import Combine

// MARK: - Connection State
enum AgoraConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(AgoraConnectionError)

    static func == (lhs: AgoraConnectionState, rhs: AgoraConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.reconnecting, .reconnecting):
            return true
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

enum AgoraConnectionError: Error, Equatable {
    case tokenInvalid
    case tokenExpired
    case kicked
    case networkError
    case joinFailed(Int32)
    case unknown
}

// MARK: - AgoraManager
/// Production-grade Agora RTC Manager
/// Features:
/// - Proper lifecycle management with memory cleanup
/// - Token authentication integration
/// - Network quality adaptation via NetworkManager
/// - Comprehensive error handling and reconnection
/// - Thread-safe state management
final class AgoraManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = AgoraManager()

    // MARK: - Configuration
    private struct Config {
        static let appId: String = {
            guard let appId = Bundle.main.object(forInfoDictionaryKey: "AGORA_APP_ID") as? String,
                  !appId.isEmpty else {
                #if DEBUG
                print("❌ AGORA_APP_ID not found in Info.plist - Video calls will not work")
                #endif
                return ""
            }
            return appId
        }()

        // Timeouts
        static let joinTimeout: TimeInterval = 30
        static let engineIdleTimeout: TimeInterval = 300  // 5 minutes

        // Video defaults
        static let defaultWidth: Int = 640
        static let defaultHeight: Int = 480
        static let defaultFrameRate: Int = 24
        static let defaultBitrate: Int = 800
    }

    // MARK: - Published Properties
    @Published private(set) var connectionState: AgoraConnectionState = .disconnected
    @Published var isInCall = false
    @Published var remoteUserJoined = false
    @Published var remoteVideoEnabled = false
    @Published var remoteCameraMuted = false
    @Published var localVideoView: UIView?
    @Published var remoteVideoView: UIView?
    @Published var isCameraOff = false
    @Published var isSpeakerEnabled = false

    // Expose engine for video canvas setup
    var agoraKit: AgoraRtcEngineKit? { engine }

    // MARK: - Private Properties
    private var engine: AgoraRtcEngineKit?
    private var localUserId: UInt = 0
    private var remoteUserId: UInt = 0
    private var channelName: String = ""
    private var currentToken: String?

    // State flags
    private var isMuted = false
    private var isJoining = false

    // Lifecycle management
    private var engineCreatedAt: Date?
    private var engineIdleTimer: Timer?
    private var joinTimeoutWorkItem: DispatchWorkItem?

    // Thread safety
    private let stateLock = NSLock()

    // Subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var lastNetworkType: NetworkType = .unknown

    // MARK: - Initialization
    private override init() {
        super.init()
        setupEngine()
        observeNetworkChanges()
        #if DEBUG
        print("🎬 AgoraManager initialized")
        #endif
    }

    deinit {
        cleanup()
        #if DEBUG
        print("🎬 AgoraManager deinitialized")
        #endif
    }

    // MARK: - Engine Setup
    private func setupEngine() {
        #if DEBUG
        print("🔧 Initializing Agora engine...")
        #endif

        let config = AgoraRtcEngineConfig()
        config.appId = Config.appId
        config.channelProfile = .communication
        config.audioScenario = .chatRoom

        engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engineCreatedAt = Date()

        guard let engine = engine else {
            #if DEBUG
            print("❌ Failed to create Agora engine")
            #endif
            return
        }

        configureEngine(engine)
    }

    private func configureEngine(_ engine: AgoraRtcEngineKit) {
        // Client role
        engine.setClientRole(.broadcaster)

        // Enable video
        engine.enableVideo()

        // Video encoder configuration
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: CGSize(width: Config.defaultWidth, height: Config.defaultHeight),
            frameRate: .fps24,
            bitrate: Config.defaultBitrate,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        videoConfig.degradationPreference = .maintainFramerate
        engine.setVideoEncoderConfiguration(videoConfig)

        // Dual stream for adaptive quality
        engine.enableDualStreamMode(true)

        // Hardware encoding preference
        engine.setParameters("{\"che.video.prefer_hw_encoder\":true}")
        engine.setParameters("{\"che.hardware_encoding\":1}")
        engine.setParameters("{\"che.hardware_decoding\":1}")

        // Fallback options
        engine.setLocalPublishFallbackOption(.audioOnly)
        engine.setRemoteSubscribeFallbackOption(.audioOnly)

        // Network adaptation
        engine.setParameters("{\"che.video.quickAdaptNetwork\":true}")
        engine.setParameters("{\"rtc.adaptive_bitrate\":true}")

        // Audio configuration
        configureAudio(engine)

        #if DEBUG
        print("✅ Engine configured")
        #endif
    }

    private func configureAudio(_ engine: AgoraRtcEngineKit) {
        // iOS Audio Session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker])
            try? audioSession.setPreferredSampleRate(48000)
            try? audioSession.setPreferredIOBufferDuration(0.01)
            try audioSession.setActive(true)
        } catch {
            #if DEBUG
            print("❌ Audio session error: \(error)")
            #endif
        }

        // Agora audio
        engine.enableAudio()
        engine.setAudioProfile(.musicHighQualityStereo, scenario: .chatRoom)

        // AI noise suppression
        engine.setParameters("{\"che.audio.enable.aec3\":true}")
        engine.setParameters("{\"che.audio.enable.ns\":true}")
        engine.setParameters("{\"che.audio.enable.ns.mode\":2}")
        engine.setParameters("{\"che.audio.enable.agc\":true}")

        // Audio routing - use speaker by default for video chat
        engine.setDefaultAudioRouteToSpeakerphone(true)
        engine.setEnableSpeakerphone(true)
        isSpeakerEnabled = true

        // Volume - boost playback volume for better audibility
        engine.adjustRecordingSignalVolume(100)
        engine.adjustPlaybackSignalVolume(200)
    }

    // MARK: - Network Observation
    private func observeNetworkChanges() {
        NetworkManager.shared.onQualityChanged = { [weak self] quality, preset in
            self?.handleNetworkQualityChange(quality, preset: preset)
        }

        // Observe network type changes
        NetworkManager.shared.$networkType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newType in
                guard let self = self else { return }
                let oldType = self.lastNetworkType
                self.lastNetworkType = newType

                if oldType == .wifi && newType == .cellular && self.isInCall {
                    self.handleNetworkTypeSwitch()
                }
            }
            .store(in: &cancellables)
    }

    private func handleNetworkQualityChange(_ quality: NetworkQuality, preset: VideoQualityPreset) {
        guard let engine = engine else { return }

        let config = AgoraVideoEncoderConfiguration(
            size: CGSize(width: preset.width, height: preset.height),
            frameRate: AgoraVideoFrameRate(rawValue: preset.frameRate) ?? .fps24,
            bitrate: preset.bitrate,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        config.minBitrate = preset.minBitrate
        config.degradationPreference = .balanced

        engine.setVideoEncoderConfiguration(config)

        #if DEBUG
        print("📹 Video config updated: \(preset.width)x\(preset.height)@\(preset.frameRate)fps")
        #endif
    }

    private func handleNetworkTypeSwitch() {
        guard let engine = engine, remoteUserId != 0 else { return }

        #if DEBUG
        print("📡 Network switch detected - temporarily lowering quality")
        #endif

        engine.setRemoteVideoStream(remoteUserId, type: .low)

        // Restore after cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, let engine = self.engine, self.remoteUserId != 0 else { return }
            if NetworkManager.shared.networkQuality.rawValue <= NetworkQuality.good.rawValue {
                engine.setRemoteVideoStream(self.remoteUserId, type: .high)
            }
        }
    }

    // MARK: - Public API: Call Management

    /// Start a video call
    func startCall(channel: String, retryCount: Int = 0) {
        guard !channel.isEmpty, channel.count <= 64 else {
            #if DEBUG
            print("❌ Invalid channel name")
            #endif
            return
        }

        guard !isJoining && !isInCall else {
            #if DEBUG
            print("⚠️ Already joining or in call")
            #endif
            return
        }

        guard NetworkManager.shared.isConnected else {
            #if DEBUG
            print("❌ No network - retrying in 3s")
            #endif
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            }
            return
        }

        isJoining = true
        channelName = channel
        updateConnectionState(.connecting)

        // Ensure engine exists
        if engine == nil {
            setupEngine()
        }

        guard let engine = engine else {
            isJoining = false
            updateConnectionState(.failed(.unknown))
            return
        }

        // Activate audio session
        try? AVAudioSession.sharedInstance().setActive(true)

        // Enable media
        engine.enableLocalAudio(true)
        engine.enableLocalVideo(true)
        engine.muteLocalAudioStream(false)
        engine.muteLocalVideoStream(false)

        // Get stable local UID
        let uid = getOrCreateLocalUid()

        // Fetch token if enabled
        if TokenProvider.shared.isEnabled() {
            TokenProvider.shared.fetchToken(channel: channel, uid: uid) { [weak self] token in
                DispatchQueue.main.async {
                    self?.joinChannel(channel: channel, token: token, uid: uid, retryCount: retryCount)
                }
            }
        } else {
            joinChannel(channel: channel, token: nil, uid: uid, retryCount: retryCount)
        }

        // Start timeout
        startJoinTimeout(channel: channel, retryCount: retryCount)
    }

    private func joinChannel(channel: String, token: String?, uid: UInt, retryCount: Int = 0) {
        guard let engine = engine else { return }

        currentToken = token

        let options = AgoraRtcChannelMediaOptions()
        options.publishCameraTrack = true
        options.publishMicrophoneTrack = true
        options.autoSubscribeVideo = true
        options.autoSubscribeAudio = true
        options.clientRoleType = .broadcaster
        options.channelProfile = .communication

        #if DEBUG
        print("📞 Joining channel: \(channel), UID: \(uid), token: \(token != nil)")
        #endif

        let result = engine.joinChannel(
            byToken: token,
            channelId: channel,
            uid: uid,
            mediaOptions: options
        )

        if result != 0 {
            #if DEBUG
            print("❌ Join failed: \(result)")
            #endif
            handleJoinError(result, channel: channel, retryCount: retryCount)
        }
    }

    /// End the current call
    func endCall() {
        #if DEBUG
        print("📞 Ending call")
        #endif

        joinTimeoutWorkItem?.cancel()
        joinTimeoutWorkItem = nil

        guard let engine = engine else {
            resetState()
            return
        }

        // Clear video canvases
        clearVideoCanvas(uid: 0, isLocal: true)
        if remoteUserId != 0 {
            clearVideoCanvas(uid: remoteUserId, isLocal: false)
        }

        // Stop media
        engine.disableVideo()
        engine.disableAudio()
        engine.stopPreview()
        engine.leaveChannel(nil)

        // Reset state
        resetState()

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        // Schedule engine cleanup
        scheduleEngineCleanup()
    }

    // MARK: - Public API: Media Controls

    func toggleMute() -> Bool {
        isMuted.toggle()
        engine?.muteLocalAudioStream(isMuted)
        #if DEBUG
        print("🎤 Muted: \(isMuted)")
        #endif
        return isMuted
    }

    func toggleCamera() -> Bool {
        isCameraOff.toggle()
        // 실제 비디오 송출 제어
        engine?.muteLocalVideoStream(isCameraOff)
        if isCameraOff {
            engine?.stopPreview()
        } else {
            engine?.startPreview()
        }
        #if DEBUG
        print("📹 Camera off: \(isCameraOff)")
        #endif
        return isCameraOff
    }

    func switchCamera() {
        engine?.switchCamera()
    }

    func setSpeakerEnabled(_ enabled: Bool) {
        isSpeakerEnabled = enabled
        engine?.setEnableSpeakerphone(enabled)
        #if DEBUG
        print("🔊 Speaker: \(enabled)")
        #endif
    }

    func toggleSpeaker() -> Bool {
        setSpeakerEnabled(!isSpeakerEnabled)
        return isSpeakerEnabled
    }

    func applyRemoteCameraMuted(_ muted: Bool) {
        guard remoteUserId != 0 else { return }
        DispatchQueue.main.async {
            self.remoteCameraMuted = muted
        }
    }

    // MARK: - Public API: Video Setup

    func ensureLocalPreviewStarted() {
        guard let engine = engine else { return }
        if localVideoView == nil {
            setupLocalVideoView()
        }
        engine.startPreview()
    }

    func stopLocalPreviewIfIdle() {
        guard let engine = engine, !isInCall else { return }
        engine.stopPreview()
    }

    private func setupLocalVideoView() {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true

        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = 0
        canvas.view = view
        canvas.renderMode = .hidden

        engine?.setupLocalVideo(canvas)
        engine?.setLocalVideoMirrorMode(.enabled)

        DispatchQueue.main.async {
            self.localVideoView = view
        }
    }

    private func clearVideoCanvas(uid: UInt, isLocal: Bool) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.view = nil
        if isLocal {
            engine?.setupLocalVideo(canvas)
        } else {
            engine?.setupRemoteVideo(canvas)
        }
    }

    private func setupRemoteVideoView(for uid: UInt) {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true

        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.view = view
        canvas.renderMode = .fit

        engine?.setupRemoteVideo(canvas)
        engine?.muteRemoteVideoStream(uid, mute: false)
        engine?.muteRemoteAudioStream(uid, mute: false)

        DispatchQueue.main.async {
            self.remoteVideoView = view
            self.remoteVideoEnabled = true
        }
    }

    // MARK: - Private: State Management

    private func updateConnectionState(_ state: AgoraConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
        }
    }

    private func resetState() {
        stateLock.lock()
        defer { stateLock.unlock() }

        isInCall = false
        isJoining = false
        remoteUserJoined = false
        remoteVideoEnabled = false
        remoteCameraMuted = false
        isMuted = false
        remoteUserId = 0
        channelName = ""
        currentToken = nil
        localVideoView = nil
        remoteVideoView = nil

        updateConnectionState(.disconnected)
    }

    // MARK: - Private: UID Management

    private func getOrCreateLocalUid() -> UInt {
        // Try to load from Keychain first (secure storage)
        if let stored = KeychainManager.loadUInt(forKey: .agoraLocalUid), stored > 0 {
            localUserId = stored
            return localUserId
        }

        // Migration: Check UserDefaults for legacy data
        let legacyKey = "agora_local_uid"
        if let legacyStored = UserDefaults.standard.object(forKey: legacyKey) as? Int, legacyStored > 0 {
            let uid = UInt(legacyStored)
            // Migrate to Keychain
            _ = KeychainManager.save(uid, forKey: .agoraLocalUid)
            // Remove from UserDefaults
            UserDefaults.standard.removeObject(forKey: legacyKey)
            localUserId = uid
            #if DEBUG
            print("🔐 Migrated Agora UID to Keychain")
            #endif
            return localUserId
        }

        // Generate new UID and save to Keychain
        let newUid = UInt(Int.random(in: 1...(Int(UInt32.max) - 1)))
        _ = KeychainManager.save(newUid, forKey: .agoraLocalUid)
        localUserId = newUid
        return localUserId
    }

    // MARK: - Private: Timeout & Error Handling

    private func startJoinTimeout(channel: String, retryCount: Int) {
        joinTimeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isJoining else { return }
            #if DEBUG
            print("⏰ Join timeout")
            #endif
            self.isJoining = false
            self.updateConnectionState(.failed(.networkError))

            if retryCount < 3 {
                self.startCall(channel: channel, retryCount: retryCount + 1)
            }
        }

        joinTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.joinTimeout, execute: workItem)
    }

    private func handleJoinError(_ code: Int32, channel: String, retryCount: Int) {
        isJoining = false

        switch code {
        case -2, -3, -7:
            // SDK error - reinitialize
            if retryCount < 3 {
                setupEngine()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            }
        case -17:
            // Already in channel - leave and rejoin
            engine?.leaveChannel(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startCall(channel: channel, retryCount: retryCount + 1)
            }
        case 110, 8:
            // Token error
            updateConnectionState(.failed(.tokenInvalid))
        default:
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) { [weak self] in
                    self?.startCall(channel: channel, retryCount: retryCount + 1)
                }
            } else {
                updateConnectionState(.failed(.joinFailed(code)))
            }
        }
    }

    private func handleTokenRefresh() {
        guard !channelName.isEmpty else { return }

        TokenProvider.shared.fetchToken(channel: channelName, uid: localUserId) { [weak self] newToken in
            guard let self = self, let token = newToken else {
                self?.updateConnectionState(.failed(.tokenExpired))
                return
            }
            DispatchQueue.main.async {
                self.currentToken = token
                self.engine?.renewToken(token)
                #if DEBUG
                print("🔐 Token renewed")
                #endif
            }
        }
    }

    // MARK: - Private: Engine Lifecycle

    private func scheduleEngineCleanup() {
        engineIdleTimer?.invalidate()
        engineIdleTimer = Timer.scheduledTimer(
            withTimeInterval: Config.engineIdleTimeout,
            repeats: false
        ) { [weak self] _ in
            self?.destroyEngine()
        }
    }

    private func destroyEngine() {
        guard engine != nil else { return }

        #if DEBUG
        print("🧹 Destroying Agora engine")
        #endif

        AgoraRtcEngineKit.destroy()
        engine = nil
        engineCreatedAt = nil
    }

    private func cleanup() {
        joinTimeoutWorkItem?.cancel()
        engineIdleTimer?.invalidate()
        cancellables.removeAll()

        if engine != nil {
            engine?.leaveChannel(nil)
            AgoraRtcEngineKit.destroy()
            engine = nil
        }
    }

    // MARK: - Debug

    func printDebugInfo() {
        print("=== Agora Debug Info ===")
        print("Connection: \(connectionState)")
        print("Is In Call: \(isInCall)")
        print("Local UID: \(localUserId)")
        print("Remote UID: \(remoteUserId)")
        print("Channel: \(channelName)")
        print("========================")
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraManager: AgoraRtcEngineDelegate {

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        #if DEBUG
        print("✅ Joined channel: \(channel), UID: \(uid)")
        #endif

        joinTimeoutWorkItem?.cancel()
        joinTimeoutWorkItem = nil

        localUserId = uid
        isJoining = false

        DispatchQueue.main.async {
            self.isInCall = true
            self.updateConnectionState(.connected)
        }

        // Initial quality setting
        engine.setRemoteDefaultVideoStreamType(.low)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if NetworkManager.shared.networkQuality.rawValue <= NetworkQuality.good.rawValue {
                self?.engine?.setRemoteDefaultVideoStreamType(.high)
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        #if DEBUG
        print("👤 Remote user joined: \(uid)")
        #endif

        remoteUserId = uid

        DispatchQueue.main.async {
            self.remoteUserJoined = true
            self.setupRemoteVideoView(for: uid)

            // Apply stream type based on network
            let streamType: AgoraVideoStreamType = NetworkManager.shared.networkQuality.rawValue <= NetworkQuality.good.rawValue ? .high : .low
            self.engine?.setRemoteVideoStream(uid, type: streamType)

            if self.remoteCameraMuted {
                self.applyRemoteCameraMuted(true)
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        #if DEBUG
        print("👤 Remote user offline: \(uid), reason: \(reason.rawValue)")
        #endif

        if reason == .dropped {
            MatchingManager.shared.signalCallEnd()
        }

        // Clear remote canvas
        clearVideoCanvas(uid: uid, isLocal: false)

        DispatchQueue.main.async {
            self.remoteUserJoined = false
            self.remoteVideoEnabled = false
            self.remoteVideoView = nil
            self.remoteUserId = 0
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        #if DEBUG
        print("👋 Left channel - duration: \(stats.duration)s")
        #endif
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        #if DEBUG
        print("🔌 Connection: \(state), reason: \(reason)")
        #endif

        switch state {
        case .disconnected:
            updateConnectionState(.disconnected)
        case .connecting:
            updateConnectionState(.connecting)
        case .connected:
            updateConnectionState(.connected)
        case .reconnecting:
            updateConnectionState(.reconnecting)
        case .failed:
            updateConnectionState(.failed(.networkError))
            if TokenProvider.shared.isEnabled() && !channelName.isEmpty {
                handleTokenRefresh()
            }
        @unknown default:
            break
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        #if DEBUG
        print("🔐 Token expiring soon")
        #endif
        handleTokenRefresh()
    }

    func rtcEngineRequestToken(_ engine: AgoraRtcEngineKit) {
        #if DEBUG
        print("🔐 Token requested")
        #endif
        handleTokenRefresh()
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        // Update NetworkManager with Agora quality
        let worstQuality = max(txQuality.rawValue, rxQuality.rawValue)
        NetworkManager.shared.updateFromAgoraQuality(Int(worstQuality))
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        NetworkManager.shared.updateStatistics(
            txLoss: Double(stats.txPacketLossRate),
            rxLoss: Double(stats.rxPacketLossRate),
            rtt: Int(stats.lastmileDelay),
            txBitrate: Int(stats.txVideoKBitrate),
            rxBitrate: Int(stats.rxVideoKBitrate)
        )
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStateChangedOfUid uid: UInt, state: AgoraVideoRemoteState, reason: AgoraVideoRemoteReason, elapsed: Int) {
        #if DEBUG
        print("📹 Remote video state: \(state.rawValue), reason: \(reason.rawValue)")
        #endif

        DispatchQueue.main.async {
            switch state {
            case .stopped, .failed:
                self.remoteVideoEnabled = false
            case .starting, .decoding:
                self.remoteVideoEnabled = true
            case .frozen:
                // Keep current state, will recover automatically
                break
            @unknown default:
                break
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid uid: UInt) {
        #if DEBUG
        print("📹 Remote video muted: \(muted)")
        #endif
        DispatchQueue.main.async {
            self.remoteVideoEnabled = !muted
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        #if DEBUG
        print("🎥 First remote frame: \(uid), size: \(size)")
        #endif

        DispatchQueue.main.async {
            self.remoteVideoEnabled = true
            if self.remoteVideoView == nil {
                self.setupRemoteVideoView(for: uid)
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        #if DEBUG
        print("❌ Agora error: \(errorCode.rawValue)")
        #endif
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        #if DEBUG
        print("⚠️ Agora warning: \(warningCode.rawValue)")
        #endif
    }
}
