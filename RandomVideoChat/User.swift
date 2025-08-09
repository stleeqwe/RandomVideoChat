import Foundation
import FirebaseFirestore

struct User: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    var heartCount: Int
    let createdAt: Date
    var blockedUsers: [String]
    
    init(uid: String, email: String? = nil, displayName: String? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.heartCount = 3  // 초기 하트 3개
        self.createdAt = Date()
        self.blockedUsers = []
    }
    
    // Firestore 데이터로 변환
    var dictionary: [String: Any] {
        return [
            "uid": uid,
            "email": email ?? "",
            "displayName": displayName ?? "",
            "heartCount": heartCount,
            "createdAt": Timestamp(date: createdAt),
            "blockedUsers": blockedUsers
        ]
    }
}
