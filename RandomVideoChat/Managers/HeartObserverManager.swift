import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

/// Manages heart count observation from Firestore and Realtime Database
@MainActor
class HeartObserverManager: ObservableObject {
    // MARK: - Published Properties
    @Published var heartCount: Int = 0
    @Published var showHeartAnimation = false

    // MARK: - Private Properties
    private var heartCountListener: ListenerRegistration?
    private var heartNotificationHandle: DatabaseHandle?
    private var currentUserId: String?

    // MARK: - Callbacks
    var onHeartReceived: (() -> Void)?

    // MARK: - Initialization
    init(initialHeartCount: Int = 0) {
        self.heartCount = initialHeartCount
    }

    // MARK: - Public Methods

    /// Start observing heart count changes for the given user
    /// - Parameter userId: The user ID to observe
    func startObserving(userId: String) {
        // Clean up existing observers first
        stopObserving()
        currentUserId = userId

        observeHeartCount(uid: userId)
        observeNewHeartNotification(uid: userId)

        #if DEBUG
        print("❤️ HeartObserverManager: Started observing for user \(userId)")
        #endif
    }

    /// Stop all observers and clean up resources
    func stopObserving() {
        // Remove Firestore listener
        heartCountListener?.remove()
        heartCountListener = nil

        // Remove Realtime Database observer
        if let handle = heartNotificationHandle, let uid = currentUserId {
            Database.database().reference()
                .child("notifications")
                .child(uid)
                .child("newHeart")
                .removeObserver(withHandle: handle)
        }
        heartNotificationHandle = nil

        #if DEBUG
        print("🧹 HeartObserverManager: Observers removed")
        #endif
    }

    /// Deduct a heart from the user's account
    /// - Parameters:
    ///   - completion: Callback with success status
    func deductHeart(completion: @escaping (Bool) -> Void) {
        guard heartCount > 0, let uid = currentUserId else {
            completion(false)
            return
        }

        // Animate heart count change
        triggerHeartAnimation()

        // Update local state
        heartCount -= 1
        UserDefaults.standard.set(heartCount, forKey: "heartCount")

        // Update Firestore
        UserManager.shared.changeHeartCount(uid: uid, delta: -1)

        completion(true)
    }

    /// Send a heart to an opponent
    /// - Parameter opponentUserId: The opponent's user ID
    func sendHeartToOpponent(_ opponentUserId: String) {
        UserManager.shared.sendHeartToOpponent(opponentUserId)
    }

    /// Trigger heart animation
    func triggerHeartAnimation() {
        showHeartAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showHeartAnimation = false
        }
    }

    // MARK: - Private Methods

    private func observeHeartCount(uid: String) {
        heartCountListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let newCount = data["heartCount"] as? Int,
                      newCount != self.heartCount else { return }

                Task { @MainActor in
                    self.heartCount = newCount
                    UserDefaults.standard.set(newCount, forKey: "heartCount")
                }
            }
    }

    private func observeNewHeartNotification(uid: String) {
        let ref = Database.database().reference()
            .child("notifications")
            .child(uid)
            .child("newHeart")

        heartNotificationHandle = ref.observe(.childAdded) { [weak self] snapshot in
            guard let self = self else { return }

            // "from" 값 읽기 - 누가 하트를 보냈는지
            let fromUserId = (snapshot.value as? [String: Any])?["from"] as? String

            Task { @MainActor in
                self.heartCount += 1
                UserDefaults.standard.set(self.heartCount, forKey: "heartCount")
                self.onHeartReceived?()
            }

            // Update Firestore and remove notification
            UserManager.shared.changeHeartCount(uid: uid, delta: +1)

            // 발신자 기록 → preferenceRate 업데이트
            if let fromUserId = fromUserId, !fromUserId.isEmpty {
                UserManager.shared.recordHeartReceived(from: fromUserId)
                #if DEBUG
                print("❤️ 하트 수신 기록: from \(fromUserId)")
                #endif
            }

            snapshot.ref.removeValue()
        }
    }
}
