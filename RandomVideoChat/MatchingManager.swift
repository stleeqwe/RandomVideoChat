import Foundation
import UIKit
import FirebaseDatabase
import FirebaseAuth

class MatchingManager: ObservableObject {
    static let shared = MatchingManager()
    private let database = Database.database()
    
    // MARK: - Database Handles
    private var matchingHandle: DatabaseHandle?
    private var statusHandle: DatabaseHandle?
    private var callEndHandle: DatabaseHandle?
    private var timerHandle: DatabaseHandle?
    private var presenceHandle: DatabaseHandle?
    
    @Published var isMatching = false
    @Published var matchedUserId: String?
    @Published var isMatched = false
    @Published var callEndedByOpponent = false
    
    private init() {
        setupPresenceTracking()
    }
    
    // MARK: - Presence Tracking
    private func setupPresenceTracking() {
        // 앱이 백그라운드로 가거나 종료될 때 처리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // 백그라운드 처리는 VideoCallView에서만 담당하도록 제거
    }
    
    @objc private func appWillTerminate() {
        print("🚨 앱 종료 감지 - 통화 종료 신호 전송")
        signalCallEnd()
        cleanupOnDisconnect()
    }
    
    // 백그라운드 처리는 VideoCallView에서만 담당하도록 이 메서드들 제거
    
    private func cleanupOnDisconnect() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // 매칭 큐에서 제거
        removeFromQueue(userId: currentUserId)
        
        // 매칭 상태 정리
        if let matchId = UserDefaults.standard.string(forKey: "currentMatchId") {
            database.reference().child("matches").child(matchId).child("status").setValue("ended")
        }
    }
    
    // MARK: - Public Methods
    // MARK: - Public Methods 섹션에 추가
    func removeFromQueueIfNeeded(userId: String) {
        // VideoCall이 시작되면 큐에서 제거
        removeFromQueue(userId: userId)
    }
    
    func startMatching() {
        print("📱 MatchingManager: startMatching called")
        let currentUserId = Auth.auth().currentUser?.uid ?? "testUser_\(UUID().uuidString.prefix(8))"

        // 기존에 남아 있는 큐 데이터 정리
        removeFromQueue(userId: currentUserId)

        // 상태 초기화
        isMatching = true
        isMatched = false
        matchedUserId = nil

        // UserDefaults 초기화
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")

        // 매칭 큐에 새로 추가
        let matchingRef = database.reference().child("matching_queue")
        let userRef = matchingRef.child(currentUserId)
        let userData: [String: Any] = [
            "userId": currentUserId,
            "timestamp": ServerValue.timestamp(),
            "status": "waiting",
            "matchId": NSNull(),
            "channelName": NSNull()
        ]

        userRef.setValue(userData) { error, _ in
            if let error = error {
                print("매칭 큐 추가 실패: \(error)")
                self.isMatching = false
                return
            }
            print("매칭 큐에 추가됨")
            
            // onDisconnect 설정 - 연결이 끊어지면 자동으로 큐에서 제거
            userRef.onDisconnectRemoveValue()
            
            self.startObserving()
        }
        
        // presence 추적 설정
        setupPresenceForUser(userId: currentUserId)
    }
    
    private func setupPresenceForUser(userId: String) {
        let presenceRef = database.reference().child("presence").child(userId)
        
        // 온라인 상태 설정
        presenceRef.setValue([
            "online": true,
            "lastSeen": ServerValue.timestamp()
        ])
        
        // 연결 끊김 시 오프라인 상태로 설정
        presenceRef.onDisconnectUpdateChildValues([
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ])
    }

    
    // MatchingManager.swift의 handleMatchSuccess 함수 내부
    func handleMatchSuccess(matchId: String, channelName: String, matchedUserId: String) {
        print("✅ 매칭 성공 처리")
        print("   - 매칭 ID: \(matchId)")
        print("   - 채널명: \(channelName)")
        print("   - 상대방 ID: \(matchedUserId)")
        
        // UserDefaults에 저장 (중요!)
        UserDefaults.standard.set(channelName, forKey: "currentChannelName")
        UserDefaults.standard.set(matchId, forKey: "currentMatchId")
        
        self.matchedUserId = matchedUserId
        self.isMatched = true
    }
    
    func cancelMatching() {
        let currentUserId = Auth.auth().currentUser?.uid ?? "testUser_\(UUID().uuidString.prefix(8))"
        
        print("🛑 매칭 취소")
        
        isMatching = false
        isMatched = false
        matchedUserId = nil
        callEndedByOpponent = false
        
        // 리스너 제거
        if let handle = matchingHandle {
            database.reference().child("matching_queue").removeObserver(withHandle: handle)
            matchingHandle = nil
        }
        
        if let handle = statusHandle {
            database.reference().child("matching_queue").child(currentUserId).removeObserver(withHandle: handle)
            statusHandle = nil
        }
        
        // 큐에서 제거
        removeFromQueue(userId: currentUserId)
        
        // UserDefaults 정리
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
    }
    
    // MARK: - Private Methods
    
    private func startObserving() {
        let currentUserId = Auth.auth().currentUser?.uid ?? "testUser_\(UUID().uuidString.prefix(8))"
        
        // 1. 내 상태 변화 관찰 (User B를 위해)
        observeMyStatus(userId: currentUserId)
        
        // 2. 다른 대기자 찾기 (User A 역할)
        findWaitingUsers(currentUserId: currentUserId)
    }
    
    private func observeMyStatus(userId: String) {
        let myRef = database.reference().child("matching_queue").child(userId)
        
        statusHandle = myRef.observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any],
                  let status = data["status"] as? String else { return }
            
            print("📊 내 상태: \(status)")
            
            // 이미 매칭된 상태면 무시
            if self.isMatched {
                return
            }
            
            if status == "matched",
               let matchId = data["matchId"] as? String,
               let channelName = data["channelName"] as? String,
               matchId != "null",
               channelName != "null" {
                
                print("🎯 매칭 완료 감지!")
                print("📺 채널: \(channelName)")
                
                // 상대방 ID 찾기
                self.findMatchedUser(matchId: matchId, currentUserId: userId)
                
                // 매칭 정보 저장
                UserDefaults.standard.set(channelName, forKey: "currentChannelName")
                UserDefaults.standard.set(matchId, forKey: "currentMatchId")
                
                // 상태 업데이트
                self.isMatched = true
                self.isMatching = false
                
                // 🆕 수정: 큐에서 제거를 더 늦춤 (15초) 또는 제거하지 않음
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    self.removeFromQueue(userId: userId)
                }
            }
        }
    }
    
    private func findMatchedUser(matchId: String, currentUserId: String) {
        database.reference().child("matches").child(matchId).observeSingleEvent(of: .value) { [weak self] snapshot in
            if let data = snapshot.value as? [String: Any],
               let user1 = data["user1"] as? String,
               let user2 = data["user2"] as? String {
                
                self?.matchedUserId = (user1 == currentUserId) ? user2 : user1
                print("📺 매칭된 상대: \(self?.matchedUserId ?? "")")
            }
        }
    }
    
    private func findWaitingUsers(currentUserId: String) {
        let matchingRef = database.reference().child("matching_queue")
        matchingHandle = matchingRef.observe(.value) { [weak self] snapshot in
            guard let self = self, self.isMatching, !self.isMatched else { return }

            var waitingUsers: [String] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let data = childSnapshot.value as? [String: Any],
                   let userId = data["userId"] as? String,
                   let status = data["status"] as? String,
                   status == "waiting" {
                    waitingUsers.append(userId)
                }
            }

            // 자신만 대기열에 있는 경우 매칭 시도 안함
            if waitingUsers.count <= 1 { return }

            // 다른 대기자를 찾아 매칭 시도
            for userId in waitingUsers {
                if userId != currentUserId {
                    if UserManager.shared.canMatchWith(userId) {
                        self.tryMatch(with: userId, currentUserId: currentUserId)
                        break
                    }
                }
            }
        }
    }

    
    private func tryMatch(with otherUserId: String, currentUserId: String) {
        print("🔒 매칭 잠금 시도: \(otherUserId)")
        
        // 🆕 추가: ID 비교로 한 쪽만 매칭 생성 (작은 ID가 생성)
        if currentUserId > otherUserId {
            print("⏸ 상대방이 매칭을 생성하도록 대기")
            return
        }
        
        // 상대방 상태를 "matching"으로 변경 (원자적 연산)
        let otherUserRef = database.reference().child("matching_queue").child(otherUserId)
        
        otherUserRef.runTransactionBlock { currentData in
            guard let data = currentData.value as? [String: Any],
                  let status = data["status"] as? String,
                  status == "waiting" else {
                return TransactionResult.abort()
            }
            
            // 상태를 matching으로 변경
            var newData = data
            newData["status"] = "matching"
            currentData.value = newData
            
            return TransactionResult.success(withValue: currentData)
        } andCompletionBlock: { [weak self] error, committed, _ in
            if committed && error == nil {
                print("✅ 매칭 잠금 성공")
                self?.proceedWithMatch(otherUserId: otherUserId, currentUserId: currentUserId)
            } else {
                print("❌ 매칭 잠금 실패 - 다른 사용자 찾기")
            }
        }
    }
    
    private func proceedWithMatch(otherUserId: String, currentUserId: String) {
        let matchesRef = database.reference().child("matches")
        let matchId = UUID().uuidString
        
        // 짧은 채널 이름 생성
        let timestamp = Int(Date().timeIntervalSince1970)
        let channelName = "ch_\(timestamp)_\(Int.random(in: 1000...9999))"
        
        let matchData: [String: Any] = [
            "user1": currentUserId,
            "user2": otherUserId,
            "channelName": channelName,
            "timestamp": ServerValue.timestamp(),
            "status": "active"
        ]
        
        matchesRef.child(matchId).setValue(matchData) { [weak self] error, _ in
            if let error = error {
                print("매칭 생성 실패: \(error)")
                // 실패 시 상대방 상태 복구
                self?.resetUserStatus(userId: otherUserId)
                return
            }
            
            print("✅ 매칭 생성 성공!")
            print("📺 생성된 채널: \(channelName)")
            
            // 양쪽 사용자 상태 업데이트
            self?.updateBothUsers(
                user1: currentUserId,
                user2: otherUserId,
                matchId: matchId,
                channelName: channelName
            )
        }
    }
    
    private func updateBothUsers(user1: String, user2: String, matchId: String, channelName: String) {
        let updates: [String: Any] = [
            "matching_queue/\(user1)/status": "matched",
            "matching_queue/\(user1)/matchId": matchId,
            "matching_queue/\(user1)/channelName": channelName,
            "matching_queue/\(user2)/status": "matched",
            "matching_queue/\(user2)/matchId": matchId,
            "matching_queue/\(user2)/channelName": channelName
        ]
        
        database.reference().updateChildValues(updates) { error, _ in
            if error == nil {
                print("✅ 양쪽 사용자 상태 업데이트 완료")
                // 중복 처리 제거 - observeMyStatus에서 처리됨
            } else {
                print("❌ 상태 업데이트 실패: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    private func resetUserStatus(userId: String) {
        database.reference()
            .child("matching_queue")
            .child(userId)
            .child("status")
            .setValue("waiting")
    }
    
    private func removeFromQueue(userId: String) {
        let userRef = database.reference().child("matching_queue").child(userId)
        userRef.removeValue { error, _ in
            if error == nil {
                print("🗑 큐에서 제거 완료: \(userId)")
            }
        }
    }
    
    private func isBlockedUser(_ userId: String) -> Bool {
        if let blockedUsers = UserManager.shared.currentUser?.blockedUsers {
            return blockedUsers.contains(userId)
        }
        return false
    }
    
    // MARK: - 타이머 동기화
    func updateCallTimer(_ seconds: Int) {
            guard let matchId = UserDefaults.standard.string(forKey: "currentMatchId") else {
                print("❌ matchId가 없어서 타이머를 업데이트할 수 없음")
                return
            }
            
            // Firebase에 타이머 업데이트
            database.reference()
                .child("matches")
                .child(matchId)
                .child("timeRemaining")
                .setValue(seconds) { error, _ in
                    if let error = error {
                        print("❌ 타이머 업데이트 실패: \(error)")
                    } else {
                        print("⏱ 타이머 업데이트 성공: \(seconds)초")
                    }
                }
        }

    func observeCallTimer(completion: @escaping (Int) -> Void) {
            guard let matchId = UserDefaults.standard.string(forKey: "currentMatchId") else {
                print("❌ matchId가 없어서 타이머를 관찰할 수 없음")
                return
            }
            
            // 기존 옵저버 제거
            if let handle = timerHandle {
                database.reference().removeObserver(withHandle: handle)
            }
            
            timerHandle = database.reference()
                .child("matches")
                .child(matchId)
                .child("timeRemaining")
                .observe(.value) { snapshot in
                    if let time = snapshot.value as? Int {
                        print("⏱ 타이머 동기화 수신: \(time)초")
                        completion(time)
                    }
                }
            
            print("👀 타이머 옵저버 설정 완료 - matchId: \(matchId)")
        }
    
    func signalCallEnd() {
            guard let matchId = UserDefaults.standard.string(forKey: "currentMatchId") else {
                return
            }
            
            // 현재 사용자 ID 가져오기
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            
            // Firebase에 통화 종료 신호 - 사용자별로 따로 저장
            let updates: [String: Any] = [
                "matches/\(matchId)/endedBy/\(currentUserId)": true,
                "matches/\(matchId)/endedAt": ServerValue.timestamp()
            ]
            
            database.reference().updateChildValues(updates) { error, _ in
                // Silent completion
            }
        }
    
    func observeOpponentPresence(opponentId: String, onDisconnect: @escaping () -> Void) {
        // 기존 리스너 정리
        cleanupPresenceObserver()
        
        let presenceRef = database.reference().child("presence").child(opponentId)
        
        presenceHandle = presenceRef.observe(.value) { [weak self] snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let isOnline = data["online"] as? Bool else { return }
            
            if !isOnline {
                print("🚨 상대방 연결 끊김 감지 - 6초 지연 후 처리")
                // 6초 지연을 두어 상대방이 백그라운드에서 복귀할 시간을 줌
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    // 6초 후에도 여전히 offline이면 통화 종료
                    presenceRef.observeSingleEvent(of: .value) { delayedSnapshot in
                        if let delayedData = delayedSnapshot.value as? [String: Any],
                           let delayedIsOnline = delayedData["online"] as? Bool,
                           !delayedIsOnline {
                            print("🚨 6초 후에도 상대방 연결 끊김 확인 - 통화 종료")
                            self?.callEndedByOpponent = true
                            onDisconnect()
                        } else {
                            print("✅ 상대방이 다시 연결됨 - 통화 유지")
                        }
                    }
                }
            }
        }
    }
    
    private func cleanupPresenceObserver() {
        if let handle = presenceHandle {
            database.reference().removeObserver(withHandle: handle)
            presenceHandle = nil
        }
    }
    
    // MARK: - 통화 종료 관찰
    func observeCallEnd(completion: @escaping () -> Void) {
        guard let matchId = UserDefaults.standard.string(forKey: "currentMatchId") else {
            print("❌ matchId가 없어서 통화 종료를 관찰할 수 없음")
            return
        }
        
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        
        // 기존 옵저버 제거
        if let handle = callEndHandle {
            database.reference().removeObserver(withHandle: handle)
        }
        
        // 상대방의 종료 신호 관찰
        callEndHandle = database.reference()
            .child("matches")
            .child(matchId)
            .child("endedBy")
            .observe(.childAdded) { snapshot in
                let endedByUserId = snapshot.key
                
                // 자신이 아닌 다른 사용자가 종료한 경우
                if endedByUserId != currentUserId {
                    completion()
                    
                    // 한 번 실행 후 옵저버 제거
                    if let handle = self.callEndHandle {
                        self.database.reference().removeObserver(withHandle: handle)
                        self.callEndHandle = nil
                    }
                }
            }
        
        print("👀 통화 종료 옵저버 설정 완료 - matchId: \(matchId)")
    }
    
    // MARK: - Observer Cleanup
    func cleanupCallObservers() {
        cleanupCallEndObserver()
        cleanupTimerObserver()
        cleanupPresenceObserver()
        
        print("🧹 통화 관련 옵저버 정리 완료")
    }
    
    private func cleanupCallEndObserver() {
        if let handle = callEndHandle {
            database.reference().removeObserver(withHandle: handle)
            callEndHandle = nil
        }
    }
    
    private func cleanupTimerObserver() {
        if let handle = timerHandle {
            database.reference().removeObserver(withHandle: handle)
            timerHandle = nil
        }
    }
}
