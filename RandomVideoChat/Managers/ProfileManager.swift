import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles user profile management operations
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Gender Management

    func updateGender(_ gender: Gender) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let previousGender = UserManager.shared.currentUser?.gender
        UserManager.shared.currentUser?.gender = gender

        db.collection("users").document(uid).updateData([
            "gender": gender.rawValue
        ]) { error in
            if let error = error {
                UserManager.shared.currentUser?.gender = previousGender
                #if DEBUG
                print("❌ 성별 업데이트 실패: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("✅ 성별 업데이트 완료: \(gender.displayName)")
                #endif
            }
        }
    }

    func updatePreferredGender(_ gender: Gender?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let previousGender = UserManager.shared.currentUser?.preferredGender
        UserManager.shared.currentUser?.preferredGender = gender

        let genderValue = gender?.rawValue ?? ""
        db.collection("users").document(uid).updateData([
            "preferredGender": genderValue
        ]) { error in
            if let error = error {
                UserManager.shared.currentUser?.preferredGender = previousGender
                #if DEBUG
                print("❌ 선호 성별 업데이트 실패: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                if let gender = gender {
                    print("✅ 선호 성별 업데이트 완료: \(gender.displayName)")
                } else {
                    print("✅ 선호 성별 선택 해제 완료")
                }
                #endif
            }
        }
    }

    // MARK: - Terms Agreement

    func updateTermsAgreement(termsAgreedAt: Date, privacyAgreedAt: Date, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let data: [String: Any] = [
            "termsAgreedAt": Timestamp(date: termsAgreedAt),
            "privacyAgreedAt": Timestamp(date: privacyAgreedAt),
            "ageVerified": true
        ]

        db.collection("users").document(uid).updateData(data) { error in
            if let error = error {
                #if DEBUG
                print("❌ 약관 동의 저장 실패: \(error.localizedDescription)")
                #endif
                completion(false)
            } else {
                #if DEBUG
                print("✅ 약관 동의 저장 완료")
                #endif
                // Update UserManager's currentUser
                UserManager.shared.currentUser?.termsAgreedAt = termsAgreedAt
                UserManager.shared.currentUser?.privacyAgreedAt = privacyAgreedAt
                UserManager.shared.currentUser?.ageVerified = true
                completion(true)
            }
        }
    }

    // MARK: - User Stats

    func getUserStats(completion: @escaping (Int, Int) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(0, 0)
            return
        }

        db.collection("users").document(uid).getDocument { document, error in
            if let data = document?.data() {
                let totalMatches = data["totalMatches"] as? Int ?? 0
                let totalHeartsSent = data["totalHeartsSent"] as? Int ?? 0
                completion(totalMatches, totalHeartsSent)
            } else {
                completion(0, 0)
            }
        }
    }

    func incrementMatchCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).updateData([
            "totalMatches": FieldValue.increment(Int64(1)),
            "lastMatchAt": Timestamp(date: Date())
        ]) { error in
            if error == nil {
                #if DEBUG
                print("✅ 매칭 횟수 증가")
                #endif
            }
        }
    }

    // MARK: - Preference Rate (DISABLED - 선호도 로직 비활성화)
    // TODO: 성별 내 백분위 기반 매칭으로 재설계 필요

    func calculatePreferenceRate(callCount: Int, uniqueGivers: Int) -> Double {
        // DISABLED: 선호도 계산 비활성화
        return 50.0
        /*
        guard callCount >= 5 else { return 50.0 }
        guard callCount > 0 else { return 50.0 }
        return (Double(uniqueGivers) / Double(callCount)) * 100.0
        */
    }

    func incrementCallCount() {
        // DISABLED: 선호도 로직 비활성화
        #if DEBUG
        print("⏸️ incrementCallCount() - 선호도 로직 비활성화됨")
        #endif
        /*
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(uid)

        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            guard let self = self else { return nil }
            do {
                let snapshot = try transaction.getDocument(userRef)
                var data = snapshot.data() ?? [:]
                let currentCount = data["totalCallCount"] as? Int ?? 0
                let uniqueGivers = (data["uniqueHeartGivers"] as? [String] ?? []).count
                let newCount = currentCount + 1
                let newRate = self.calculatePreferenceRate(callCount: newCount, uniqueGivers: uniqueGivers)
                transaction.updateData([
                    "totalCallCount": newCount,
                    "preferenceRate": newRate
                ], forDocument: userRef)
                return nil
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
        }) { (_, error) in
            if error == nil {
                if var user = UserManager.shared.currentUser {
                    user.totalCallCount += 1
                    user.preferenceRate = self.calculatePreferenceRate(callCount: user.totalCallCount, uniqueGivers: user.uniqueHeartGivers.count)
                    UserManager.shared.currentUser = user
                }
                #if DEBUG
                print("✅ totalCallCount 증가 및 선호도 갱신")
                #endif
            }
        }
        */
    }

    func recordHeartReceived(from giverId: String) {
        // DISABLED: 선호도 로직 비활성화
        #if DEBUG
        print("⏸️ recordHeartReceived() - 선호도 로직 비활성화됨")
        #endif
        /*
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard !giverId.isEmpty else { return }
        let userRef = db.collection("users").document(uid)

        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            guard let self = self else { return nil }
            do {
                let snapshot = try transaction.getDocument(userRef)
                var data = snapshot.data() ?? [:]
                var givers = data["uniqueHeartGivers"] as? [String] ?? []
                let callCount = data["totalCallCount"] as? Int ?? 0
                if !givers.contains(giverId) {
                    givers.append(giverId)
                    let newRate = self.calculatePreferenceRate(callCount: callCount, uniqueGivers: givers.count)
                    transaction.updateData([
                        "uniqueHeartGivers": givers,
                        "preferenceRate": newRate
                    ], forDocument: userRef)
                }
                return nil
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
        }) { (_, error) in
            if error == nil {
                if var user = UserManager.shared.currentUser {
                    if !user.uniqueHeartGivers.contains(giverId) {
                        user.uniqueHeartGivers.append(giverId)
                        user.preferenceRate = self.calculatePreferenceRate(callCount: user.totalCallCount, uniqueGivers: user.uniqueHeartGivers.count)
                        UserManager.shared.currentUser = user
                    }
                }
                #if DEBUG
                print("✅ uniqueHeartGivers 업데이트 및 선호도 갱신")
                #endif
            }
        }
        */
    }
}
