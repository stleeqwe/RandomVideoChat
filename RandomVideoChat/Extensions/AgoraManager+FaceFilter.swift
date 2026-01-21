import AgoraRtcKit
import CoreVideo

// MARK: - AgoraManager + Face Filter Extension
/// Agora Video Frame Observer를 통한 실시간 필터 처리
extension AgoraManager {
    
    // MARK: - Filter Setup
    
    /// 필터 시스템 초기화 (통화 시작 시 호출)
    func setupFaceFilter() {
        guard let engine = agoraKit else {
            #if DEBUG
            print("❌ Cannot setup face filter: Agora engine not initialized")
            #endif
            return
        }
        
        // Video Frame Observer 등록
        engine.setVideoFrameDelegate(self)
        
        // ARKit 얼굴 추적 시작
        if FaceFilterRenderer.shared.currentFilter.requiresARKit {
            ARFaceTrackingManager.shared.startTracking()
        }
        
        #if DEBUG
        print("🎭 Face filter system initialized")
        #endif
    }
    
    /// 필터 시스템 정리 (통화 종료 시 호출)
    func cleanupFaceFilter() {
        agoraKit?.setVideoFrameDelegate(nil)
        ARFaceTrackingManager.shared.stopTracking()
        FaceFilterRenderer.shared.currentFilter = .none
        
        #if DEBUG
        print("🎭 Face filter system cleaned up")
        #endif
    }
    
    /// 현재 필터 변경
    func setFaceFilter(_ filter: FaceFilterType) {
        FaceFilterRenderer.shared.currentFilter = filter
        
        // ARKit 필요 여부에 따라 추적 시작/중지
        if filter.requiresARKit {
            ARFaceTrackingManager.shared.startTracking()
        } else if !FaceFilterRenderer.shared.currentFilter.requiresARKit {
            // 현재 필터도 ARKit 불필요하면 추적 중지
            ARFaceTrackingManager.shared.stopTracking()
        }
        
        #if DEBUG
        print("🎭 Filter changed to: \(filter.displayName)")
        #endif
    }
    
    /// 현재 필터 타입 반환
    var currentFaceFilter: FaceFilterType {
        FaceFilterRenderer.shared.currentFilter
    }
}

// MARK: - AgoraVideoFrameDelegate
extension AgoraManager: AgoraVideoFrameDelegate {
    
    /// 프레임 처리 모드 설정
    public func getVideoFrameProcessMode() -> AgoraVideoFrameProcessMode {
        // readWrite: 프레임 수정 가능
        return .readWrite
    }
    
    /// 미러링 설정
    public func getMirrorApplied() -> Bool {
        return true  // 로컬 비디오 미러링
    }
    
    /// 관찰할 비디오 포지션 (카메라만)
    public func getObservedFramePosition() -> AgoraVideoFramePosition {
        return .postCapture  // 캡처 후 인코딩 전
    }
    
    /// 로컬 비디오 프레임 처리 (카메라 캡처 후)
    public func onCapture(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        // 필터가 없으면 패스
        guard FaceFilterRenderer.shared.currentFilter != .none else {
            return true
        }
        
        // 카메라 소스만 처리
        guard sourceType == .camera else {
            return true
        }
        
        // PixelBuffer 가져오기
        guard let pixelBuffer = videoFrame.pixelBuffer else {
            return true
        }
        
        // Vision 기반 처리 (ARKit 미지원 기기)
        if !ARFaceTrackingManager.shared.isARKitSupported {
            ARFaceTrackingManager.shared.processFrame(pixelBuffer)
        }
        
        // 필터 적용
        let processedBuffer = FaceFilterRenderer.shared.processFrameSync(pixelBuffer)
        
        // 처리된 버퍼로 교체 (같은 버퍼면 이미 수정됨)
        if processedBuffer !== pixelBuffer {
            videoFrame.pixelBuffer = processedBuffer
        }
        
        return true
    }
    
    /// 원격 비디오 프레임 처리 (수신된 프레임)
    public func onRenderVideoFrame(_ videoFrame: AgoraOutputVideoFrame, uid: UInt, channelId: String) -> Bool {
        // 원격 비디오는 필터 적용하지 않음 (원본 유지)
        return true
    }
    
    /// 로컬 비디오 프레임 프리렌더 (표시 전)
    public func onPreEncode(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        // 인코딩 전 추가 처리 필요 시 여기서 수행
        return true
    }
}

// MARK: - AgoraManager Call Lifecycle Hooks
extension AgoraManager {
    
    /// 통화 시작 시 필터 시스템 활성화
    func onCallStarted() {
        setupFaceFilter()
    }
    
    /// 통화 종료 시 필터 시스템 비활성화
    func onCallEnded() {
        cleanupFaceFilter()
    }
}
