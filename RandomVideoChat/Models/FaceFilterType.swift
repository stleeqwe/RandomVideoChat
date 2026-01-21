import Foundation
import UIKit

// MARK: - Face Filter Type
/// 얼굴 필터 종류 정의
enum FaceFilterType: String, CaseIterable, Identifiable {
    case none = "none"
    
    // AR 필터 (얼굴에 오버레이)
    case glasses = "glasses"
    case sunglasses = "sunglasses"
    case catEars = "cat_ears"
    case dogNose = "dog_nose"
    case crown = "crown"
    case mask = "mask"
    
    // 뷰티 필터
    case beautyLight = "beauty_light"
    case beautyMedium = "beauty_medium"
    case beautyStrong = "beauty_strong"
    
    // 아바타 (얼굴 전체 교체)
    case avatarAnime = "avatar_anime"
    case avatarRobot = "avatar_robot"
    case avatarCat = "avatar_cat"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "없음"
        case .glasses: return "안경"
        case .sunglasses: return "선글라스"
        case .catEars: return "고양이 귀"
        case .dogNose: return "강아지 코"
        case .crown: return "왕관"
        case .mask: return "마스크"
        case .beautyLight: return "뷰티 (약)"
        case .beautyMedium: return "뷰티 (중)"
        case .beautyStrong: return "뷰티 (강)"
        case .avatarAnime: return "애니메 아바타"
        case .avatarRobot: return "로봇 아바타"
        case .avatarCat: return "고양이 아바타"
        }
    }
    
    var iconName: String {
        switch self {
        case .none: return "circle.slash"
        case .glasses: return "eyeglasses"
        case .sunglasses: return "sun.max.fill"
        case .catEars: return "cat.fill"
        case .dogNose: return "dog.fill"
        case .crown: return "crown.fill"
        case .mask: return "theatermasks.fill"
        case .beautyLight: return "sparkles"
        case .beautyMedium: return "wand.and.stars"
        case .beautyStrong: return "star.fill"
        case .avatarAnime: return "person.crop.circle.fill"
        case .avatarRobot: return "cpu.fill"
        case .avatarCat: return "cat.circle.fill"
        }
    }
    
    var category: FilterCategory {
        switch self {
        case .none:
            return .none
        case .glasses, .sunglasses, .catEars, .dogNose, .crown, .mask:
            return .arOverlay
        case .beautyLight, .beautyMedium, .beautyStrong:
            return .beauty
        case .avatarAnime, .avatarRobot, .avatarCat:
            return .avatar
        }
    }
    
    /// 뷰티 필터 강도 (0.0 ~ 1.0)
    var beautyIntensity: Float {
        switch self {
        case .beautyLight: return 0.3
        case .beautyMedium: return 0.5
        case .beautyStrong: return 0.8
        default: return 0.0
        }
    }
    
    /// ARKit 지원 필요 여부
    var requiresARKit: Bool {
        switch self {
        case .none, .beautyLight, .beautyMedium, .beautyStrong:
            return false
        default:
            return true
        }
    }
}

// MARK: - Filter Category
enum FilterCategory: String, CaseIterable {
    case none = "없음"
    case arOverlay = "AR 필터"
    case beauty = "뷰티"
    case avatar = "아바타"
    
    var filters: [FaceFilterType] {
        FaceFilterType.allCases.filter { $0.category == self }
    }
}

// MARK: - Face Landmark Points
/// ARKit 얼굴 랜드마크 포인트 인덱스
struct FaceLandmarkIndices {
    // 눈
    static let leftEyeCenter = 1064
    static let rightEyeCenter = 1096
    static let leftEyeInner = 1057
    static let leftEyeOuter = 1070
    static let rightEyeInner = 1089
    static let rightEyeOuter = 1102
    
    // 코
    static let noseTip = 9
    static let noseBottom = 2
    
    // 입
    static let mouthCenter = 24
    static let mouthLeft = 49
    static let mouthRight = 303
    static let upperLip = 13
    static let lowerLip = 14
    
    // 얼굴 윤곽
    static let chin = 152
    static let foreheadCenter = 10
    static let leftCheek = 234
    static let rightCheek = 454
}

// MARK: - Filter Asset
/// 필터 에셋 정보
struct FilterAsset {
    let type: FaceFilterType
    let imageName: String?
    let modelName: String?  // 3D 모델용
    let anchorPoint: AnchorPoint
    let scale: CGFloat
    let offset: CGPoint
    
    enum AnchorPoint {
        case eyes       // 눈 사이
        case nose       // 코
        case mouth      // 입
        case forehead   // 이마
        case fullFace   // 전체 얼굴
    }
    
    static func asset(for type: FaceFilterType) -> FilterAsset? {
        switch type {
        case .glasses:
            return FilterAsset(
                type: type,
                imageName: "filter_glasses",
                modelName: nil,
                anchorPoint: .eyes,
                scale: 1.2,
                offset: CGPoint(x: 0, y: -0.02)
            )
        case .sunglasses:
            return FilterAsset(
                type: type,
                imageName: "filter_sunglasses",
                modelName: nil,
                anchorPoint: .eyes,
                scale: 1.3,
                offset: CGPoint(x: 0, y: -0.02)
            )
        case .catEars:
            return FilterAsset(
                type: type,
                imageName: "filter_cat_ears",
                modelName: nil,
                anchorPoint: .forehead,
                scale: 1.5,
                offset: CGPoint(x: 0, y: -0.15)
            )
        case .dogNose:
            return FilterAsset(
                type: type,
                imageName: "filter_dog_nose",
                modelName: nil,
                anchorPoint: .nose,
                scale: 0.8,
                offset: CGPoint(x: 0, y: 0)
            )
        case .crown:
            return FilterAsset(
                type: type,
                imageName: "filter_crown",
                modelName: nil,
                anchorPoint: .forehead,
                scale: 1.4,
                offset: CGPoint(x: 0, y: -0.12)
            )
        case .mask:
            return FilterAsset(
                type: type,
                imageName: "filter_mask",
                modelName: nil,
                anchorPoint: .fullFace,
                scale: 1.0,
                offset: CGPoint(x: 0, y: 0)
            )
        default:
            return nil
        }
    }
}
