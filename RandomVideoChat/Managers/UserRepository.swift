import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

// MARK: - UserRepository Protocol
protocol UserRepositoryProtocol {
    func loadUser(uid: String, completion: @escaping (Result<User, Error>) -> Void)
    func createUser(uid: String, completion: @escaping (Result<User, Error>) -> Void)
    func updateHeartCount(uid: String, newCount: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func changeHeartCount(uid: String, delta: Int, completion: @escaping (Result<Int, Error>) -> Void)
    func updateField(uid: String, field: String, value: Any, completion: @escaping (Result<Void, Error>) -> Void)
    func updateFields(uid: String, fields: [String: Any], completion: @escaping (Result<Void, Error>) -> Void)
    func observeUserHearts(uid: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration?
    func deleteUserData(uid: String, completion: @escaping (Result<Void, Error>) -> Void)
}

// MARK: - UserRepository Implementation
final class UserRepository: UserRepositoryProtocol {
    static let shared = UserRepository()

    private let db = Firestore.firestore()
    private let realtimeDb = Database.database()

    private init() {}

    // MARK: - Load User

    func loadUser(uid: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                logError(error, context: "Failed to load user", category: .user)
                completion(.failure(DataError.loadFailed(underlying: error)))
                return
            }

            guard let document = document, document.exists else {
                completion(.failure(DataError.notFound))
                return
            }

            let user = self.parseUserDocument(uid: uid, data: document.data() ?? [:])
            logDebug("User loaded: \(uid)", category: .user)
            completion(.success(user))
        }
    }

    // MARK: - Create User

    func createUser(uid: String, completion: @escaping (Result<User, Error>) -> Void) {
        let userData: [String: Any] = [
            "uid": uid,
            "ageVerified": true,
            "heartCount": Constants.Hearts.defaultCount,
            "blockedUsers": [],
            "createdAt": Timestamp(date: Date()),
            "totalCallCount": 0,
            "uniqueHeartGivers": [],
            "preferenceRate": 50.0
        ]

        db.collection("users").document(uid).setData(userData) { error in
            if let error = error {
                logError(error, context: "Failed to create user", category: .user)
                completion(.failure(DataError.saveFailed(underlying: error)))
                return
            }

            let user = User(uid: uid)
            logInfo("New user created: \(uid)", category: .user)
            completion(.success(user))
        }
    }

    // MARK: - Update Heart Count

    func updateHeartCount(uid: String, newCount: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).updateData([
            "heartCount": newCount
        ]) { error in
            if let error = error {
                logError(error, context: "Failed to update heart count", category: .user)
                completion(.failure(DataError.saveFailed(underlying: error)))
            } else {
                logDebug("Heart count updated to \(newCount)", category: .user)
                completion(.success(()))
            }
        }
    }

    func changeHeartCount(uid: String, delta: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        let userRef = db.collection("users").document(uid)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentCount = document.data()?["heartCount"] as? Int ?? 0
            let newCount = max(0, currentCount + delta)

            transaction.updateData(["heartCount": newCount], forDocument: userRef)
            return newCount
        }) { result, error in
            if let error = error {
                logError(error, context: "Failed to change heart count", category: .user)
                completion(.failure(DataError.saveFailed(underlying: error)))
            } else if let newCount = result as? Int {
                logDebug("Heart count changed by \(delta), now: \(newCount)", category: .user)
                completion(.success(newCount))
            } else {
                completion(.failure(DataError.invalidData))
            }
        }
    }

    // MARK: - Update Fields

    func updateField(uid: String, field: String, value: Any, completion: @escaping (Result<Void, Error>) -> Void) {
        updateFields(uid: uid, fields: [field: value], completion: completion)
    }

    func updateFields(uid: String, fields: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).updateData(fields) { error in
            if let error = error {
                logError(error, context: "Failed to update fields", category: .user)
                completion(.failure(DataError.saveFailed(underlying: error)))
            } else {
                logDebug("Fields updated: \(fields.keys.joined(separator: ", "))", category: .user)
                completion(.success(()))
            }
        }
    }

    // MARK: - Observe Hearts

    func observeUserHearts(uid: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration? {
        return db.collection("users").document(uid)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let heartCount = data["heartCount"] as? Int else {
                    if let error = error {
                        logError(error, context: "Heart observation error", category: .user)
                    }
                    return
                }
                onChange(heartCount)
            }
    }

    // MARK: - Delete User Data

    func deleteUserData(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        let errorsLock = NSLock()

        // Delete Firestore document
        group.enter()
        db.collection("users").document(uid).delete { error in
            if let error = error {
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            }
            group.leave()
        }

        // Delete presence data
        group.enter()
        realtimeDb.reference().child("user_presence").child(uid).removeValue { error, _ in
            if let error = error {
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            }
            group.leave()
        }

        // Delete notifications
        group.enter()
        realtimeDb.reference().child("notifications").child(uid).removeValue { error, _ in
            if let error = error {
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            }
            group.leave()
        }

        // Remove from matching queue
        group.enter()
        let queueRef = realtimeDb.reference().child("matching_queue")
        queueRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                for child in snapshot.children {
                    if let bucketSnapshot = child as? DataSnapshot {
                        queueRef.child(bucketSnapshot.key).child(uid).removeValue()
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                logInfo("User data deleted: \(uid)", category: .user)
                completion(.success(()))
            } else if let firstError = errors.first {
                logError(firstError, context: "Failed to delete user data", category: .user)
                completion(.failure(firstError))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Heart Notification

    func sendHeartNotification(to userId: String, from senderId: String, completion: ((Bool) -> Void)? = nil) {
        let ref = realtimeDb.reference()
            .child("notifications")
            .child(userId)
            .child("newHeart")
            .childByAutoId()

        ref.setValue([
            "timestamp": ServerValue.timestamp(),
            "from": senderId
        ]) { error, _ in
            if let error = error {
                logError(error, context: "Failed to send heart notification", category: .user)
                completion?(false)
            } else {
                logDebug("Heart notification sent to \(userId)", category: .user)
                completion?(true)
            }
        }
    }

    // MARK: - Parse Document

    private func parseUserDocument(uid: String, data: [String: Any]) -> User {
        var user = User(
            uid: uid,
            email: data["email"] as? String,
            displayName: data["displayName"] as? String
        )

        user.heartCount = data["heartCount"] as? Int ?? Constants.Hearts.defaultCount
        user.blockedUsers = data["blockedUsers"] as? [String] ?? []
        user.gender = Gender(rawValue: data["gender"] as? String ?? "")
        user.preferredGender = Gender(rawValue: data["preferredGender"] as? String ?? "")
        user.ageVerified = data["ageVerified"] as? Bool ?? false
        user.authProvider = data["authProvider"] as? String ?? "anonymous"
        user.totalCallCount = data["totalCallCount"] as? Int ?? 0
        user.uniqueHeartGivers = data["uniqueHeartGivers"] as? [String] ?? []
        user.preferenceRate = data["preferenceRate"] as? Double ?? 50.0

        if let birthDateTimestamp = data["birthDate"] as? Timestamp {
            user.birthDate = birthDateTimestamp.dateValue()
        }
        if let termsTimestamp = data["termsAgreedAt"] as? Timestamp {
            user.termsAgreedAt = termsTimestamp.dateValue()
        }
        if let privacyTimestamp = data["privacyAgreedAt"] as? Timestamp {
            user.privacyAgreedAt = privacyTimestamp.dateValue()
        }

        return user
    }
}

// MARK: - Moderation Extensions
extension UserRepository {
    func checkUserSafety(uid: String, completion: @escaping (Bool, String?) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                logError(error, context: "Failed to check user safety", category: .user)
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
                        completion(false, "\(reason)\n해제 예정: \(formatter.string(from: endDate))")
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
            if data["termsAgreedAt"] == nil || data["privacyAgreedAt"] == nil {
                completion(false, "이용약관 동의가 필요합니다.")
                return
            }

            completion(true, nil)
        }
    }
}
