import Foundation
import UIKit
import FirebaseDatabase
import FirebaseAuth

// MARK: - Matching State
enum MatchingState: Equatable {
    case idle
    case registering
    case waiting
    case matched(matchId: String, channelName: String, opponentId: String)
    case error(MatchingError)

    static func == (lhs: MatchingState, rhs: MatchingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.registering, .registering): return true
        case (.waiting, .waiting): return true
        case let (.matched(m1, c1, o1), .matched(m2, c2, o2)):
            return m1 == m2 && c1 == c2 && o1 == o2
        case let (.error(e1), .error(e2)):
            return e1 == e2
        default: return false
        }
    }
}

// MARK: - Observer Info
private struct ObserverInfo {
    let reference: DatabaseReference
    let handle: DatabaseHandle
}

// MARK: - MatchingManager
/// Production-grade MatchingManager
/// Responsibilities:
/// - Register/unregister from matching queue
/// - Observe server-side matching results
/// - Signal call state changes
/// - NO client-side matching logic (server handles all matching)
final class MatchingManager: ObservableObject {

    // MARK: - Singleton
    static let shared = MatchingManager()

    // MARK: - Properties
    private let database = Database.database()
    private let config = MatchingConfig.shared

    // Database observers with references for proper cleanup
    private var statusObserver: ObserverInfo?
    private var callEndObserver: ObserverInfo?
    private var timerObserver: ObserverInfo?
    private var presenceObserver: ObserverInfo?
    private var statusEndedObserver: ObserverInfo?
    private var cameraStatusObserver: ObserverInfo?
    private var connectionObserver: ObserverInfo?

    // State
    @Published private(set) var state: MatchingState = .idle
    @Published var isMatching = false
    @Published var matchedUserId: String?
    @Published var isMatched = false
    @Published var callEndedByOpponent = false

    // Current match info
    private(set) var currentMatchId: String?
    private(set) var currentChannelName: String?

    // Timeout handling
    private var matchingTimeoutWorkItem: DispatchWorkItem?

    // MARK: - Initialization
    private init() {
        setupAppLifecycleObservers()
        setupConnectionMonitoring()
    }

    deinit {
        cleanupAllObservers()
        NotificationCenter.default.removeObserver(self)
        #if DEBUG
        print("🧹 MatchingManager deinitialized")
        #endif
    }

    // MARK: - Configuration
    struct MatchingConfig {
        static let shared = MatchingConfig()

        let matchingTimeoutSeconds: TimeInterval = 120  // 2 minutes
        let presenceTimeoutSeconds: TimeInterval = 15   // 15 seconds grace period
        let queueCleanupDelaySeconds: TimeInterval = 3  // Delay before removing from queue
    }

    // MARK: - App Lifecycle
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleAppWillTerminate() {
        #if DEBUG
        print("🚨 App terminating - cleaning up matching state")
        #endif
        signalCallEnd()
        cleanupOnDisconnect()
    }

    @objc private func handleAppDidEnterBackground() {
        // Set onDisconnect handlers to clean up if connection drops
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = database.reference().child("matching_queue").child(userId)
        userRef.onDisconnectRemoveValue()
    }

    // MARK: - Connection Monitoring
    private func setupConnectionMonitoring() {
        let connectedRef = database.reference().child(".info/connected")
        let handle = connectedRef.observe(.value) { [weak self] snapshot in
            guard let connected = snapshot.value as? Bool else { return }
            #if DEBUG
            print("🔌 Firebase connection: \(connected ? "✅ connected" : "❌ disconnected")")
            #endif

            if !connected && self?.state == .waiting {
                // Connection lost while waiting - will auto-reconnect
                #if DEBUG
                print("⚠️ Connection lost while waiting - Firebase will auto-reconnect")
                #endif
            }
        }
        connectionObserver = ObserverInfo(reference: connectedRef, handle: handle)
    }

    // MARK: - Public API: Start Matching
    func startMatching() {
        #if DEBUG
        print("📱 MatchingManager: startMatching called")
        #endif

        // Guard: Already matching
        guard state == .idle || state == .error(.cancelled) else {
            #if DEBUG
            print("⚠️ Already in matching state: \(state)")
            #endif
            return
        }

        // Guard: Authentication
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("❌ Not authenticated")
            #endif
            updateState(.error(.notAuthenticated))
            return
        }

        // Reset state
        updateState(.registering)
        resetMatchState()

        // Register in queue
        registerInQueue(userId: currentUserId)
    }

    // MARK: - Public API: Cancel Matching
    func cancelMatching() {
        #if DEBUG
        print("🛑 Cancelling matching")
        #endif

        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Cancel timeout
        matchingTimeoutWorkItem?.cancel()
        matchingTimeoutWorkItem = nil

        // Remove from queue
        removeFromQueue(userId: userId)

        // Cleanup observers
        cleanupMatchingObservers()

        // Reset state
        resetMatchState()
        updateState(.idle)

        // Clear Keychain data
        clearMatchingData()
    }

    // MARK: - Queue Registration (Server-Side Matching)
    private func registerInQueue(userId: String) {
        let queueRef = database.reference().child("matching_queue").child(userId)

        // Get user preferences
        let currentUser = UserManager.shared.currentUser
        let userGender = currentUser?.gender?.rawValue ?? "any"
        let preferredGender = currentUser?.preferredGender?.rawValue ?? "any"

        // Determine bucket for indexed queries
        let bucket = getBucket(for: userGender)

        // Queue entry data
        let queueData: [String: Any] = [
            "userId": userId,
            "status": "waiting",
            "gender": userGender,
            "preferredGender": preferredGender,
            "bucket": bucket,
            "timestamp": ServerValue.timestamp(),
            "clientVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]

        #if DEBUG
        print("═══════════════════════════════════════")
        print("📤 REGISTERING IN QUEUE")
        print("   User ID: \(userId)")
        print("   Gender: \(userGender)")
        print("   Preferred: \(preferredGender)")
        print("   Bucket: \(bucket)")
        print("   Data: \(queueData)")
        print("═══════════════════════════════════════")
        #endif

        // Register in queue
        queueRef.setValue(queueData) { [weak self] error, _ in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("❌ Failed to register in queue: \(error.localizedDescription)")
                #endif
                self.updateState(.error(.networkError))
                return
            }

            #if DEBUG
            print("✅ Registered in matching queue")
            print("   Gender: \(userGender), Preferred: \(preferredGender), Bucket: \(bucket)")
            #endif

            // Set onDisconnect handler
            queueRef.onDisconnectRemoveValue()

            // Update state
            self.updateState(.waiting)

            // Setup presence
            self.setupPresence(userId: userId)

            // Start observing for match result
            self.observeMatchResult(userId: userId)

            // Start timeout
            self.startMatchingTimeout()
        }
    }

    private func getBucket(for gender: String) -> String {
        switch gender.lowercased() {
        case "male": return "waiting_male"
        case "female": return "waiting_female"
        default: return "waiting_any"
        }
    }

    // MARK: - Observe Match Result
    private func observeMatchResult(userId: String) {
        let userQueueRef = database.reference().child("matching_queue").child(userId)

        let handle = userQueueRef.observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any],
                  let status = data["status"] as? String else { return }

            #if DEBUG
            print("📊 Queue status update: \(status)")
            #endif

            // Already matched - ignore further updates
            if case .matched = self.state { return }

            if status == "matched" {
                // Extract match info
                guard let matchId = data["matchId"] as? String,
                      let channelName = data["channelName"] as? String,
                      let matchedWith = data["matchedWith"] as? String,
                      !matchId.isEmpty,
                      !channelName.isEmpty else {
                    #if DEBUG
                    print("⚠️ Matched but missing data")
                    #endif
                    return
                }

                #if DEBUG
                print("🎯 Match found!")
                print("   Match ID: \(matchId)")
                print("   Channel: \(channelName)")
                print("   Opponent: \(matchedWith)")
                #endif

                // Cancel timeout
                self.matchingTimeoutWorkItem?.cancel()
                self.matchingTimeoutWorkItem = nil

                // Store match info
                self.currentMatchId = matchId
                self.currentChannelName = channelName
                self.matchedUserId = matchedWith

                // Save to Keychain for secure recovery
                _ = KeychainManager.save(channelName, forKey: .currentChannelName)
                _ = KeychainManager.save(matchId, forKey: .currentMatchId)

                // Record in session history
                UserManager.shared.addRecentMatch(matchedWith)

                // Update state
                self.updateState(.matched(matchId: matchId, channelName: channelName, opponentId: matchedWith))

                // Clean up queue entry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + self.config.queueCleanupDelaySeconds) {
                    self.removeFromQueue(userId: userId)
                }
            }
        }
        statusObserver = ObserverInfo(reference: userQueueRef, handle: handle)
    }

    // MARK: - Presence Tracking
    private func setupPresence(userId: String) {
        let presenceRef = database.reference().child("presence").child(userId)

        presenceRef.setValue([
            "online": true,
            "lastSeen": ServerValue.timestamp()
        ])

        presenceRef.onDisconnectUpdateChildValues([
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ])
    }

    // MARK: - Timeout Handling
    private func startMatchingTimeout() {
        matchingTimeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .waiting else { return }

            #if DEBUG
            print("⏰ Matching timeout - no partner found")
            #endif

            self.cancelMatching()
            self.updateState(.error(.timeout))
        }

        matchingTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + config.matchingTimeoutSeconds,
            execute: workItem
        )
    }

    // MARK: - Match Success Handler (Called from VideoCallView)
    func handleMatchSuccess(matchId: String, channelName: String, matchedUserId: String) {
        #if DEBUG
        print("🎉 handleMatchSuccess called")
        print("   Match ID: \(matchId)")
        print("   Channel: \(channelName)")
        print("   Opponent: \(matchedUserId)")
        #endif

        self.currentMatchId = matchId
        self.currentChannelName = channelName
        self.matchedUserId = matchedUserId
        self.isMatched = true
        self.isMatching = false

        // Save to Keychain for secure storage
        _ = KeychainManager.save(channelName, forKey: .currentChannelName)
        _ = KeychainManager.save(matchId, forKey: .currentMatchId)
        UserManager.shared.addRecentMatch(matchedUserId)
    }

    // MARK: - Remove from Queue
    func removeFromQueue(userId: String) {
        database.reference().child("matching_queue").child(userId).removeValue { error, _ in
            #if DEBUG
            if let error = error {
                print("❌ Failed to remove from queue: \(error.localizedDescription)")
            } else {
                print("🗑 Removed from queue: \(userId)")
            }
            #endif
        }
    }

    func removeFromQueueIfNeeded(userId: String) {
        removeFromQueue(userId: userId)
    }

    // MARK: - Call Timer Sync
    func updateCallTimer(_ seconds: Int) {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              !matchId.isEmpty else {
            #if DEBUG
            print("❌ Cannot update timer: no matchId")
            #endif
            return
        }

        database.reference()
            .child("matches")
            .child(matchId)
            .child("timeRemaining")
            .setValue(seconds)
    }

    func observeCallTimer(completion: @escaping (Int) -> Void) {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              !matchId.isEmpty else {
            #if DEBUG
            print("❌ Cannot observe timer: no matchId")
            #endif
            return
        }

        cleanupTimerObserver()

        let timerRef = database.reference()
            .child("matches")
            .child(matchId)
            .child("timeRemaining")

        let handle = timerRef.observe(.value) { snapshot in
            if let time = snapshot.value as? Int {
                completion(time)
            }
        }
        timerObserver = ObserverInfo(reference: timerRef, handle: handle)
    }

    // MARK: - Call End Signaling
    func signalCallEnd() {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              !matchId.isEmpty else {
            #if DEBUG
            print("⚠️ signalCallEnd: no matchId available")
            #endif
            return
        }
        signalCallEnd(matchId: matchId)
    }

    func signalCallEnd(matchId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        #if DEBUG
        print("📡 Signaling call end - matchId: \(matchId)")
        #endif

        let matchRef = database.reference().child("matches").child(matchId)

        matchRef.updateChildValues([
            "endedBy/\(currentUserId)": true,
            "endedAt": ServerValue.timestamp(),
            "status": "ended"
        ]) { error, _ in
            #if DEBUG
            if let error = error {
                print("❌ Failed to signal call end: \(error.localizedDescription)")
            } else {
                print("✅ Call end signaled successfully")
            }
            #endif
        }
    }

    // MARK: - Observe Opponent Events
    func observeOpponentPresence(opponentId: String, onDisconnect: @escaping () -> Void) {
        cleanupPresenceObserver()

        let presenceRef = database.reference().child("presence").child(opponentId)

        let handle = presenceRef.observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any],
                  let isOnline = data["online"] as? Bool else { return }

            if !isOnline {
                #if DEBUG
                print("🚨 Opponent disconnected - waiting \(self.config.presenceTimeoutSeconds)s before ending")
                #endif

                // Wait before ending call (grace period for reconnection)
                DispatchQueue.main.asyncAfter(deadline: .now() + self.config.presenceTimeoutSeconds) { [weak self] in
                    // Re-check presence after delay
                    presenceRef.observeSingleEvent(of: .value) { delayedSnapshot in
                        if let delayedData = delayedSnapshot.value as? [String: Any],
                           let stillOnline = delayedData["online"] as? Bool,
                           !stillOnline {
                            #if DEBUG
                            print("🚨 Opponent still offline after grace period - ending call")
                            #endif
                            self?.callEndedByOpponent = true
                            onDisconnect()
                        }
                    }
                }
            }
        }
        presenceObserver = ObserverInfo(reference: presenceRef, handle: handle)
    }

    private var observeCallEndRetryCount = 0
    private let maxObserveCallEndRetries = 10

    func observeCallEnd(completion: @escaping () -> Void) {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              !matchId.isEmpty else {
            observeCallEndRetryCount += 1
            if observeCallEndRetryCount >= maxObserveCallEndRetries {
                #if DEBUG
                print("❌ observeCallEnd: max retries reached, giving up")
                #endif
                observeCallEndRetryCount = 0
                return
            }
            #if DEBUG
            print("⚠️ observeCallEnd: no matchId - retrying in 0.3s (\(observeCallEndRetryCount)/\(maxObserveCallEndRetries))")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.observeCallEnd(completion: completion)
            }
            return
        }
        observeCallEndRetryCount = 0

        let currentUserId = Auth.auth().currentUser?.uid ?? ""

        cleanupCallEndObserver()

        let endRef = database.reference()
            .child("matches")
            .child(matchId)
            .child("endedBy")

        let handle = endRef.observe(.childAdded) { [weak self] snapshot in
            let endedByUserId = snapshot.key

            if endedByUserId != currentUserId {
                #if DEBUG
                print("✅ Opponent ended call")
                #endif
                completion()
                self?.cleanupCallEndObserver()
            }
        }
        callEndObserver = ObserverInfo(reference: endRef, handle: handle)
    }

    func observeCallStatusEnded(completion: @escaping () -> Void) {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              !matchId.isEmpty else { return }

        cleanupStatusEndedObserver()

        let statusRef = database.reference()
            .child("matches")
            .child(matchId)
            .child("status")

        let handle = statusRef.observe(.value) { [weak self] snapshot in
            if let status = snapshot.value as? String, status == "ended" {
                #if DEBUG
                print("🔔 Match status changed to 'ended'")
                #endif
                completion()
                self?.cleanupStatusEndedObserver()
            }
        }
        statusEndedObserver = ObserverInfo(reference: statusRef, handle: handle)
    }

    // MARK: - Camera Status Signaling
    func signalCameraStatus(isOn: Bool) {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              let currentUserId = Auth.auth().currentUser?.uid,
              !matchId.isEmpty else { return }

        database.reference()
            .child("matches")
            .child(matchId)
            .child("cameraStatus")
            .updateChildValues([currentUserId: isOn])
    }

    func observeOpponentCameraStatus(opponentId: String, onUpdate: @escaping (Bool) -> Void) {
        guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
              !matchId.isEmpty else {
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.observeOpponentCameraStatus(opponentId: opponentId, onUpdate: onUpdate)
            }
            return
        }

        cleanupCameraStatusObserver()

        let cameraRef = database.reference()
            .child("matches")
            .child(matchId)
            .child("cameraStatus")
            .child(opponentId)

        let handle = cameraRef.observe(.value) { snapshot in
            let isOn = snapshot.value as? Bool ?? true  // Default to camera on
            onUpdate(isOn)
        }
        cameraStatusObserver = ObserverInfo(reference: cameraRef, handle: handle)
    }

    // MARK: - State Management
    private func updateState(_ newState: MatchingState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.state = newState

            // Update legacy properties for compatibility
            switch newState {
            case .idle:
                self.isMatching = false
                self.isMatched = false
                self.matchedUserId = nil

            case .registering, .waiting:
                self.isMatching = true
                self.isMatched = false

            case .matched(_, _, let opponentId):
                self.isMatching = false
                self.isMatched = true
                self.matchedUserId = opponentId

            case .error:
                self.isMatching = false
                self.isMatched = false
            }
        }
    }

    private func resetMatchState() {
        isMatching = false
        isMatched = false
        matchedUserId = nil
        callEndedByOpponent = false
        currentMatchId = nil
        currentChannelName = nil
    }

    // MARK: - Cleanup
    private func cleanupOnDisconnect() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        removeFromQueue(userId: userId)

        if let matchId = currentMatchId {
            database.reference().child("matches").child(matchId).child("status").setValue("ended")
        }
    }

    private func clearMatchingData() {
        KeychainManager.delete(forKey: .currentChannelName)
        KeychainManager.delete(forKey: .currentMatchId)
    }

    func cleanupCallObservers() {
        cleanupCallEndObserver()
        cleanupTimerObserver()
        cleanupPresenceObserver()
        cleanupStatusEndedObserver()
        cleanupCameraStatusObserver()

        #if DEBUG
        print("🧹 Call observers cleaned up")
        #endif
    }

    private func removeObserver(_ observer: inout ObserverInfo?) {
        if let obs = observer {
            obs.reference.removeObserver(withHandle: obs.handle)
            observer = nil
        }
    }

    private func cleanupMatchingObservers() {
        removeObserver(&statusObserver)
    }

    private func cleanupCallEndObserver() {
        removeObserver(&callEndObserver)
    }

    private func cleanupTimerObserver() {
        removeObserver(&timerObserver)
    }

    private func cleanupPresenceObserver() {
        removeObserver(&presenceObserver)
    }

    private func cleanupStatusEndedObserver() {
        removeObserver(&statusEndedObserver)
    }

    private func cleanupCameraStatusObserver() {
        removeObserver(&cameraStatusObserver)
    }

    private func cleanupConnectionObserver() {
        removeObserver(&connectionObserver)
    }

    private func cleanupAllObservers() {
        cleanupMatchingObservers()
        cleanupCallObservers()
        cleanupConnectionObserver()

        #if DEBUG
        print("🧹 All observers cleaned up")
        #endif
    }
}
