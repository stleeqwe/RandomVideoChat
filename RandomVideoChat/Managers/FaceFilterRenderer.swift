import UIKit
import CoreImage
import Metal
import MetalKit
import ARKit
import Accelerate

// MARK: - FaceFilterRenderer
/// 얼굴 필터 렌더링 엔진
/// - Core Image 기반 뷰티 필터
/// - Metal 기반 오버레이 렌더링
/// - 실시간 프레임 처리
final class FaceFilterRenderer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FaceFilterRenderer()
    
    // MARK: - Published Properties
    @Published var currentFilter: FaceFilterType = .none {
        didSet {
            if oldValue != currentFilter {
                loadFilterAssets()
            }
        }
    }
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var ciContext: CIContext?
    private var textureCache: CVMetalTextureCache?
    
    // 필터 에셋 캐시
    private var filterImages: [FaceFilterType: CIImage] = [:]
    private var filterTextures: [FaceFilterType: MTLTexture] = [:]
    
    // 성능 측정
    private var lastFrameTime: CFAbsoluteTime = 0
    private var frameCount: Int = 0
    private var averageFPS: Double = 0
    
    // 처리 큐
    private let processingQueue = DispatchQueue(label: "com.5sec.facefilter.processing", qos: .userInteractive)
    
    // MARK: - Initialization
    private init() {
        setupMetal()
        setupCoreImage()
        
        #if DEBUG
        print("🎨 FaceFilterRenderer initialized")
        #endif
    }
    
    // MARK: - Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            #if DEBUG
            print("❌ Metal not supported")
            #endif
            return
        }
        
        metalDevice = device
        commandQueue = device.makeCommandQueue()
        
        // Texture cache 생성
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        textureCache = cache
    }
    
    private func setupCoreImage() {
        if let device = metalDevice {
            ciContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .highQualityDownsample: true,
                .useSoftwareRenderer: false
            ])
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }
    
    private func loadFilterAssets() {
        guard currentFilter != .none else { return }
        
        // 이미지 에셋 로드
        if let asset = FilterAsset.asset(for: currentFilter),
           let imageName = asset.imageName,
           let uiImage = UIImage(named: imageName) {
            filterImages[currentFilter] = CIImage(image: uiImage)
        }
        
        #if DEBUG
        print("🎨 Loaded assets for filter: \(currentFilter.displayName)")
        #endif
    }
    
    // MARK: - Public API
    
    /// 프레임에 필터 적용
    /// - Parameters:
    ///   - pixelBuffer: 입력 프레임
    ///   - faceData: 얼굴 추적 데이터
    /// - Returns: 처리된 프레임 (또는 원본)
    func processFrame(_ pixelBuffer: CVPixelBuffer, faceData: FaceTrackingData?) -> CVPixelBuffer {
        guard currentFilter != .none else {
            return pixelBuffer
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 성능 측정
        updateFPS()
        
        switch currentFilter.category {
        case .none:
            return pixelBuffer
            
        case .beauty:
            return applyBeautyFilter(pixelBuffer, intensity: currentFilter.beautyIntensity)
            
        case .arOverlay:
            guard let faceData = faceData else { return pixelBuffer }
            return applyOverlayFilter(pixelBuffer, faceData: faceData)
            
        case .avatar:
            guard let faceData = faceData else { return pixelBuffer }
            return applyAvatarFilter(pixelBuffer, faceData: faceData)
        }
    }
    
    /// 동기적으로 프레임 처리 (Agora delegate용)
    func processFrameSync(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        let faceData = ARFaceTrackingManager.shared.currentFaceData
        return processFrame(pixelBuffer, faceData: faceData)
    }
    
    // MARK: - Beauty Filter
    
    private func applyBeautyFilter(_ pixelBuffer: CVPixelBuffer, intensity: Float) -> CVPixelBuffer {
        guard let ciContext = ciContext else { return pixelBuffer }
        
        var inputImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 1. 피부 스무딩 (Gaussian Blur + 원본 블렌딩)
        if let smoothed = applySkinSmoothing(inputImage, intensity: intensity) {
            inputImage = smoothed
        }
        
        // 2. 밝기/대비 조정
        if let adjusted = applyColorAdjustment(inputImage, intensity: intensity) {
            inputImage = adjusted
        }
        
        // 3. 약간의 샤프닝 (디테일 유지)
        if let sharpened = applySharpening(inputImage, intensity: intensity * 0.5) {
            inputImage = sharpened
        }
        
        // 결과를 pixelBuffer에 렌더링
        ciContext.render(inputImage, to: pixelBuffer)
        
        return pixelBuffer
    }
    
    private func applySkinSmoothing(_ image: CIImage, intensity: Float) -> CIImage? {
        // 가우시안 블러
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(Double(intensity) * 4.0, forKey: kCIInputRadiusKey)  // 0 ~ 3.2
        
        guard let blurred = blurFilter.outputImage else { return nil }
        
        // 원본과 블렌딩 (피부만 부드럽게)
        guard let blendFilter = CIFilter(name: "CISourceOverCompositing") else { return blurred }
        
        // 마스크 없이 단순 블렌딩 (추후 피부 감지 마스크 추가 가능)
        guard let mixFilter = CIFilter(name: "CIMix") else { return blurred }
        mixFilter.setValue(image, forKey: kCIInputImageKey)
        mixFilter.setValue(blurred, forKey: kCIInputBackgroundImageKey)
        mixFilter.setValue(Double(intensity) * 0.5, forKey: kCIInputAmountKey)  // 블렌딩 비율
        
        return mixFilter.outputImage ?? blurred
    }
    
    private func applyColorAdjustment(_ image: CIImage, intensity: Float) -> CIImage? {
        guard let colorFilter = CIFilter(name: "CIColorControls") else { return nil }
        colorFilter.setValue(image, forKey: kCIInputImageKey)
        colorFilter.setValue(1.0 + Double(intensity) * 0.1, forKey: kCIInputContrastKey)     // 약간의 대비 증가
        colorFilter.setValue(Double(intensity) * 0.05, forKey: kCIInputBrightnessKey)       // 약간 밝게
        colorFilter.setValue(1.0 + Double(intensity) * 0.1, forKey: kCIInputSaturationKey)  // 약간의 채도 증가
        
        return colorFilter.outputImage
    }
    
    private func applySharpening(_ image: CIImage, intensity: Float) -> CIImage? {
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return nil }
        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(Double(intensity) * 0.5, forKey: kCIInputSharpnessKey)
        
        return sharpenFilter.outputImage
    }
    
    // MARK: - Overlay Filter (AR 필터)
    
    private func applyOverlayFilter(_ pixelBuffer: CVPixelBuffer, faceData: FaceTrackingData) -> CVPixelBuffer {
        guard let ciContext = ciContext,
              let filterImage = filterImages[currentFilter],
              let asset = FilterAsset.asset(for: currentFilter) else {
            return pixelBuffer
        }
        
        var baseImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageSize = baseImage.extent.size
        
        // 얼굴 위치 및 크기 계산
        let facePosition = faceData.facePosition
        let faceRotation = faceData.faceRotation
        
        // 3D 좌표를 2D 화면 좌표로 변환 (간단한 투영)
        let screenX = (CGFloat(facePosition.x) + 0.5) * imageSize.width
        let screenY = (CGFloat(-facePosition.y) + 0.5) * imageSize.height
        
        // 얼굴 크기 추정 (z 좌표 기반)
        let faceScale = 1.0 / max(0.3, abs(facePosition.z) + 0.5)
        let filterScale = asset.scale * CGFloat(faceScale) * 0.3  // 기본 스케일 조정
        
        // 필터 이미지 변환
        var transform = CGAffineTransform.identity
        
        // 스케일링
        let scaledWidth = filterImage.extent.width * filterScale
        let scaledHeight = filterImage.extent.height * filterScale
        transform = transform.scaledBy(x: filterScale, y: filterScale)
        
        // 회전 (얼굴 회전에 맞춤)
        transform = transform.rotated(by: CGFloat(faceRotation.z))
        
        // 위치 이동
        let offsetX = screenX - scaledWidth / 2 + asset.offset.x * imageSize.width
        let offsetY = screenY - scaledHeight / 2 + asset.offset.y * imageSize.height
        transform = transform.translatedBy(x: offsetX / filterScale, y: offsetY / filterScale)
        
        // 변환된 필터 이미지
        let transformedFilter = filterImage.transformed(by: transform)
        
        // 오버레이 합성
        guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else {
            return pixelBuffer
        }
        compositeFilter.setValue(transformedFilter, forKey: kCIInputImageKey)
        compositeFilter.setValue(baseImage, forKey: kCIInputBackgroundImageKey)
        
        guard let result = compositeFilter.outputImage else {
            return pixelBuffer
        }
        
        ciContext.render(result, to: pixelBuffer)
        
        return pixelBuffer
    }
    
    // MARK: - Avatar Filter
    
    private func applyAvatarFilter(_ pixelBuffer: CVPixelBuffer, faceData: FaceTrackingData) -> CVPixelBuffer {
        guard let ciContext = ciContext else { return pixelBuffer }
        
        // 아바타 렌더링 (추후 SceneKit/RealityKit 통합)
        // 현재는 간단한 마스크 + 이모지 스타일로 구현
        
        var baseImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageSize = baseImage.extent.size
        
        // 얼굴 영역 마스킹
        let facePosition = faceData.facePosition
        let screenX = (CGFloat(facePosition.x) + 0.5) * imageSize.width
        let screenY = (CGFloat(-facePosition.y) + 0.5) * imageSize.height
        let faceScale = 1.0 / max(0.3, abs(facePosition.z) + 0.5)
        let faceRadius = CGFloat(faceScale) * imageSize.width * 0.15
        
        // 얼굴 영역 블러 (마스킹 효과)
        guard let maskGenerator = CIFilter(name: "CIRadialGradient") else {
            return pixelBuffer
        }
        maskGenerator.setValue(CIVector(x: screenX, y: screenY), forKey: "inputCenter")
        maskGenerator.setValue(faceRadius * 0.8, forKey: "inputRadius0")
        maskGenerator.setValue(faceRadius * 1.2, forKey: "inputRadius1")
        maskGenerator.setValue(CIColor.white, forKey: "inputColor0")
        maskGenerator.setValue(CIColor.clear, forKey: "inputColor1")
        
        // 아바타 색상 (표정에 따라 변화)
        let smile = (faceData.smileLeft + faceData.smileRight) / 2
        let avatarHue = 0.6 + Double(smile) * 0.1  // 웃으면 약간 더 밝은 색
        
        // 단색 아바타 (추후 3D 모델로 교체)
        guard let colorFilter = CIFilter(name: "CIConstantColorGenerator") else {
            return pixelBuffer
        }
        
        let avatarColor: CIColor
        switch currentFilter {
        case .avatarAnime:
            avatarColor = CIColor(red: 1.0, green: 0.85, blue: 0.75, alpha: 1.0)  // 피부색
        case .avatarRobot:
            avatarColor = CIColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1.0)   // 메탈릭
        case .avatarCat:
            avatarColor = CIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0)   // 밝은 오렌지
        default:
            avatarColor = CIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        }
        colorFilter.setValue(avatarColor, forKey: kCIInputColorKey)
        
        guard let avatarBase = colorFilter.outputImage?.cropped(to: baseImage.extent),
              let mask = maskGenerator.outputImage else {
            return pixelBuffer
        }
        
        // 마스크로 아바타와 배경 합성
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return pixelBuffer
        }
        blendFilter.setValue(avatarBase, forKey: kCIInputImageKey)
        blendFilter.setValue(baseImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        
        guard let result = blendFilter.outputImage else {
            return pixelBuffer
        }
        
        // 표정 오버레이 추가 (눈, 입 등)
        let finalResult = addExpressionOverlay(result, faceData: faceData, center: CGPoint(x: screenX, y: screenY), radius: faceRadius)
        
        ciContext.render(finalResult, to: pixelBuffer)
        
        return pixelBuffer
    }
    
    private func addExpressionOverlay(_ image: CIImage, faceData: FaceTrackingData, center: CGPoint, radius: CGFloat) -> CIImage {
        // 눈 그리기 (깜빡임 반영)
        let leftEyeOpen = 1.0 - faceData.eyeBlinkLeft
        let rightEyeOpen = 1.0 - faceData.eyeBlinkRight
        
        // 입 그리기 (열림 정도 반영)
        let mouthOpen = faceData.mouthOpen
        
        // 현재는 단순 구현 - 추후 SceneKit 렌더링으로 교체
        // 눈과 입 위치에 원 그리기
        var result = image
        
        // 왼쪽 눈
        let leftEyeCenter = CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.15)
        if let eye = createEyeImage(at: leftEyeCenter, radius: radius * 0.08, openness: CGFloat(leftEyeOpen)) {
            result = eye.composited(over: result)
        }
        
        // 오른쪽 눈
        let rightEyeCenter = CGPoint(x: center.x + radius * 0.25, y: center.y + radius * 0.15)
        if let eye = createEyeImage(at: rightEyeCenter, radius: radius * 0.08, openness: CGFloat(rightEyeOpen)) {
            result = eye.composited(over: result)
        }
        
        // 입
        let mouthCenter = CGPoint(x: center.x, y: center.y - radius * 0.25)
        if let mouth = createMouthImage(at: mouthCenter, width: radius * 0.3, openness: CGFloat(mouthOpen)) {
            result = mouth.composited(over: result)
        }
        
        return result
    }
    
    private func createEyeImage(at center: CGPoint, radius: CGFloat, openness: CGFloat) -> CIImage? {
        guard let generator = CIFilter(name: "CIRadialGradient") else { return nil }
        
        let eyeRadius = radius * max(0.3, openness)  // 눈 감으면 작아짐
        
        generator.setValue(CIVector(cgPoint: center), forKey: "inputCenter")
        generator.setValue(eyeRadius * 0.3, forKey: "inputRadius0")
        generator.setValue(eyeRadius, forKey: "inputRadius1")
        generator.setValue(CIColor.black, forKey: "inputColor0")
        generator.setValue(CIColor.clear, forKey: "inputColor1")
        
        return generator.outputImage
    }
    
    private func createMouthImage(at center: CGPoint, width: CGFloat, openness: CGFloat) -> CIImage? {
        guard let generator = CIFilter(name: "CIRadialGradient") else { return nil }
        
        let mouthHeight = width * 0.3 * max(0.2, openness)  // 입 열림에 따라 높이 변화
        
        generator.setValue(CIVector(cgPoint: center), forKey: "inputCenter")
        generator.setValue(mouthHeight * 0.5, forKey: "inputRadius0")
        generator.setValue(width * 0.5, forKey: "inputRadius1")
        generator.setValue(CIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0), forKey: "inputColor0")
        generator.setValue(CIColor.clear, forKey: "inputColor1")
        
        return generator.outputImage
    }
    
    // MARK: - Performance
    
    private func updateFPS() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        frameCount += 1
        
        if currentTime - lastFrameTime >= 1.0 {
            averageFPS = Double(frameCount) / (currentTime - lastFrameTime)
            frameCount = 0
            lastFrameTime = currentTime
            
            #if DEBUG
            // 1초마다 FPS 로깅 (디버그 모드)
            if averageFPS < 20 {
                print("⚠️ Low FPS: \(String(format: "%.1f", averageFPS))")
            }
            #endif
        }
    }
    
    /// 현재 평균 FPS 반환
    var currentFPS: Double {
        averageFPS
    }
}

// MARK: - CIVector Extension
extension CIVector {
    convenience init(cgPoint: CGPoint) {
        self.init(x: cgPoint.x, y: cgPoint.y)
    }
}
