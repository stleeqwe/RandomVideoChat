import Foundation
import FirebaseFirestore

enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    
    var icon: String {
        switch self {
        case .male:
            return "person.fill"
        case .female:
            return "person.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .male:
            return "남"
        case .female:
            return "여"
        }
    }
}

struct User: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    var heartCount: Int
    let createdAt: Date
    var blockedUsers: [String]
    var gender: Gender?
    var preferredGender: Gender?
    
    init(uid: String, email: String? = nil, displayName: String? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.heartCount = 3  // 초기 하트 3개
        self.createdAt = Date()
        self.blockedUsers = []
        self.gender = nil
        self.preferredGender = nil
    }
    
    // Firestore 데이터로 변환
    var dictionary: [String: Any] {
        return [
            "uid": uid,
            "email": email ?? "",
            "displayName": displayName ?? "",
            "heartCount": heartCount,
            "createdAt": Timestamp(date: createdAt),
            "blockedUsers": blockedUsers,
            "gender": gender?.rawValue ?? "",
            "preferredGender": preferredGender?.rawValue ?? ""
        ]
    }
}
