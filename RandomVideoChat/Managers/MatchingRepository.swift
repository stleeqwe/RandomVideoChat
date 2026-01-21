import Foundation
import FirebaseDatabase
import FirebaseAuth

// MARK: - MatchingRepository Protocol
protocol MatchingRepositoryProtocol {
    func registerInQueue(userId: String, gender: String, preferredGender: String, completion: @escaping (Result<Void, Error>) -> Void)
    func removeFromQueue(userId: String, completion: ((Bool) -> Void)?)
    func observeMatchResult(userId: String, onMatch: @escaping (String, String, String) -> Void) -> DatabaseHandle?
    func observeCallTimer(matchId: String, onChange: @escaping (Int) -> Void) -> DatabaseHandle?
    func updateCallTimer(matchId: String, seconds: Int)
    func signalCallEnd(matchId: String, userId: String, completion: ((Bool) -> Void)?)
    func observeCallEnd(matchId: String, currentUserId: String, onEnd: @escaping () -> Void) -> DatabaseHandle?
    func observeCallStatus(matchId: String, onStatusChange: @escaping (String) -> Void) -> DatabaseHandle?
    func observePresence(userId: String, onChange: @escaping (Bool) -> Void) -> DatabaseHandle?
    func updatePresence(userId: String, isOnline: Bool)
    func signalCameraStatus(matchId: String, userId: String, isOn: Bool)
    func observeCameraStatus(matchId: String, userId: String, onChange: @escaping (Bool) -> Void) -> DatabaseHandle?
    func observeConnection(onChange: @escaping (Bool) -> Void) -> DatabaseHandle?
    func removeObserver(handle: DatabaseHandle)
}

// MARK: - MatchingRepository Implementation
final class MatchingRepository: MatchingRepositoryProtocol {
    static let shared = MatchingRepository()

    private let database = Database.database()
    private var observerHandles: [DatabaseHandle] = []

    private init() {}

    // MARK: - Queue Management

    func registerInQueue(userId: String, gender: String, preferredGender: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let queueRef = database.reference().child("matching_queue").child(userId)
        let bucket = getBucket(for: gender)

        let queueData: [String: Any] = [
            "userId": userId,
            "status": "waiting",
            "gender": gender,
            "preferredGender": preferredGender,
            "bucket": bucket,
            "timestamp": ServerValue.timestamp(),
            "clientVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]

        logDebug("Registering in queue - User: \(userId), Gender: \(gender), Preferred: \(preferredGender)", category: .matching)

        queueRef.setValue(queueData) { error, _ in
            if let error = error {
                logError(error, context: "Failed to register in queue", category: .matching)
                completion(.failure(MatchingError.queueRegistrationFailed(underlying: error)))
            } else {
                queueRef.onDisconnectRemoveValue()
                logInfo("Registered in matching queue", category: .matching)
                completion(.success(()))
            }
        }
    }

    func removeFromQueue(userId: String, completion: ((Bool) -> Void)? = nil) {
        database.reference().child("matching_queue").child(userId).removeValue { error, _ in
            if let error = error {
                logError(error, context: "Failed to remove from queue", category: .matching)
                completion?(false)
            } else {
                logDebug("Removed from queue: \(userId)", category: .matching)
                completion?(true)
            }
        }
    }

    private func getBucket(for gender: String) -> String {
        switch gender.lowercased() {
        case "male": return "waiting_male"
        case "female": return "waiting_female"
        default: return "waiting_any"
        }
    }

    // MARK: - Match Observation

    func observeMatchResult(userId: String, onMatch: @escaping (String, String, String) -> Void) -> DatabaseHandle? {
        let userQueueRef = database.reference().child("matching_queue").child(userId)

        let handle = userQueueRef.observe(.value) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let status = data["status"] as? String,
                  status == "matched",
                  let matchId = data["matchId"] as? String,
                  let channelName = data["channelName"] as? String,
                  let matchedWith = data["matchedWith"] as? String,
                  !matchId.isEmpty, !channelName.isEmpty else {
                return
            }

            logInfo("Match found - ID: \(matchId), Channel: \(channelName), Opponent: \(matchedWith)", category: .matching)
            onMatch(matchId, channelName, matchedWith)
        }

        observerHandles.append(handle)
        return handle
    }

    // MARK: - Call Timer

    func observeCallTimer(matchId: String, onChange: @escaping (Int) -> Void) -> DatabaseHandle? {
        guard !matchId.isEmpty else {
            logWarning("Cannot observe timer: empty matchId", category: .matching)
            return nil
        }

        let handle = database.reference()
            .child("matches")
            .child(matchId)
            .child("timeRemaining")
            .observe(.value) { snapshot in
                if let time = snapshot.value as? Int {
                    onChange(time)
                }
            }

        observerHandles.append(handle)
        return handle
    }

    func updateCallTimer(matchId: String, seconds: Int) {
        guard !matchId.isEmpty else { return }

        database.reference()
            .child("matches")
            .child(matchId)
            .child("timeRemaining")
            .setValue(seconds)
    }

    // MARK: - Call End Signaling

    func signalCallEnd(matchId: String, userId: String, completion: ((Bool) -> Void)? = nil) {
        let matchRef = database.reference().child("matches").child(matchId)

        matchRef.updateChildValues([
            "endedBy/\(userId)": true,
            "endedAt": ServerValue.timestamp(),
            "status": "ended"
        ]) { error, _ in
            if let error = error {
                logError(error, context: "Failed to signal call end", category: .matching)
                completion?(false)
            } else {
                logDebug("Call end signaled for match: \(matchId)", category: .matching)
                completion?(true)
            }
        }
    }

    func observeCallEnd(matchId: String, currentUserId: String, onEnd: @escaping () -> Void) -> DatabaseHandle? {
        guard !matchId.isEmpty else { return nil }

        let handle = database.reference()
            .child("matches")
            .child(matchId)
            .child("endedBy")
            .observe(.childAdded) { snapshot in
                let endedByUserId = snapshot.key
                if endedByUserId != currentUserId {
                    logDebug("Opponent ended call", category: .matching)
                    onEnd()
                }
            }

        observerHandles.append(handle)
        return handle
    }

    func observeCallStatus(matchId: String, onStatusChange: @escaping (String) -> Void) -> DatabaseHandle? {
        guard !matchId.isEmpty else { return nil }

        let handle = database.reference()
            .child("matches")
            .child(matchId)
            .child("status")
            .observe(.value) { snapshot in
                if let status = snapshot.value as? String {
                    onStatusChange(status)
                }
            }

        observerHandles.append(handle)
        return handle
    }

    // MARK: - Presence

    func updatePresence(userId: String, isOnline: Bool) {
        let presenceRef = database.reference().child("presence").child(userId)

        presenceRef.setValue([
            "online": isOnline,
            "lastSeen": ServerValue.timestamp()
        ])

        if isOnline {
            presenceRef.onDisconnectUpdateChildValues([
                "online": false,
                "lastSeen": ServerValue.timestamp()
            ])
        }
    }

    func observePresence(userId: String, onChange: @escaping (Bool) -> Void) -> DatabaseHandle? {
        let handle = database.reference()
            .child("presence")
            .child(userId)
            .observe(.value) { snapshot in
                guard let data = snapshot.value as? [String: Any],
                      let isOnline = data["online"] as? Bool else {
                    return
                }
                onChange(isOnline)
            }

        observerHandles.append(handle)
        return handle
    }

    // MARK: - Camera Status

    func signalCameraStatus(matchId: String, userId: String, isOn: Bool) {
        guard !matchId.isEmpty else { return }

        database.reference()
            .child("matches")
            .child(matchId)
            .child("cameraStatus")
            .updateChildValues([userId: isOn])
    }

    func observeCameraStatus(matchId: String, userId: String, onChange: @escaping (Bool) -> Void) -> DatabaseHandle? {
        guard !matchId.isEmpty else { return nil }

        let handle = database.reference()
            .child("matches")
            .child(matchId)
            .child("cameraStatus")
            .child(userId)
            .observe(.value) { snapshot in
                let isOn = snapshot.value as? Bool ?? true
                onChange(isOn)
            }

        observerHandles.append(handle)
        return handle
    }

    // MARK: - Connection Monitoring

    func observeConnection(onChange: @escaping (Bool) -> Void) -> DatabaseHandle? {
        let handle = database.reference()
            .child(".info/connected")
            .observe(.value) { snapshot in
                let connected = snapshot.value as? Bool ?? false
                logDebug("Firebase connection: \(connected ? "connected" : "disconnected")", category: .network)
                onChange(connected)
            }

        observerHandles.append(handle)
        return handle
    }

    // MARK: - Cleanup

    func removeObserver(handle: DatabaseHandle) {
        database.reference().removeObserver(withHandle: handle)
        observerHandles.removeAll { $0 == handle }
    }

    func removeAllObservers() {
        for handle in observerHandles {
            database.reference().removeObserver(withHandle: handle)
        }
        observerHandles.removeAll()
        logDebug("All observers removed", category: .matching)
    }
}
