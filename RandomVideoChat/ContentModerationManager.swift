import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class ContentModerationManager: ObservableObject {
    static let shared = ContentModerationManager()
    private let db = Firestore.firestore()
    
    // 제재 임계값
    private let reportThreshold = 3        // 신고 3회 시 자동 제재
    private let blockThreshold = 5         // 차단 5회 시 계정 정지
    private let autoSuspensionDays = 7     // 자동 정지 기간 (일)
    
    private init() {}
    
    // MARK: - Report System
    func reportUser(reportedUserId: String, reason: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let reportData: [String: Any] = [
            "reportedUserId": reportedUserId,
            "reporterUserId": currentUid,
            "reason": reason,
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        // 1. 신고 데이터 저장
        db.collection("reports").addDocument(data: reportData) { [weak self] error in
            if let error = error {
                print("❌ 신고 실패: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("✅ 신고 접수 완료: \(reason)")
            
            // 2. 신고 횟수 확인 및 자동 제재 검토
            self?.checkAndApplyAutoSanction(reportedUserId: reportedUserId)
            completion(true)
        }
    }
    
    // MARK: - Auto Sanction System
    private func checkAndApplyAutoSanction(reportedUserId: String) {
        // 최근 7일간 신고 횟수 확인
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        db.collection("reports")
            .whereField("reportedUserId", isEqualTo: reportedUserId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: sevenDaysAgo))
            .getDocuments { [weak self] querySnapshot, error in
                
                guard let documents = querySnapshot?.documents else {
                    print("❌ 신고 기록 조회 실패: \(error?.localizedDescription ?? "")")
                    return
                }
                
                let reportCount = documents.count
                print("📊 사용자 \(reportedUserId) 최근 7일 신고 횟수: \(reportCount)")
                
                // 임계값 초과 시 자동 제재
                if reportCount >= self?.reportThreshold ?? 3 {
                    self?.applySuspension(userId: reportedUserId, days: self?.autoSuspensionDays ?? 7, reason: "자동 제재 - 신고 \(reportCount)회")
                }
            }
    }
    
    // MARK: - Suspension System
    func applySuspension(userId: String, days: Int, reason: String) {
        let suspensionEndDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        let suspensionData: [String: Any] = [
            "userId": userId,
            "startDate": Timestamp(date: Date()),
            "endDate": Timestamp(date: suspensionEndDate),
            "reason": reason,
            "isActive": true,
            "appliedBy": "system"
        ]
        
        db.collection("suspensions").addDocument(data: suspensionData) { error in
            if let error = error {
                print("❌ 계정 정지 실패: \(error.localizedDescription)")
            } else {
                print("⚠️ 계정 정지 적용: \(userId) - \(days)일간, 사유: \(reason)")
                
                // 사용자에게 정지 알림 전송
                self.sendSuspensionNotification(userId: userId, days: days, reason: reason)
            }
        }
    }
    
    private func sendSuspensionNotification(userId: String, days: Int, reason: String) {
        let notificationData: [String: Any] = [
            "type": "suspension",
            "title": "계정 이용 제한",
            "message": "귀하의 계정이 \(days)일간 이용 제한되었습니다.\n사유: \(reason)",
            "timestamp": Timestamp(date: Date()),
            "isRead": false
        ]
        
        Database.database().reference()
            .child("notifications")
            .child(userId)
            .child("suspension")
            .child(UUID().uuidString)
            .setValue(notificationData)
    }
    
    // MARK: - Suspension Check
    func checkUserSuspension(userId: String, completion: @escaping (Bool, String?) -> Void) {
        db.collection("suspensions")
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .whereField("endDate", isGreaterThan: Timestamp(date: Date()))
            .getDocuments { querySnapshot, error in
                
                guard let documents = querySnapshot?.documents,
                      let suspensionDoc = documents.first else {
                    completion(false, nil)
                    return
                }
                
                let data = suspensionDoc.data()
                let reason = data["reason"] as? String ?? "이용 제한"
                let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
                let endDateString = formatter.string(from: endDate)
                
                let message = "\(reason)\n해제 예정: \(endDateString)"
                completion(true, message)
            }
    }
    
    // MARK: - Trust Score System
    func calculateTrustScore(userId: String, completion: @escaping (Int) -> Void) {
        var trustScore = 100 // 기본 신뢰도 100점
        
        let group = DispatchGroup()
        
        // 신고 받은 횟수 차감
        group.enter()
        db.collection("reports")
            .whereField("reportedUserId", isEqualTo: userId)
            .getDocuments { querySnapshot, error in
                let reportCount = querySnapshot?.documents.count ?? 0
                trustScore -= (reportCount * 10) // 신고 1회당 -10점
                group.leave()
            }
        
        // 정지 기록 차감
        group.enter()
        db.collection("suspensions")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { querySnapshot, error in
                let suspensionCount = querySnapshot?.documents.count ?? 0
                trustScore -= (suspensionCount * 20) // 정지 1회당 -20점
                group.leave()
            }
        
        group.notify(queue: .main) {
            completion(max(0, trustScore)) // 최소 0점
        }
    }
    
    // MARK: - New User Restrictions
    func isNewUserRestricted(userId: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            guard let document = document,
                  let data = document.data(),
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                completion(false)
                return
            }
            
            // 가입 후 24시간 이내는 제한된 기능만 제공
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
            completion(daysSinceCreation < 1)
        }
    }
}

// MARK: - Moderation Extensions for UserManager
extension UserManager {
    func reportAndBlockUser(_ userId: String, reason: String) {
        // 1. 신고 접수
        ContentModerationManager.shared.reportUser(reportedUserId: userId, reason: reason) { success in
            if success {
                print("✅ 신고 및 차단 완료: \(userId)")
            }
        }
        
        // 2. 개인 차단 목록에 추가
        blockUser(userId)
    }
    
    func checkContentSafety(completion: @escaping (Bool, String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, "사용자 인증 실패")
            return
        }
        
        // 1. 계정 정지 상태 확인
        ContentModerationManager.shared.checkUserSuspension(userId: uid) { isSuspended, suspensionMessage in
            if isSuspended {
                completion(false, suspensionMessage)
                return
            }
            
            // 2. 신뢰도 점수 확인
            ContentModerationManager.shared.calculateTrustScore(userId: uid) { trustScore in
                if trustScore < 30 {
                    completion(false, "계정 신뢰도가 낮아 서비스 이용이 제한됩니다.")
                    return
                }
                
                completion(true, nil)
            }
        }
    }
}