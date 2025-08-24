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
    private var statusEndedHandle: DatabaseHandle?
    
    @Published var isMatching = false
    @Published var matchedUserId: String?
    @Published var isMatched = false
    @Published var callEndedByOpponent = false
    
    private init() {
        setupPresenceTracking()
    }
    
    deinit {
        cleanupAllObservers()
        NotificationCenter.default.removeObserver(self)
        print("🧹 MatchingManager 메모리 정리 완료")
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
        
        // 중복 호출 방지
        guard !isMatching else {
            print("⚠️ 이미 매칭 중 - 중복 호출 무시")
            return
        }
        
        // 연령 확인 검증 (Apple Sign In 사용자의 경우)
        if let currentUser = UserManager.shared.currentUser {
            if currentUser.authProvider == "apple.com" && !currentUser.ageVerified {
                print("❌ 연령 확인이 필요한 사용자 - 매칭 중단")
                isMatching = false
                return
            }
            
            if let age = currentUser.age, age < 18 {
                print("❌ 연령 미달 사용자 - 매칭 중단")
                isMatching = false
                return
            }
        }
        
        let currentUserId = Auth.auth().currentUser?.uid ?? "testUser_\(UUID().uuidString.prefix(8))"

        // 상태 초기화
        isMatching = true
        isMatched = false
        matchedUserId = nil

        // UserDefaults 초기화
        UserDefaults.standard.removeObject(forKey: "currentChannelName")
        UserDefaults.standard.removeObject(forKey: "currentMatchId")
        
        // 사용자 정보가 없으면 로딩 시도
        if UserManager.shared.currentUser == nil {
            print("⚠️ 사용자 정보 로딩 중 - 곧 재시도")
            UserManager.shared.loadCurrentUserIfNeeded()
        }

        // 매칭 큐에 데이터 업데이트 (삭제 없이 덮어쓰기)
        let matchingRef = database.reference().child("matching_queue")
        let userRef = matchingRef.child(currentUserId)
        
        // 현재 사용자의 성별 정보 가져오기
        let currentUser = UserManager.shared.currentUser
        let userGender = currentUser?.gender?.rawValue ?? "any"
        let preferredGender = currentUser?.preferredGender?.rawValue ?? "any"
        
        // 버킷과 랜덤 시드 생성 (개선된 매칭 알고리즘)
        let bucket = "waiting_\(userGender)"
        let randomSeed = Int.random(in: 0..<1_000_000)
        
        let myPrefRate = UserManager.shared.currentUser?.preferenceRate ?? 50.0
        let lower = max(0, Int(myPrefRate / 10) * 10)
        let upper = min(100, lower + 10)
        let prefRange = "\(lower)-\(upper)"

        let userData: [String: Any] = [
            "userId": currentUserId,
            "timestamp": ServerValue.timestamp(),
            "status": "waiting",
            "matchId": NSNull(),
            "channelName": NSNull(),
            "gender": userGender,
            "preferredGender": preferredGender,
            "bucket": bucket,
            "randomSeed": randomSeed,
            "preferenceRate": myPrefRate,
            "preferenceRange": prefRange
        ]

        // 기존 데이터가 있어도 덮어쓰기만 함 (노드 삭제 없음)
        userRef.updateChildValues(userData) { error, _ in
            if let error = error {
                print("매칭 큐 업데이트 실패: \(error)")
                self.isMatching = false
                return
            }
            print("매칭 큐에 업데이트됨 (삭제 없이 덮어쓰기)")
            
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
        
        // 세션 기록에 추가 (반복 매칭 방지)
        UserManager.shared.addRecentMatch(matchedUserId)
        print("📝 세션 매칭 기록에 추가: \(matchedUserId)")
        
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
        
        // 1. 내 상태 변화 관찰 (매칭 성공 감지용)
        observeMyStatus(userId: currentUserId)
        // 2. 클라이언트 폴링 제거: Cloud Function이 매칭을 수행하고
        //    상태를 업데이트하므로 여기서 주기적 검색을 수행하지 않습니다.
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
    
    // MARK: - Improved Matching Algorithm
    private func candidateBuckets(for myPref: String) -> [String] {
        // 내 선호 성별에 맞는 상대 버킷
        if myPref == "" || myPref == "any" {
            return ["waiting_male", "waiting_female"]
        } else {
            return ["waiting_\(myPref)"]
        }
    }
    
    private func findWaitingUsers(currentUserId: String) {
        // currentUser가 nil이어도 기본값으로 매칭 진행
        let myGender = UserManager.shared.currentUser?.gender?.rawValue ?? "any"
        let myPref = UserManager.shared.currentUser?.preferredGender?.rawValue ?? "any"
        
        print("🔄 매칭 시도 - 내 성별: \(myGender), 선호: \(myPref), currentUser: \(UserManager.shared.currentUser != nil ? "로드됨" : "nil")")
        
        let buckets = candidateBuckets(for: myPref)
        let matchingRef = database.reference().child("matching_queue")
        
        let pivot = Int.random(in: 0..<1_000_000) // 랜덤 피벗
        
        func tryBucket(_ index: Int) {
            // 매칭 상태 확인 - 취소된 경우 재시도 중단
            guard self.isMatching && !self.isMatched else {
                print("🚫 매칭 취소됨 - 재시도 중단")
                return
            }
            
            guard index < buckets.count else {
                print("⚠️ 후보 없음. 잠시 후 재시도.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    // 재시도 전에도 매칭 상태 재확인
                    guard self.isMatching && !self.isMatched else {
                        print("🚫 재시도 취소됨 - 매칭 상태 변경")
                        return
                    }
                    self.findWaitingUsers(currentUserId: currentUserId)
                }
                return
            }
            
            let bucket = buckets[index]
            
            print("🔍 버킷 검색 시작: \(bucket) (내 성별: \(myGender), 내 선호: \(myPref))")
            
            // 올바른 버킷 쿼리 (Firebase 인덱스가 있으면 최적화됨)
            matchingRef.queryOrdered(byChild: "bucket")
                .queryEqual(toValue: bucket)
                .observeSingleEvent(of: .value) { snapshot in
                    print("📦 버킷 '\(bucket)' 응답: \(snapshot.childrenCount)개 항목")
                    var candidates: [[String: Any]] = []
                    
                    for child in snapshot.children {
                        guard let snap = child as? DataSnapshot,
                              let dict = snap.value as? [String: Any] else { 
                            print("❌ 스냅샷 파싱 실패")
                            continue 
                        }
                        
                        let status = dict["status"] as? String ?? "waiting"
                        let userId = dict["userId"] as? String ?? snap.key
                        let userBucket = dict["bucket"] as? String ?? "none"
                        
                        print("👤 후보 분석: \(userId)")
                        print("   - 상태: \(status)")
                        print("   - 버킷: \(userBucket)")
                        
                        // 스테일 데이터 정리: 존재하지 않는 노드 감지
                        if !snap.exists() {
                            print("   🧹 스테일 데이터 감지 - 정리 중...")
                            snap.ref.removeValue()
                            continue
                        }
                        
                        if status != "waiting" {
                            print("   ❌ 대기 상태 아님")
                            continue
                        }
                        if userId == currentUserId {
                            print("   ❌ 자기 자신")
                            continue
                        }
                        
                        // 2) 양방향 선호 필터링
                        let candidatePref = (dict["preferredGender"] as? String) ?? "any"
                        let candidateGender = (dict["gender"] as? String) ?? "any"
                        
                        print("   - 후보 성별: \(candidateGender), 후보 선호: \(candidatePref)")
                        
                        let myPrefOK = (myPref == "any" || candidateGender == myPref)
                        let hisPrefOK = (candidatePref == "any" || myGender == candidatePref)
                        
                        print("   - 내 선호 충족: \(myPrefOK), 상대 선호 충족: \(hisPrefOK)")
                        
                        if !myPrefOK || !hisPrefOK { 
                            print("   ❌ 성별 선호 불일치")
                            continue 
                        }
                        
                        // 차단/최근매칭 제외
                        let canMatch = UserManager.shared.canMatchWith(userId)
                        print("   - canMatchWith 결과: \(canMatch)")
                        if !canMatch { 
                            print("   ❌ 차단/최근매칭")
                            continue 
                        }
                        
                        print("   ✅ 후보로 선정 - candidates에 추가 중...")
                        var candidateDict = dict
                        candidateDict["userId"] = userId
                        candidates.append(candidateDict)
                        print("   ✅ candidates 추가 완료, 현재 개수: \(candidates.count)")
                    }
                    
                    print("🎯 후보 집계 완료: \(candidates.count)개")
                    if candidates.isEmpty {
                        print("❌ 후보 배열이 비어있음 - 다음 버킷 시도")
                        tryBucket(index + 1)
                        return
                    } else {
                        print("✅ 후보 \(candidates.count)개로 매칭 시도")
                    }

                    // 3) 선호도 범위 기반 확장 로직: 동일 범위 → 인접 범위 → 전체
                    let myRate = UserManager.shared.currentUser?.preferenceRate ?? 50.0
                    let myLower = max(0, min(100, (Int(myRate) / 10) * 10))
                    func rangeString(_ lower: Int) -> String { "\(lower)-\(min(100, lower + 10))" }
                    let myRange = rangeString(myLower)
                    let lowNeighbor = myLower - 10
                    let highNeighbor = myLower + 10

                    // 그룹 분할
                    let sameRange = candidates.filter { ($0["preferenceRange"] as? String) == myRange }
                    let adjacentRanges: [[String: Any]] = {
                        var arr: [[String: Any]] = []
                        if lowNeighbor >= 0 {
                            let r = rangeString(lowNeighbor)
                            arr.append(contentsOf: candidates.filter { ($0["preferenceRange"] as? String) == r })
                        }
                        if highNeighbor <= 100 {
                            let r = rangeString(highNeighbor)
                            arr.append(contentsOf: candidates.filter { ($0["preferenceRange"] as? String) == r })
                        }
                        return arr
                    }()
                    var others = candidates.filter {
                        let r = ($0["preferenceRange"] as? String) ?? ""
                        return r != myRange && r != rangeString(lowNeighbor) && r != rangeString(highNeighbor)
                    }

                    // 정렬 함수: 선호도 차이 → 랜덤성 보조
                    func sortByPreferenceThenRandom(_ list: inout [[String: Any]]) {
                        list.sort {
                            let ar = $0["preferenceRate"] as? Double ?? 50.0
                            let br = $1["preferenceRate"] as? Double ?? 50.0
                            let ad = abs(ar - myRate)
                            let bd = abs(br - myRate)
                            if ad == bd {
                                let a = $0["randomSeed"] as? Int ?? 0
                                let b = $1["randomSeed"] as? Int ?? 0
                                let da = min(abs(a - pivot), 1_000_000 - abs(a - pivot))
                                let db = min(abs(b - pivot), 1_000_000 - abs(b - pivot))
                                return da < db
                            }
                            return ad < bd
                        }
                    }

                    let sameCount = sameRange.count
                    let adjCount = adjacentRanges.count
                    let othCount = others.count
                    print("🧭 선호도 티어 분포 - same: \(sameCount), adjacent: \(adjCount), global: \(othCount)")

                    var prioritized: [[String: Any]] = []
                    var firstTierUsed = "unknown"
                    if !sameRange.isEmpty {
                        var s = sameRange
                        sortByPreferenceThenRandom(&s)
                        s = s.map { var d = $0; d["prefTier"] = "same"; return d }
                        prioritized.append(contentsOf: s)
                        firstTierUsed = "same"
                    }
                    if prioritized.isEmpty && !adjacentRanges.isEmpty {
                        var a = adjacentRanges
                        sortByPreferenceThenRandom(&a)
                        a = a.map { var d = $0; d["prefTier"] = "adjacent"; return d }
                        prioritized.append(contentsOf: a)
                        firstTierUsed = "adjacent"
                    }
                    if prioritized.isEmpty {
                        sortByPreferenceThenRandom(&others)
                        others = others.map { var d = $0; d["prefTier"] = "global"; return d }
                        prioritized.append(contentsOf: others)
                        firstTierUsed = "global"
                    }

                    print("🎚 우선 사용 티어: \(firstTierUsed)")

                    self.tryLockAndFinalize(currentUserId: currentUserId,
                                            myGender: myGender,
                                            candidateList: prioritized,
                                            index: 0,
                                            onExhausted: {
                                                tryBucket(index + 1)
                                            })
                }
        }
        
        tryBucket(0)
    }
    
    // MARK: - Atomic Lock System
    private func tryLockAndFinalize(currentUserId: String,
                                    myGender: String,
                                    candidateList: [[String: Any]],
                                    index: Int,
                                    onExhausted: @escaping () -> Void) {
        
        print("🔒 tryLockAndFinalize 호출됨")
        print("   - candidateList.count: \(candidateList.count)")
        print("   - index: \(index)")
        
        guard index < candidateList.count else {
            print("❌ 인덱스 범위 벗어남 - onExhausted 호출")
            onExhausted(); return
        }
        
        let candidate = candidateList[index]
        let opponentId = candidate["userId"] as? String ?? ""
        let prefTier = candidate["prefTier"] as? String ?? "unknown"
        
        print("🎯 매칭 시도 대상: \(opponentId) [tier=\(prefTier)]")
        
        // 매칭 ID와 채널명 미리 생성
        let matchId = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let channelName = "ch_\(timestamp)_\(Int.random(in: 1000...9999))"
        
        print("🆔 매칭 ID 생성: \(matchId)")
        print("📺 채널명 생성: \(channelName)")
        
        let candidateRef = database.reference().child("matching_queue").child(opponentId)
        
        print("🔍 트랜잭션 전 상대방 데이터 존재 확인...")
        // 트랜잭션 전에 상대방 데이터 존재 여부 먼저 확인
        candidateRef.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                print("🚫 상대방 노드 없음 - 큐에서 사라짐. 다음 후보로 넘어갑니다.")
                self.tryLockAndFinalize(currentUserId: currentUserId,
                                        myGender: myGender,
                                        candidateList: candidateList,
                                        index: index + 1,
                                        onExhausted: onExhausted)
                return
            }
            
            guard let dict = snapshot.value as? [String: Any] else {
                print("🚫 상대방 데이터 형식 오류. 다음 후보로 넘어갑니다.")
                self.tryLockAndFinalize(currentUserId: currentUserId,
                                        myGender: myGender,
                                        candidateList: candidateList,
                                        index: index + 1,
                                        onExhausted: onExhausted)
                return
            }
            
            let status = dict["status"] as? String ?? "waiting"
            print("🔍 상대방 현재 상태 확인: \(status)")
            if status != "waiting" {
                print("🚫 상대방이 이미 대기 상태가 아님(\(status)). 다음 후보로 넘어갑니다.")
                self.tryLockAndFinalize(currentUserId: currentUserId,
                                        myGender: myGender,
                                        candidateList: candidateList,
                                        index: index + 1,
                                        onExhausted: onExhausted)
                return
            }
            
            print("✅ 상대방 데이터 유효성 확인 완료 - 타임스탬프 기반 매칭 시작")
            
            // 트랜잭션 대신 타임스탬프 기반 경쟁 시스템 사용
            let myTimestamp = Int(Date().timeIntervalSince1970 * 1000) // 밀리초 단위
            let lockKey = "matchingLock_\(min(currentUserId, opponentId))_\(max(currentUserId, opponentId))"
            
            print("🏁 타임스탬프 기반 락 시도: \(myTimestamp)")
            
            // 1) 내 타임스탬프로 락 시도
            let lockRef = self.database.reference().child("matching_locks").child(lockKey)
            let lockData: [String: Any] = [
                "timestamp": myTimestamp,
                "initiator": currentUserId,
                "opponent": opponentId,
                "matchId": matchId,
                "status": "locking"
            ]
            
            lockRef.setValue(lockData) { error, _ in
                if let error = error {
                    print("❌ 락 설정 실패: \(error)")
                    self.tryLockAndFinalize(currentUserId: currentUserId,
                                            myGender: myGender,
                                            candidateList: candidateList,
                                            index: index + 1,
                                            onExhausted: onExhausted)
                    return
                }
                
                // 2) 0.2초 후 락 상태 확인 (다른 클라이언트의 경쟁 대기)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    lockRef.observeSingleEvent(of: .value) { lockSnapshot in
                        guard let lockResult = lockSnapshot.value as? [String: Any],
                              let winnerTimestamp = lockResult["timestamp"] as? Int,
                              let winner = lockResult["initiator"] as? String else {
                            print("❌ 락 결과 읽기 실패")
                            self.tryLockAndFinalize(currentUserId: currentUserId,
                                                    myGender: myGender,
                                                    candidateList: candidateList,
                                                    index: index + 1,
                                                    onExhausted: onExhausted)
                            return
                        }
                        
                        if winner == currentUserId && winnerTimestamp == myTimestamp {
                            print("✅ 락 획득 성공 - 매칭 진행")
                            self.proceedWithMatching(currentUserId: currentUserId,
                                                     opponentId: opponentId,
                                                     matchId: matchId,
                                                     channelName: channelName,
                                                     prefTier: prefTier,
                                                     lockRef: lockRef)
                        } else {
                            print("❌ 락 획득 실패 - 다른 클라이언트가 우선 (winner: \(winner), timestamp: \(winnerTimestamp) vs \(myTimestamp))")
                            self.tryLockAndFinalize(currentUserId: currentUserId,
                                                    myGender: myGender,
                                                    candidateList: candidateList,
                                                    index: index + 1,
                                                    onExhausted: onExhausted)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Timestamp-based Matching System
    private func proceedWithMatching(currentUserId: String,
                                     opponentId: String,
                                     matchId: String,
                                     channelName: String,
                                     prefTier: String?,
                                     lockRef: DatabaseReference) {
        
        print("🚀 매칭 확정 진행 시작 [tier=\(prefTier ?? "unknown")] opponent=\(opponentId)")
        
        // 1) 매칭 확정(멀티 로케이션 업데이트)
        let updates: [String: Any] = [
            "matches/\(matchId)/status": "active",
            "matches/\(matchId)/user1": currentUserId,
            "matches/\(matchId)/user2": opponentId,
            "matches/\(matchId)/channelName": channelName,
            "matches/\(matchId)/timestamp": ServerValue.timestamp(),
            "matching_queue/\(currentUserId)/status": "matched",
            "matching_queue/\(currentUserId)/matchId": matchId,
            "matching_queue/\(currentUserId)/channelName": channelName,
            "matching_queue/\(opponentId)/status": "matched",
            "matching_queue/\(opponentId)/matchId": matchId,
            "matching_queue/\(opponentId)/channelName": channelName
        ]
        
        database.reference().updateChildValues(updates) { error, _ in
            // 락 정리
            lockRef.removeValue()
            
            if let error = error {
                print("❌ 매칭 확정 실패: \(error)")
                // 롤백 - 큐 상태를 waiting으로 되돌림
                let rollbackUpdates: [String: Any] = [
                    "matching_queue/\(currentUserId)/status": "waiting",
                    "matching_queue/\(currentUserId)/matchId": NSNull(),
                    "matching_queue/\(currentUserId)/channelName": NSNull(),
                    "matching_queue/\(opponentId)/status": "waiting",
                    "matching_queue/\(opponentId)/matchId": NSNull(),
                    "matching_queue/\(opponentId)/channelName": NSNull()
                ]
                self.database.reference().updateChildValues(rollbackUpdates)
            } else {
                print("✅ 매칭 확정 완료: \(matchId)")
                // 기존에 구현된 handleMatchSuccess(...) 호출
                self.handleMatchSuccess(matchId: matchId,
                                        channelName: channelName,
                                        matchedUserId: opponentId)
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
        // UserDefaults에서 matchId를 가져와서 오버로드된 함수 호출
        guard let matchId = UserDefaults.standard.string(forKey: "currentMatchId") else {
            print("❌ signalCallEnd: matchId가 없음 - UserDefaults에서 조회 실패")
            return
        }
        signalCallEnd(matchId: matchId)
    }
    
    func signalCallEnd(matchId: String) {
        // 현재 사용자 ID 가져오기
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        print("📡 통화 종료 신호 전송 - matchId: \(matchId), userId: \(currentUserId)")
        
        // Firebase에 통화 종료 신호 - 사용자별로 따로 저장
        let updates: [String: Any] = [
            "matches/\(matchId)/endedBy/\(currentUserId)": true,
            "matches/\(matchId)/endedAt": ServerValue.timestamp(),
            "matches/\(matchId)/status": "ended"
        ]
        
        database.reference().updateChildValues(updates) { error, _ in
            if let error = error {
                print("❌ 통화 종료 신호 전송 실패: \(error)")
            } else {
                print("✅ 통화 종료 신호 전송 성공")
            }
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
                print("🚨 상대방 연결 끊김 감지 - 15초 지연 후 처리")
                // 15초 지연을 두어 상대방이 백그라운드에서 복귀할 시간을 줌
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                    // 15초 후에도 여전히 offline이면 통화 종료
                    presenceRef.observeSingleEvent(of: .value) { delayedSnapshot in
                        if let delayedData = delayedSnapshot.value as? [String: Any],
                           let delayedIsOnline = delayedData["online"] as? Bool,
                           !delayedIsOnline {
                            print("🚨 15초 후에도 상대방 연결 끊김 확인 - 통화 종료")
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
            print("❌ observeCallEnd: matchId가 없어서 통화 종료를 관찰할 수 없음")
            return
        }
        
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        print("👀 통화 종료 관찰 시작 - matchId: \(matchId), currentUserId: \(currentUserId)")
        
        // 기존 옵저버 제거
        if let handle = callEndHandle {
            database.reference().removeObserver(withHandle: handle)
            callEndHandle = nil
        }
        
        // 상대방의 종료 신호 관찰 - endedBy 노드 변화 감지
        callEndHandle = database.reference()
            .child("matches")
            .child(matchId)
            .child("endedBy")
            .observe(.childAdded) { [weak self] snapshot in
                let endedByUserId = snapshot.key
                print("🔔 통화 종료 신호 감지 - endedBy: \(endedByUserId), currentUser: \(currentUserId)")
                
                // 자신이 아닌 다른 사용자가 종료한 경우
                if endedByUserId != currentUserId {
                    print("✅ 상대방 종료 확인 - 통화 종료 처리")
                    completion()
                    
                    // 한 번 실행 후 옵저버 제거
                    if let handle = self?.callEndHandle {
                        self?.database.reference().removeObserver(withHandle: handle)
                        self?.callEndHandle = nil
                        print("🧹 통화 종료 옵저버 제거 완료")
                    }
                } else {
                    print("ℹ️ 내가 종료한 신호이므로 무시")
                }
            }
        
        print("✅ 통화 종료 옵저버 설정 완료 - matchId: \(matchId)")
    }
    
    func observeCallStatusEnded(completion: @escaping () -> Void) {
        guard let matchId = UserDefaults.standard.string(forKey: "currentMatchId") else {
            print("❌ observeCallStatusEnded: matchId가 없어서 상태 변경을 관찰할 수 없음")
            return
        }
        
        // 기존 핸들 제거
        if let handle = statusEndedHandle {
            database.reference().removeObserver(withHandle: handle)
            statusEndedHandle = nil
        }
        
        statusEndedHandle = database.reference()
            .child("matches")
            .child(matchId)
            .child("status")
            .observe(.value) { [weak self] snapshot in
                if let status = snapshot.value as? String, status == "ended" {
                    print("🔔 통화 상태 'ended' 감지")
                    completion()
                    
                    // 한 번 실행 후 옵저버 제거
                    if let handle = self?.statusEndedHandle {
                        self?.database.reference().removeObserver(withHandle: handle)
                        self?.statusEndedHandle = nil
                    }
                }
            }
        print("👀 통화 상태 종료 옵저버 설정 완료 - matchId: \(matchId)")
    }
    
    // MARK: - Observer Cleanup
    func cleanupCallObservers() {
        cleanupCallEndObserver()
        cleanupTimerObserver()
        cleanupPresenceObserver()
        cleanupStatusEndedObserver()
        
        print("🧹 통화 관련 옵저버 정리 완료")
    }
    
    private func cleanupStatusEndedObserver() {
        if let handle = statusEndedHandle {
            database.reference().removeObserver(withHandle: handle)
            statusEndedHandle = nil
        }
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
    
    // MARK: - Memory Management
    private func cleanupAllObservers() {
        // 모든 Firebase 옵저버 정리
        if let handle = matchingHandle {
            database.reference().removeObserver(withHandle: handle)
            matchingHandle = nil
        }
        
        if let handle = statusHandle {
            database.reference().removeObserver(withHandle: handle)
            statusHandle = nil
        }
        
        // 통화 관련 옵저버 정리
        cleanupCallObservers()
        
        print("🧹 MatchingManager 모든 옵저버 정리 완료")
    }
}
