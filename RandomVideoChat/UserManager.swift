import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import AuthenticationServices
import CryptoKit

class UserManager: ObservableObject {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    
    @Published var currentUser: User?
    private var recentMatches: Set<String> = []  // 세션 동안 매칭된 사용자 ID
    
    private init() {
        loadCurrentUserIfNeeded()
    }
    
    // MARK: - User Management
    func loadCurrentUserIfNeeded() {
        if let uid = Auth.auth().currentUser?.uid {
            loadCurrentUser(uid: uid)
        }
    }
    
    // 자동 로그인 상태 확인
    func checkAutoLoginStatus() -> Bool {
        return Auth.auth().currentUser != nil
    }
    
    // 로그아웃
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            clearRecentMatches()
            #if DEBUG
            print("✅ 로그아웃 완료")
            #endif
        } catch {
            #if DEBUG
            print("❌ 로그아웃 실패: \(error.localizedDescription)")
            #endif
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
                
                // User 생성 - User의 실제 초기화 함수에 맞게
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

                // 약관 동의 정보 로드
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
                // 사용자 문서가 없으면 생성
                self?.createUserDocument(uid: uid)
            }
        }
    }
    
    func createUserDocument(uid: String) {
        let userData: [String: Any] = [
            "uid": uid,
            "heartCount": 3,
            "blockedUsers": [],
            "createdAt": Timestamp(date: Date()),
            "totalCallCount": 0,
            "uniqueHeartGivers": [],
            "preferenceRate": 50.0
        ]
        
        db.collection("users").document(uid).setData(userData) { [weak self] error in
            if error == nil {
                let user = User(uid: uid) // User의 초기화 함수는 기본값을 자동 설정
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

    // MARK: - Preference-based Matching Helpers
    private func calculatePreferenceRate(callCount: Int, uniqueGivers: Int) -> Double {
        guard callCount >= 5 else { return 50.0 }
        guard callCount > 0 else { return 50.0 }
        return (Double(uniqueGivers) / Double(callCount)) * 100.0
    }

    func incrementCallCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(uid)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
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
        }) { [weak self] (_, error) in
            if error == nil {
                // Update local model
                if var user = self?.currentUser {
                    user.totalCallCount += 1
                    user.preferenceRate = self?.calculatePreferenceRate(callCount: user.totalCallCount, uniqueGivers: user.uniqueHeartGivers.count) ?? user.preferenceRate
                    self?.currentUser = user
                }
                #if DEBUG
                print("✅ totalCallCount 증가 및 선호도 갱신")
                #endif
            } else {
                #if DEBUG
                print("❌ totalCallCount 증가 실패: \(error!.localizedDescription)")
                #endif
            }
        }
    }

    func recordHeartReceived(from giverId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard !giverId.isEmpty else { return }
        let userRef = db.collection("users").document(uid)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
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
        }) { [weak self] (_, error) in
            if error == nil {
                if var user = self?.currentUser {
                    if !user.uniqueHeartGivers.contains(giverId) {
                        user.uniqueHeartGivers.append(giverId)
                        user.preferenceRate = self?.calculatePreferenceRate(callCount: user.totalCallCount, uniqueGivers: user.uniqueHeartGivers.count) ?? user.preferenceRate
                        self?.currentUser = user
                    }
                }
                #if DEBUG
                print("✅ uniqueHeartGivers 업데이트 및 선호도 갱신")
                #endif
            } else {
                #if DEBUG
                print("❌ uniqueHeartGivers 업데이트 실패: \(error!.localizedDescription)")
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
        // 기존 리스너 정리
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
    
    // MARK: - Block Management
    func blockUser(_ userId: String) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Firestore에 차단 정보 저장
        db.collection("users").document(currentUid).updateData([
            "blockedUsers": FieldValue.arrayUnion([userId])
        ]) { error in
            if error == nil {
                self.currentUser?.blockedUsers.append(userId)
                #if DEBUG
                print("✅ 사용자 차단 완료: \(userId)")
                #endif
            } else {
                #if DEBUG
                print("❌ 사용자 차단 실패: \(error?.localizedDescription ?? "")")
                #endif
            }
        }
    }
    
    func unblockUser(_ userId: String) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(currentUid).updateData([
            "blockedUsers": FieldValue.arrayRemove([userId])
        ]) { error in
            if error == nil {
                self.currentUser?.blockedUsers.removeAll { $0 == userId }
                #if DEBUG
                print("✅ 사용자 차단 해제: \(userId)")
                #endif
            } else {
                #if DEBUG
                print("❌ 차단 해제 실패: \(error?.localizedDescription ?? "")")
                #endif
            }
        }
    }
    
    func isUserBlocked(_ userId: String) -> Bool {
        return currentUser?.blockedUsers.contains(userId) ?? false
    }
    
    // MARK: - Matching Validation
    func canMatchWith(_ userId: String) -> Bool {
        // 1. 자기 자신과는 매칭 불가
        if userId == Auth.auth().currentUser?.uid {
            #if DEBUG
            print("❌ 자기 자신과는 매칭 불가")
            #endif
            return false
        }
        
        // 2. 차단된 사용자와는 매칭 불가
        if isUserBlocked(userId) {
            #if DEBUG
            print("❌ 차단된 사용자와는 매칭 불가: \(userId)")
            #endif
            return false
        }
        
        // 3. 최근 매칭한 사용자와는 매칭 불가 (세션 기반)
        if hasRecentlyMatched(userId) {
            #if DEBUG
            print("❌ 최근 매칭한 사용자와는 매칭 불가: \(userId)")
            #endif
            return false
        }
        
        #if DEBUG
        print("✅ 매칭 가능한 사용자: \(userId)")
        #endif
        return true
    }
    
    // MARK: - Recent Matches (Session-based)
    private static let maxRecentMatches = 5
    
    func addRecentMatch(_ userId: String) {
        recentMatches.insert(userId)
        #if DEBUG
        print("📝 세션 매칭 기록 추가: \(userId)")
        print("📊 현재 세션 매칭 기록: \(recentMatches.count)명")
        #endif
        
        // 최근 5명만 유지 (메모리 관리)
        if recentMatches.count > Self.maxRecentMatches {
            let matchesArray = Array(recentMatches)
            recentMatches = Set(matchesArray.suffix(Self.maxRecentMatches))
        }
    }
    
    func hasRecentlyMatched(_ userId: String) -> Bool {
        return recentMatches.contains(userId)
    }
    
    func clearRecentMatches() {
        recentMatches.removeAll()
        #if DEBUG
        print("🧹 세션 매칭 기록 초기화")
        #endif
    }
    
    // 세션 매칭 기록 개수 반환 (MainView 디버그용)
    func getRecentMatchesCount() -> Int {
        return recentMatches.count
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
    
    // MARK: - Atomic Heart Management
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
                // Firestore에서 최신 데이터 다시 로드하여 완전 동기화
                self?.loadCurrentUser(uid: uid)
            }
        }
    }
    
    // MARK: - Gender Management
    func updateGender(_ gender: Gender) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 먼저 로컬 상태 갱신 - UI를 즉시 업데이트
        let previousGender = currentUser?.gender
        currentUser?.gender = gender
        
        // 백그라운드에서 비동기 처리
        Task {
            await updateGenderAsync(uid: uid, gender: gender, previousGender: previousGender)
        }
    }
    
    @MainActor
    private func updateGenderAsync(uid: String, gender: Gender, previousGender: Gender?) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "gender": gender.rawValue
            ])
            #if DEBUG
            print("✅ 성별 업데이트 완료: \(gender.displayName)")
            #endif
        } catch {
            // 실패 시 로컬 상태 롤백
            currentUser?.gender = previousGender
            #if DEBUG
            print("❌ 성별 업데이트 실패: \(error.localizedDescription)")
            #endif
        }
    }
    
    func updatePreferredGender(_ gender: Gender?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 먼저 로컬 상태 갱신 - UI를 즉시 업데이트
        let previousGender = currentUser?.preferredGender
        currentUser?.preferredGender = gender
        
        // 백그라운드에서 비동기 처리
        Task {
            await updatePreferredGenderAsync(uid: uid, gender: gender, previousGender: previousGender)
        }
    }
    
    @MainActor
    private func updatePreferredGenderAsync(uid: String, gender: Gender?, previousGender: Gender?) async {
        do {
            let genderValue = gender?.rawValue ?? ""
            try await db.collection("users").document(uid).updateData([
                "preferredGender": genderValue
            ])
            #if DEBUG
            if let gender = gender {
                print("✅ 선호 성별 업데이트 완료: \(gender.displayName)")
            } else {
                print("✅ 선호 성별 선택 해제 완료")
            }
            #endif
        } catch {
            // 실패 시 로컬 상태 롤백
            currentUser?.preferredGender = previousGender
            #if DEBUG
            print("❌ 선호 성별 업데이트 실패: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Account Deletion with Re-authentication
    
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])))
            return
        }
        
        let uid = currentUser.uid
        
        // 먼저 사용자 데이터를 삭제한 후 계정 삭제
        cleanupUserData(uid: uid) { [weak self] cleanupResult in
            switch cleanupResult {
            case .success:
                // 데이터 삭제 성공 후 계정 삭제 시도
                currentUser.delete { error in
                    if let error = error as NSError? {
                        // Check if re-authentication is required
                        if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                            // Re-authenticate with Apple Sign In
                            if #available(iOS 13.0, *) {
                                self?.reauthenticateWithApple { reauthResult in
                                    switch reauthResult {
                                    case .success:
                                        // Try deletion again after re-authentication
                                        Auth.auth().currentUser?.delete { deleteError in
                                            if let deleteError = deleteError {
                                                #if DEBUG
                                                print("❌ 재인증 후 계정 삭제 실패: \(deleteError.localizedDescription)")
                                                #endif
                                                completion(.failure(deleteError))
                                            } else {
                                                #if DEBUG
                                                print("✅ 계정 삭제 성공")
                                                #endif
                                                self?.currentUser = nil
                                                self?.clearRecentMatches()
                                                completion(.success(()))
                                            }
                                        }
                                    case .failure(let reauthError):
                                        #if DEBUG
                                        print("❌ 재인증 실패: \(reauthError.localizedDescription)")
                                        #endif
                                        completion(.failure(reauthError))
                                    }
                                }
                            } else {
                                completion(.failure(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Re-authentication requires iOS 13.0 or later"])))
                            }
                        } else {
                            #if DEBUG
                            print("❌ 계정 삭제 실패: \(error.localizedDescription)")
                            #endif
                            completion(.failure(error))
                        }
                    } else {
                        // Account deleted successfully
                        #if DEBUG
                        print("✅ 계정 삭제 성공")
                        #endif
                        self?.currentUser = nil
                        self?.clearRecentMatches()
                        completion(.success(()))
                    }
                }
            case .failure(let cleanupError):
                #if DEBUG
                print("⚠️ 데이터 삭제 실패했지만 계정 삭제 시도: \(cleanupError.localizedDescription)")
                #endif
                // 데이터 삭제가 실패해도 계정 삭제는 시도
                currentUser.delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        self?.currentUser = nil
                        self?.clearRecentMatches()
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func reauthenticateWithApple(completion: @escaping (Result<Void, Error>) -> Void) {
        let nonce = randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = sha256(nonce)
        request.requestedScopes = []
        
        let coordinator = AppleReauthCoordinator(
            currentNonce: nonce,
            completion: completion
        )
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        
        // Keep reference to prevent deallocation
        objc_setAssociatedObject(self, &AssociatedKeys.reauthCoordinator, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        controller.performRequests()
    }
    
    private func cleanupUserData(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // 1. Firestore 사용자 문서 삭제
        group.enter()
        db.collection("users").document(uid).delete { error in
            if let error = error {
                #if DEBUG
                print("❌ Firestore 사용자 문서 삭제 실패: \(error.localizedDescription)")
                #endif
                errors.append(error)
            } else {
                #if DEBUG
                print("✅ Firestore 사용자 문서 삭제 성공")
                #endif
            }
            group.leave()
        }
        
        // 2. Realtime Database - presence 삭제
        group.enter()
        let presenceRef = Database.database().reference().child("user_presence").child(uid)
        presenceRef.removeValue { error, _ in
            if let error = error {
                #if DEBUG
                print("❌ Presence 데이터 삭제 실패: \(error.localizedDescription)")
                #endif
                errors.append(error)
            } else {
                #if DEBUG
                print("✅ Presence 데이터 삭제 성공")
                #endif
            }
            group.leave()
        }
        
        // 3. Realtime Database - notifications 삭제
        group.enter()
        let notificationsRef = Database.database().reference().child("notifications").child(uid)
        notificationsRef.removeValue { error, _ in
            if let error = error {
                #if DEBUG
                print("❌ Notifications 데이터 삭제 실패: \(error.localizedDescription)")
                #endif
                errors.append(error)
            } else {
                #if DEBUG
                print("✅ Notifications 데이터 삭제 성공")
                #endif
            }
            group.leave()
        }
        
        // 4. Realtime Database - matching_queue에서 사용자 제거
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
            #if DEBUG
            print("✅ Matching queue에서 사용자 제거 완료")
            #endif
            group.leave()
        }
        
        // 모든 작업 완료 후 콜백
        group.notify(queue: .main) {
            if errors.isEmpty {
                #if DEBUG
                print("✅ 모든 사용자 데이터 삭제 성공")
                #endif
                completion(.success(()))
            } else {
                #if DEBUG
                print("⚠️ 일부 데이터 삭제 실패: \(errors.count)개 오류")
                #endif
                // 일부 실패해도 계정 삭제는 계속 진행
                completion(.failure(errors.first!))
            }
        }
    }
    
    // MARK: - Helper Methods for Apple Re-auth
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Apple Re-authentication Coordinator

private struct AssociatedKeys {
    static var reauthCoordinator = "reauthCoordinator"
}

@available(iOS 13.0, *)
class AppleReauthCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let currentNonce: String
    private let completion: (Result<Void, Error>) -> Void
    
    init(currentNonce: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.currentNonce = currentNonce
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            completion(.failure(NSError(domain: "AppleReauth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get Apple ID token"])))
            return
        }
        
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: currentNonce
        )
        
        Auth.auth().currentUser?.reauthenticate(with: credential) { _, error in
            if let error = error {
                self.completion(.failure(error))
            } else {
                self.completion(.success(()))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 모든 윈도우 시도
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        
        // 대체 방법: keyWindow 직접 찾기
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        
        // 최후의 수단: 철 번째 윈도우
        if let window = UIApplication.shared.windows.first {
            return window
        }
        
        // 수모든 방법 실패 시 새 윈도우 생성
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
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

        db.collection("users").document(uid).updateData(data) { [weak self] error in
            if let error = error {
                #if DEBUG
                print("❌ 약관 동의 저장 실패: \(error.localizedDescription)")
                #endif
                completion(false)
            } else {
                #if DEBUG
                print("✅ 약관 동의 저장 완료")
                #endif
                self?.currentUser?.termsAgreedAt = termsAgreedAt
                self?.currentUser?.privacyAgreedAt = privacyAgreedAt
                self?.currentUser?.ageVerified = true
                completion(true)
            }
        }
    }

    func hasAgreedToTerms() -> Bool {
        return currentUser?.hasAgreedToTerms ?? false
    }
}
