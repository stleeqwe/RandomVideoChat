import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

/// Core user management - heart system, user data loading
/// Auth operations -> AuthManager
/// Profile operations -> ProfileManager
/// Block operations -> BlockManager
class UserManager: ObservableObject {
    static let shared = UserManager()
    private let db = Firestore.firestore()

    @Published var currentUser: User?
    private var recentMatches: Set<String> = []

    private init() {
        loadCurrentUserIfNeeded()
    }

    // MARK: - User Loading

    func loadCurrentUserIfNeeded() {
        if let uid = Auth.auth().currentUser?.uid {
            loadCurrentUser(uid: uid)
        }
    }

    func loadCurrentUser(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                let data = document.data() ?? [:]
                let heartCount = data["heartCount"] as? Int ?? 3
                let blockedUsers = data["blockedUsers"] as? [String] ?? []
                let email = data["email"] as? String
                let displayName = data["displayName"] as? String
                let genderString = data["gender"] as? String ?? ""
                let preferredGenderString = data["preferredGender"] as? String ?? ""
                let ageVerified = data["ageVerified"] as? Bool ?? false
                let authProvider = data["authProvider"] as? String ?? "anonymous"
                let birthDateTimestamp = data["birthDate"] as? Timestamp
                let totalCallCount = data["totalCallCount"] as? Int ?? 0
                let uniqueHeartGivers = data["uniqueHeartGivers"] as? [String] ?? []
                let preferenceRate = data["preferenceRate"] as? Double ?? 50.0

                var user = User(uid: uid, email: email, displayName: displayName)
                user.heartCount = heartCount
                user.blockedUsers = blockedUsers
                user.gender = Gender(rawValue: genderString)
                user.preferredGender = Gender(rawValue: preferredGenderString)
                user.ageVerified = ageVerified
                user.authProvider = authProvider
                user.birthDate = birthDateTimestamp?.dateValue()
                user.totalCallCount = totalCallCount
                user.uniqueHeartGivers = uniqueHeartGivers
                user.preferenceRate = preferenceRate

                if let termsTimestamp = data["termsAgreedAt"] as? Timestamp {
                    user.termsAgreedAt = termsTimestamp.dateValue()
                }
                if let privacyTimestamp = data["privacyAgreedAt"] as? Timestamp {
                    user.privacyAgreedAt = privacyTimestamp.dateValue()
                }

                self?.currentUser = user

                #if DEBUG
                print("✅ 사용자 데이터 로드 완료: \(heartCount) 하트")
                #endif
            } else {
                self?.createUserDocument(uid: uid)
            }
        }
    }

    func createUserDocument(uid: String) {
        let userData: [String: Any] = [
            "uid": uid,
            "ageVerified": true,
            "heartCount": 3,
            "blockedUsers": [],
            "createdAt": Timestamp(date: Date()),
            "totalCallCount": 0,
            "uniqueHeartGivers": [],
            "preferenceRate": 50.0
        ]

        db.collection("users").document(uid).setData(userData) { [weak self] error in
            if error == nil {
                let user = User(uid: uid)
                self?.currentUser = user
                #if DEBUG
                print("✅ 새 사용자 문서 생성 완료")
                #endif
            } else {
                #if DEBUG
                print("❌ 사용자 문서 생성 실패: \(error?.localizedDescription ?? "")")
                #endif
            }
        }
    }

    // MARK: - Heart Management

    func updateHeartCount(uid: String, newCount: Int) {
        db.collection("users").document(uid).updateData([
            "heartCount": newCount
        ]) { error in
            if let error = error {
                #if DEBUG
                print("❌ 하트 업데이트 실패: \(error)")
                #endif
            } else {
                #if DEBUG
                print("✅ 하트 업데이트 성공: \(newCount)개")
                #endif
                self.currentUser?.heartCount = newCount
            }
        }
    }

    func changeHeartCount(uid: String, delta: Int) {
        db.collection("users").document(uid).updateData([
            "heartCount": FieldValue.increment(Int64(delta))
        ]) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("❌ 하트 수 변경 실패: \(error)")
                #endif
            } else {
                #if DEBUG
                print("✅ 하트 수 \(delta > 0 ? "증가" : "감소"): \(delta)")
                #endif
                self?.loadCurrentUser(uid: uid)
            }
        }
    }

    // MARK: - Heart Notification System

    func sendHeartToOpponent(_ opponentId: String) {
        let ref = Database.database().reference()
            .child("notifications")
            .child(opponentId)
            .child("newHeart")
            .childByAutoId()

        ref.setValue([
            "timestamp": ServerValue.timestamp(),
            "from": Auth.auth().currentUser?.uid ?? "unknown"
        ]) { error, _ in
            if let error = error {
                #if DEBUG
                print("❌ 하트 알림 전송 실패: \(error)")
                #endif
            } else {
                #if DEBUG
                print("✅ 하트 알림 전송 성공 (상대방: \(opponentId))")
                #endif
            }
        }
    }

    // MARK: - Real-time Heart Observation

    private var heartListener: ListenerRegistration?

    func observeUserHearts(uid: String, completion: @escaping (Int) -> Void) {
        heartListener?.remove()

        heartListener = db.collection("users").document(uid)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let heartCount = data["heartCount"] as? Int else {
                    #if DEBUG
                    print("❌ 하트 관찰 에러: \(error?.localizedDescription ?? "")")
                    #endif
                    return
                }

                completion(heartCount)
                #if DEBUG
                print("👀 하트 개수 실시간 업데이트: \(heartCount)")
                #endif
            }
    }

    func stopObservingHearts() {
        heartListener?.remove()
        heartListener = nil
    }

    // MARK: - Delegation to Other Managers

    // Auth operations - delegate to AuthManager
    func checkAutoLoginStatus() -> Bool {
        return AuthManager.shared.checkAutoLoginStatus()
    }

    func signOut() {
        AuthManager.shared.signOut()
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        AuthManager.shared.deleteAccount(completion: completion)
    }

    // Block operations - delegate to BlockManager
    func blockUser(_ userId: String) {
        BlockManager.shared.blockUser(userId)
    }

    func unblockUser(_ userId: String) {
        BlockManager.shared.unblockUser(userId)
    }

    func isUserBlocked(_ userId: String) -> Bool {
        return BlockManager.shared.isUserBlocked(userId)
    }

    func canMatchWith(_ userId: String) -> Bool {
        return BlockManager.shared.canMatchWith(userId)
    }

    func addRecentMatch(_ userId: String) {
        BlockManager.shared.addRecentMatch(userId)
    }

    func hasRecentlyMatched(_ userId: String) -> Bool {
        return BlockManager.shared.hasRecentlyMatched(userId)
    }

    func clearRecentMatches() {
        BlockManager.shared.clearRecentMatches()
    }

    func getRecentMatchesCount() -> Int {
        return BlockManager.shared.getRecentMatchesCount()
    }

    func reportAndBlockUser(_ userId: String, reason: String) {
        BlockManager.shared.reportAndBlockUser(userId, reason: reason)
    }

    // Profile operations - delegate to ProfileManager
    func updateGender(_ gender: Gender) {
        ProfileManager.shared.updateGender(gender)
    }

    func updatePreferredGender(_ gender: Gender?) {
        ProfileManager.shared.updatePreferredGender(gender)
    }

    func updateTermsAgreement(termsAgreedAt: Date, privacyAgreedAt: Date, completion: @escaping (Bool) -> Void) {
        ProfileManager.shared.updateTermsAgreement(termsAgreedAt: termsAgreedAt, privacyAgreedAt: privacyAgreedAt, completion: completion)
    }

    func hasAgreedToTerms() -> Bool {
        return currentUser?.hasAgreedToTerms ?? false
    }

    func getUserStats(completion: @escaping (Int, Int) -> Void) {
        ProfileManager.shared.getUserStats(completion: completion)
    }

    func incrementMatchCount() {
        ProfileManager.shared.incrementMatchCount()
    }

    func incrementCallCount() {
        ProfileManager.shared.incrementCallCount()
    }

    func recordHeartReceived(from giverId: String) {
        ProfileManager.shared.recordHeartReceived(from: giverId)
    }

    // MARK: - Data Cleanup (Called by AuthManager)

    func cleanupUserData(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        let errorsLock = NSLock()

        // 1. Delete Firestore user document
        group.enter()
        db.collection("users").document(uid).delete { error in
            if let error = error {
                #if DEBUG
                print("❌ Firestore 사용자 문서 삭제 실패: \(error.localizedDescription)")
                #endif
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            } else {
                #if DEBUG
                print("✅ Firestore 사용자 문서 삭제 성공")
                #endif
            }
            group.leave()
        }

        // 2. Delete presence data
        group.enter()
        let presenceRef = Database.database().reference().child("user_presence").child(uid)
        presenceRef.removeValue { error, _ in
            if let error = error {
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            }
            group.leave()
        }

        // 3. Delete notifications
        group.enter()
        let notificationsRef = Database.database().reference().child("notifications").child(uid)
        notificationsRef.removeValue { error, _ in
            if let error = error {
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            }
            group.leave()
        }

        // 4. Remove from matching queue
        group.enter()
        let matchingQueueRef = Database.database().reference().child("matching_queue")
        matchingQueueRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                for child in snapshot.children {
                    if let bucketSnapshot = child as? DataSnapshot {
                        let bucketRef = matchingQueueRef.child(bucketSnapshot.key).child(uid)
                        bucketRef.removeValue()
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                if let firstError = errors.first {
                    completion(.failure(firstError))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}

// MARK: - Moderation Extensions for UserManager
extension UserManager {
    func checkContentSafety(completion: @escaping (Bool, String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, "로그인이 필요합니다.")
            return
        }

        Firestore.firestore().collection("users").document(uid).getDocument { document, error in
            if let error = error {
                #if DEBUG
                print("❌ 사용자 정보 조회 실패: \(error.localizedDescription)")
                #endif
                completion(true, nil)
                return
            }

            guard let data = document?.data() else {
                completion(true, nil)
                return
            }

            // Check suspension
            if let isSuspended = data["isSuspended"] as? Bool, isSuspended {
                let reason = data["suspensionReason"] as? String ?? "계정 이용 제한"
                if let endDate = (data["suspensionEndDate"] as? Timestamp)?.dateValue() {
                    if endDate > Date() {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM월 dd일 HH:mm"
                        let endDateString = formatter.string(from: endDate)
                        completion(false, "\(reason)\n해제 예정: \(endDateString)")
                        return
                    }
                } else {
                    completion(false, reason)
                    return
                }
            }

            // Check age verification
            if let ageVerified = data["ageVerified"] as? Bool, !ageVerified {
                completion(false, "연령 인증이 필요합니다.")
                return
            }

            // Check terms agreement
            let termsAgreed = data["termsAgreedAt"] != nil
            let privacyAgreed = data["privacyAgreedAt"] != nil
            if !termsAgreed || !privacyAgreed {
                completion(false, "이용약관 동의가 필요합니다.")
                return
            }

            completion(true, nil)
        }
    }
}
