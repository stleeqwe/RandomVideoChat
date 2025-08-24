import Foundation
import FirebaseAuth
import FirebaseFirestore

class DailyRewardManager {
    static let shared = DailyRewardManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func checkAndGrantDailyReward(completion: @escaping (Bool, String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, nil)
            return
        }
        
        let userRef = db.collection("users").document(uid)
        
        userRef.getDocument { [weak self] document, error in
            if let error = error {
                print("❌ Error fetching user document: \(error)")
                completion(false, nil)
                return
            }
            
            guard let data = document?.data() else {
                completion(false, nil)
                return
            }
            
            // 신규 가입자 제외 로직: 가입 당일에는 보상 지급하지 않음
            if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
                let calendar = Calendar.current
                let isCreatedToday = calendar.isDate(createdAt, inSameDayAs: Date())
                if isCreatedToday {
                    #if DEBUG
                    print("🛑 일일 보상 제외: 가입 당일 (uid=\(uid))")
                    #endif
                    completion(false, nil)
                    return
                }
            }

            let lastRewardDate = (data["lastRewardDate"] as? Timestamp)?.dateValue()
            let today = Calendar.current.startOfDay(for: Date())
            
            // 마지막 보상 날짜가 없거나 오늘과 다른 날이면 보상 지급
            if lastRewardDate == nil || !Calendar.current.isDate(lastRewardDate!, inSameDayAs: today) {
                self?.grantDailyReward(uid: uid, userRef: userRef) { success in
                    if success {
                        completion(true, "🎁 일일 출석 보상으로 하트 1개를 받았습니다!")
                    } else {
                        completion(false, nil)
                    }
                }
            } else {
                // 이미 오늘 보상을 받음
                completion(false, nil)
            }
        }
    }
    
    private func grantDailyReward(uid: String, userRef: DocumentReference, completion: @escaping (Bool) -> Void) {
        // 트랜잭션으로 원자적 업데이트
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // 트랜잭션 내부에서 마지막 보상 날짜 재확인하여 중복 지급 방지
            let data = userDocument.data() ?? [:]
            let lastRewardTimestamp = data["lastRewardDate"] as? Timestamp
            if let lastDate = lastRewardTimestamp?.dateValue() {
                if Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
                    // 이미 오늘 보상을 받았으므로 중단
                    errorPointer?.pointee = NSError(
                        domain: "DailyReward",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Already rewarded today"]
                    )
                    return nil
                }
            }

            let currentHeartCount = data["heartCount"] as? Int ?? 0
            
            // 하트 1개 추가 및 마지막 보상 날짜 업데이트
            transaction.updateData([
                "heartCount": currentHeartCount + 1,
                "lastRewardDate": Timestamp(date: Date()),
                "totalDailyRewards": FieldValue.increment(Int64(1))
            ], forDocument: userRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ Transaction failed: \(error)")
                completion(false)
            } else {
                print("✅ Daily reward granted successfully")
                // UserManager를 통해 업데이트 (AppStorage 자동 동기화)
                if let uid = Auth.auth().currentUser?.uid {
                    UserManager.shared.loadCurrentUser(uid: uid)
                }
                completion(true)
            }
        }
    }
    
    func getTimeUntilNextReward() -> String {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let components = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
        
        if let hours = components.hour, let minutes = components.minute {
            return "\(hours)시간 \(minutes)분"
        }
        return "계산 중..."
    }
}
