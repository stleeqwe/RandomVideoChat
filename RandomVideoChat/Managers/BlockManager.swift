import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles user blocking and matching validation
class BlockManager: ObservableObject {
    static let shared = BlockManager()
    private let db = Firestore.firestore()

    /// Session-based recent matches to prevent re-matching
    private var recentMatches: Set<String> = []
    private static let maxRecentMatches = 5

    private init() {}

    // MARK: - Block Management

    func blockUser(_ userId: String) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(currentUid).updateData([
            "blockedUsers": FieldValue.arrayUnion([userId])
        ]) { error in
            if error == nil {
                UserManager.shared.currentUser?.blockedUsers.append(userId)
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
                UserManager.shared.currentUser?.blockedUsers.removeAll { $0 == userId }
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
        return UserManager.shared.currentUser?.blockedUsers.contains(userId) ?? false
    }

    // MARK: - Matching Validation

    func canMatchWith(_ userId: String) -> Bool {
        // 1. Cannot match with self
        if userId == Auth.auth().currentUser?.uid {
            #if DEBUG
            print("❌ 자기 자신과는 매칭 불가")
            #endif
            return false
        }

        // 2. Cannot match with blocked users
        if isUserBlocked(userId) {
            #if DEBUG
            print("❌ 차단된 사용자와는 매칭 불가: \(userId)")
            #endif
            return false
        }

        // 3. Cannot match with recently matched users (session-based)
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

    func addRecentMatch(_ userId: String) {
        recentMatches.insert(userId)
        #if DEBUG
        print("📝 세션 매칭 기록 추가: \(userId)")
        print("📊 현재 세션 매칭 기록: \(recentMatches.count)명")
        #endif

        // Keep only last N matches (memory management)
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

    func getRecentMatchesCount() -> Int {
        return recentMatches.count
    }

    // MARK: - Report and Block Combined

    func reportAndBlockUser(_ userId: String, reason: String) {
        // 1. Submit report
        ContentModerationManager.shared.reportUser(reportedUserId: userId, reason: reason) { success in
            if success {
                #if DEBUG
                print("✅ 신고 및 차단 완료: \(userId)")
                #endif
            }
        }

        // 2. Add to personal block list
        blockUser(userId)
    }
}
