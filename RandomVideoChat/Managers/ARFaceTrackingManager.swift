import ARKit
import Vision
import Combine
import simd

// MARK: - ARFaceTrackingManager
/// ARKit 기반 실시간 얼굴 추적 매니저
/// - Face Tracking Configuration 관리
/// - 얼굴 랜드마크 및 blendshape 데이터 제공
/// - Vision 프레임워크 폴백 지원 (ARKit 미지원 기기)
final class ARFaceTrackingManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = ARFaceTrackingManager()
    
    // MARK: - Published Properties
    @Published private(set) var isTracking = false
    @Published private(set) var faceDetected = false
    @Published private(set) var trackingQuality: TrackingQuality = .notAvailable
    
    /// 현재 얼굴 데이터
    @Published private(set) var currentFaceData: FaceTrackingData?
    
    // MARK: - Public Properties
    var isARKitSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }
    
    // MARK: - Private Properties
    private var arSession: ARSession?
    private var visionRequests: [VNRequest] = []
    private var sequenceHandler = VNSequenceRequestHandler()
    
    // 성능 최적화
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 1.0 / 30.0  // 30fps
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Tracking Quality
    enum TrackingQuality {
        case notAvailable
        case limited
        case normal
        case high
        
        var description: String {
            switch self {
            case .notAvailable: return "추적 불가"
            case .limited: return "제한적"
            case .normal: return "보통"
            case .high: return "높음"
            }
        }
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupTracking()
        
        #if DEBUG
        print("🎭 ARFaceTrackingManager initialized - ARKit supported: \(isARKitSupported)")
        #endif
    }
    
    deinit {
        stopTracking()
        #if DEBUG
        print("🎭 ARFaceTrackingManager deinitialized")
        #endif
    }
    
    // MARK: - Setup
    private func setupTracking() {
        if isARKitSupported {
            setupARKit()
        } else {
            setupVisionFallback()
        }
    }
    
    private func setupARKit() {
        arSession = ARSession()
        arSession?.delegate = self
    }
    
    private func setupVisionFallback() {
        // Vision 프레임워크로 기본 얼굴 감지
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleVisionFaceDetection(request: request, error: error)
        }
        faceDetectionRequest.revision = VNDetectFaceLandmarksRequestRevision3
        visionRequests = [faceDetectionRequest]
        
        #if DEBUG
        print("⚠️ ARKit not supported - using Vision fallback")
        #endif
    }
    
    // MARK: - Public API
    
    /// 얼굴 추적 시작
    func startTracking() {
        guard !isTracking else { return }
        
        if isARKitSupported {
            startARKitTracking()
        }
        
        isTracking = true
        
        #if DEBUG
        print("🎭 Face tracking started")
        #endif
    }
    
    /// 얼굴 추적 중지
    func stopTracking() {
        guard isTracking else { return }
        
        arSession?.pause()
        isTracking = false
        faceDetected = false
        currentFaceData = nil
        trackingQuality = .notAvailable
        
        #if DEBUG
        print("🎭 Face tracking stopped")
        #endif
    }
    
    /// Vision으로 단일 프레임 처리 (ARKit 미지원 시)
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isARKitSupported else { return }
        
        // 프레임 레이트 제한
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessedTime >= processingInterval else { return }
        lastProcessedTime = currentTime
        
        do {
            try sequenceHandler.perform(visionRequests, on: pixelBuffer)
        } catch {
            #if DEBUG
            print("❌ Vision processing error: \(error)")
            #endif
        }
    }
    
    // MARK: - Private: ARKit
    
    private func startARKitTracking() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 1
        
        // iOS 13+ 옵션
        if #available(iOS 13.0, *) {
            configuration.isWorldTrackingEnabled = false
        }
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Private: Vision Fallback
    
    private func handleVisionFaceDetection(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNFaceObservation],
              let face = results.first else {
            DispatchQueue.main.async {
                self.faceDetected = false
                self.currentFaceData = nil
            }
            return
        }
        
        // Vision 결과를 FaceTrackingData로 변환
        let faceData = convertVisionToFaceData(face)
        
        DispatchQueue.main.async {
            self.faceDetected = true
            self.currentFaceData = faceData
            self.trackingQuality = .limited  // Vision은 제한적
        }
    }
    
    private func convertVisionToFaceData(_ observation: VNFaceObservation) -> FaceTrackingData {
        var landmarks2D: [String: CGPoint] = [:]
        
        if let landmarks = observation.landmarks {
            // 주요 랜드마크 추출
            if let leftEye = landmarks.leftEye?.normalizedPoints.first {
                landmarks2D["leftEye"] = leftEye
            }
            if let rightEye = landmarks.rightEye?.normalizedPoints.first {
                landmarks2D["rightEye"] = rightEye
            }
            if let nose = landmarks.nose?.normalizedPoints.first {
                landmarks2D["nose"] = nose
            }
            if let outerLips = landmarks.outerLips?.normalizedPoints.first {
                landmarks2D["mouth"] = outerLips
            }
        }
        
        return FaceTrackingData(
            boundingBox: observation.boundingBox,
            landmarks2D: landmarks2D,
            landmarks3D: [:],
            blendShapes: [:],
            faceTransform: matrix_identity_float4x4,
            leftEyeTransform: nil,
            rightEyeTransform: nil,
            lookAtPoint: nil
        )
    }
}

// MARK: - ARSessionDelegate
extension ARFaceTrackingManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first as? ARFaceAnchor else { return }
        
        let faceData = convertARKitToFaceData(faceAnchor)
        
        DispatchQueue.main.async {
            self.faceDetected = faceAnchor.isTracked
            self.currentFaceData = faceData
            self.updateTrackingQuality(faceAnchor)
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        if anchors.contains(where: { $0 is ARFaceAnchor }) {
            DispatchQueue.main.async {
                self.faceDetected = false
                self.currentFaceData = nil
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        #if DEBUG
        print("❌ ARSession error: \(error)")
        #endif
        
        DispatchQueue.main.async {
            self.trackingQuality = .notAvailable
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        #if DEBUG
        print("⚠️ ARSession interrupted")
        #endif
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        #if DEBUG
        print("✅ ARSession interruption ended")
        #endif
        startARKitTracking()
    }
    
    // MARK: - Private: ARKit Data Conversion
    
    private func convertARKitToFaceData(_ faceAnchor: ARFaceAnchor) -> FaceTrackingData {
        // BlendShape 변환
        var blendShapes: [String: Float] = [:]
        for (key, value) in faceAnchor.blendShapes {
            blendShapes[key.rawValue] = value.floatValue
        }
        
        // 3D 랜드마크 (ARKit geometry vertices)
        var landmarks3D: [Int: SIMD3<Float>] = [:]
        let vertices = faceAnchor.geometry.vertices
        for (index, vertex) in vertices.enumerated() {
            landmarks3D[index] = vertex
        }
        
        // 시선 방향 계산
        let lookAtPoint = calculateLookAtPoint(faceAnchor)
        
        return FaceTrackingData(
            boundingBox: .zero,  // ARKit은 bounding box를 직접 제공하지 않음
            landmarks2D: [:],
            landmarks3D: landmarks3D,
            blendShapes: blendShapes,
            faceTransform: faceAnchor.transform,
            leftEyeTransform: faceAnchor.leftEyeTransform,
            rightEyeTransform: faceAnchor.rightEyeTransform,
            lookAtPoint: lookAtPoint
        )
    }
    
    private func calculateLookAtPoint(_ faceAnchor: ARFaceAnchor) -> SIMD3<Float>? {
        // 시선 방향 계산 (양 눈의 평균)
        let leftEyeDir = faceAnchor.leftEyeTransform.columns.2
        let rightEyeDir = faceAnchor.rightEyeTransform.columns.2
        
        let avgDirection = SIMD3<Float>(
            (leftEyeDir.x + rightEyeDir.x) / 2,
            (leftEyeDir.y + rightEyeDir.y) / 2,
            (leftEyeDir.z + rightEyeDir.z) / 2
        )
        
        return avgDirection
    }
    
    private func updateTrackingQuality(_ faceAnchor: ARFaceAnchor) {
        guard faceAnchor.isTracked else {
            trackingQuality = .notAvailable
            return
        }
        
        // BlendShape 값으로 품질 추정
        let blendShapes = faceAnchor.blendShapes
        let eyeBlinkLeft = blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let eyeBlinkRight = blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        let jawOpen = blendShapes[.jawOpen]?.floatValue ?? 0
        
        // 얼굴 움직임이 감지되면 품질이 좋은 것으로 판단
        let hasMovement = eyeBlinkLeft > 0.1 || eyeBlinkRight > 0.1 || jawOpen > 0.1
        
        if hasMovement {
            trackingQuality = .high
        } else {
            trackingQuality = .normal
        }
    }
}

// MARK: - Face Tracking Data
/// 얼굴 추적 결과 데이터
struct FaceTrackingData {
    /// 얼굴 영역 (정규화된 좌표, Vision용)
    let boundingBox: CGRect
    
    /// 2D 랜드마크 (정규화된 좌표, Vision용)
    let landmarks2D: [String: CGPoint]
    
    /// 3D 랜드마크 (ARKit geometry vertices)
    let landmarks3D: [Int: SIMD3<Float>]
    
    /// ARKit BlendShape 값들 (52개)
    let blendShapes: [String: Float]
    
    /// 얼굴 변환 행렬
    let faceTransform: simd_float4x4
    
    /// 왼쪽 눈 변환 행렬
    let leftEyeTransform: simd_float4x4?
    
    /// 오른쪽 눈 변환 행렬
    let rightEyeTransform: simd_float4x4?
    
    /// 시선 방향
    let lookAtPoint: SIMD3<Float>?
    
    // MARK: - Computed Properties
    
    /// 눈 깜빡임 값 (0.0 ~ 1.0)
    var eyeBlinkLeft: Float {
        blendShapes["eyeBlink_L"] ?? blendShapes["eyeBlinkLeft"] ?? 0
    }
    
    var eyeBlinkRight: Float {
        blendShapes["eyeBlink_R"] ?? blendShapes["eyeBlinkRight"] ?? 0
    }
    
    /// 입 열림 값 (0.0 ~ 1.0)
    var mouthOpen: Float {
        blendShapes["jawOpen"] ?? 0
    }
    
    /// 미소 값 (0.0 ~ 1.0)
    var smileLeft: Float {
        blendShapes["mouthSmile_L"] ?? blendShapes["mouthSmileLeft"] ?? 0
    }
    
    var smileRight: Float {
        blendShapes["mouthSmile_R"] ?? blendShapes["mouthSmileRight"] ?? 0
    }
    
    /// 눈썹 올림 (0.0 ~ 1.0)
    var browInnerUp: Float {
        blendShapes["browInnerUp"] ?? 0
    }
    
    /// 얼굴 회전 (Euler angles)
    var faceRotation: SIMD3<Float> {
        // 변환 행렬에서 회전 추출
        let pitch = asin(-faceTransform.columns.2.y)
        let yaw = atan2(faceTransform.columns.2.x, faceTransform.columns.2.z)
        let roll = atan2(faceTransform.columns.0.y, faceTransform.columns.1.y)
        return SIMD3<Float>(pitch, yaw, roll)
    }
    
    /// 얼굴 위치 (3D)
    var facePosition: SIMD3<Float> {
        SIMD3<Float>(
            faceTransform.columns.3.x,
            faceTransform.columns.3.y,
            faceTransform.columns.3.z
        )
    }
}

// MARK: - BlendShape Keys (Apple ARKit)
/// ARKit BlendShape 키 목록
extension ARFaceAnchor.BlendShapeLocation {
    static let allCases: [ARFaceAnchor.BlendShapeLocation] = [
        .browDownLeft, .browDownRight, .browInnerUp, .browOuterUpLeft, .browOuterUpRight,
        .cheekPuff, .cheekSquintLeft, .cheekSquintRight,
        .eyeBlinkLeft, .eyeBlinkRight, .eyeLookDownLeft, .eyeLookDownRight,
        .eyeLookInLeft, .eyeLookInRight, .eyeLookOutLeft, .eyeLookOutRight,
        .eyeLookUpLeft, .eyeLookUpRight, .eyeSquintLeft, .eyeSquintRight,
        .eyeWideLeft, .eyeWideRight,
        .jawForward, .jawLeft, .jawOpen, .jawRight,
        .mouthClose, .mouthDimpleLeft, .mouthDimpleRight, .mouthFrownLeft, .mouthFrownRight,
        .mouthFunnel, .mouthLeft, .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthPressLeft, .mouthPressRight, .mouthPucker, .mouthRight,
        .mouthRollLower, .mouthRollUpper, .mouthShrugLower, .mouthShrugUpper,
        .mouthSmileLeft, .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight,
        .mouthUpperUpLeft, .mouthUpperUpRight, .noseSneerLeft, .noseSneerRight,
        .tongueOut
    ]
}
