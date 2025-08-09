import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

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
    
    func loadCurrentUser(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                let data = document.data() ?? [:]
                let heartCount = data["heartCount"] as? Int ?? 3
                let blockedUsers = data["blockedUsers"] as? [String] ?? []
                let email = data["email"] as? String
                let displayName = data["displayName"] as? String
                
                // User 생성 - User의 실제 초기화 함수에 맞게
                var user = User(uid: uid, email: email, displayName: displayName)
                user.heartCount = heartCount
                user.blockedUsers = blockedUsers
                self?.currentUser = user
                
                print("✅ 사용자 데이터 로드 완료: \(heartCount) 하트")
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
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).setData(userData) { [weak self] error in
            if error == nil {
                let user = User(uid: uid) // User의 초기화 함수는 기본값을 자동 설정
                self?.currentUser = user
                print("✅ 새 사용자 문서 생성 완료")
            } else {
                print("❌ 사용자 문서 생성 실패: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    // MARK: - Heart Management
    func updateHeartCount(uid: String, newCount: Int) {
        db.collection("users").document(uid).updateData([
            "heartCount": newCount
        ]) { error in
            if let error = error {
                print("❌ 하트 업데이트 실패: \(error)")
            } else {
                print("✅ 하트 업데이트 성공: \(newCount)개")
                self.currentUser?.heartCount = newCount
            }
        }
    }
    
    // MARK: - 하트 전송 개선
    // UserManager.swift
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
                print("❌ 하트 알림 전송 실패: \(error)")
            } else {
                print("✅ 하트 알림 전송 성공 (상대방: \(opponentId))")
            }
        }
    }

    
    // 사용자 문서가 없을 때 생성하고 하트 전송
    private func createUserAndSendHeart(_ opponentId: String) {
        print("⚠️ 상대방 문서가 없음. 새로 생성")
        
        let newData: [String: Any] = [
            "uid": opponentId,
            "heartCount": 4,  // 기본 3 + 받은 1
            "blockedUsers": [],
            "createdAt": Timestamp(date: Date()),
            "lastHeartReceivedAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(opponentId).setData(newData) { error in
            if error == nil {
                print("✅ 새 사용자 문서 생성 및 하트 전송 성공")
            } else {
                print("❌ 새 사용자 생성 실패: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    // 하트 알림 트리거 (Firebase에 알림 플래그 설정)
    private func triggerHeartNotification(to userId: String) {
        // Firebase Realtime Database에 알림 플래그 설정
        Database.database().reference()
            .child("notifications")
            .child(userId)
            .child("newHeart")
            .setValue([
                "timestamp": ServerValue.timestamp(),
                "from": Auth.auth().currentUser?.uid ?? "unknown"
            ])
        
        print("🔔 하트 알림 트리거 완료")
    }
    
    // MARK: - 하트 개수 실시간 관찰
    func observeUserHearts(uid: String, completion: @escaping (Int) -> Void) {
        db.collection("users").document(uid)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let heartCount = data["heartCount"] as? Int else {
                    print("❌ 하트 관찰 에러: \(error?.localizedDescription ?? "")")
                    return
                }
                
                completion(heartCount)
                print("👀 하트 개수 실시간 업데이트: \(heartCount)")
            }
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
                print("✅ 사용자 차단 완료: \(userId)")
            } else {
                print("❌ 사용자 차단 실패: \(error?.localizedDescription ?? "")")
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
                print("✅ 사용자 차단 해제: \(userId)")
            } else {
                print("❌ 차단 해제 실패: \(error?.localizedDescription ?? "")")
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
            print("❌ 자기 자신과는 매칭 불가")
            return false
        }
        
        // 2. 차단된 사용자와는 매칭 불가
        if isUserBlocked(userId) {
            print("❌ 차단된 사용자와는 매칭 불가: \(userId)")
            return false
        }
        
        // 3. 최근 매칭한 사용자와는 매칭 불가 (세션 기반)
        if hasRecentlyMatched(userId) {
            print("❌ 최근 매칭한 사용자와는 매칭 불가: \(userId)")
            return false
        }
        
        print("✅ 매칭 가능한 사용자: \(userId)")
        return true
    }
    
    // MARK: - Recent Matches (Session-based)
    func addRecentMatch(_ userId: String) {
        recentMatches.insert(userId)
        print("📝 세션 매칭 기록 추가: \(userId)")
        print("📊 현재 세션 매칭 기록: \(recentMatches.count)명")
        
        // 최근 5명만 유지 (메모리 관리)
        if recentMatches.count > 5 {
            // Set은 순서가 없으므로 배열로 변환 후 처리
            let sortedMatches = Array(recentMatches)
            if sortedMatches.count > 5 {
                recentMatches = Set(sortedMatches.suffix(5))
            }
        }
    }
    
    func hasRecentlyMatched(_ userId: String) -> Bool {
        return recentMatches.contains(userId)
    }
    
    func clearRecentMatches() {
        recentMatches.removeAll()
        print("🧹 세션 매칭 기록 초기화")
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
                print("✅ 매칭 횟수 증가")
            }
        }
    }
    
}
