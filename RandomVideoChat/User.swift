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
    var birthDate: Date?
    var ageVerified: Bool
    var authProvider: String?
    
    init(uid: String, email: String? = nil, displayName: String? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.heartCount = 3  // 초기 하트 3개
        self.createdAt = Date()
        self.blockedUsers = []
        self.gender = nil
        self.preferredGender = nil
        self.birthDate = nil
        self.ageVerified = false
        self.authProvider = "anonymous"
    }
    
    // Firestore 데이터로 변환
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "email": email ?? "",
            "displayName": displayName ?? "",
            "heartCount": heartCount,
            "createdAt": Timestamp(date: createdAt),
            "blockedUsers": blockedUsers,
            "gender": gender?.rawValue ?? "",
            "preferredGender": preferredGender?.rawValue ?? "",
            "ageVerified": ageVerified,
            "authProvider": authProvider ?? "anonymous"
        ]
        
        if let birthDate = birthDate {
            dict["birthDate"] = Timestamp(date: birthDate)
        }
        
        return dict
    }
    
    // 연령 계산 유틸리티
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
}
