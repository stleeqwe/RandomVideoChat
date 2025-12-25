# 5SEC - 랜덤 비디오 채팅 앱 명세서

> 최종 업데이트: 2025년 12월 25일

## 1. 개요

**5SEC**은 iOS 기반의 랜덤 비디오 채팅 앱입니다. 사용자는 성별 선호도를 설정하고 랜덤한 상대와 실시간 영상 통화를 할 수 있습니다.

### 1.1 기술 스택

| 구분 | 기술 |
|------|------|
| 플랫폼 | iOS 15.0+ |
| 언어 | Swift 5 |
| UI 프레임워크 | SwiftUI |
| 아키텍처 | MVVM + Manager 패턴 |
| 인증 | Firebase Authentication |
| 데이터베이스 | Firebase Firestore + Realtime Database |
| 서버리스 | Firebase Cloud Functions |
| 영상통화 | Agora RTC SDK |
| 결제 | StoreKit 2 |

### 1.2 Bundle ID
```
com.pukaworks.5sec
```

---

## 2. 앱 구조

### 2.1 화면 흐름

```
앱 시작
    │
    ▼
┌─────────────┐
│ SplashView  │  ← 1.5초 로고 애니메이션
└─────────────┘
    │
    ▼ (신규 사용자)
┌─────────────┐
│ SignUpView  │  ← 생년 선택 (만 18세 이상)
└─────────────┘
    │
    ▼
┌───────────────────┐
│ TermsAgreementView│  ← 약관 동의 (필수)
└───────────────────┘
    │
    ▼
┌─────────────┐
│  MainView   │  ← 메인 화면 (매칭 시작점)
└─────────────┘
    │ (스와이프 or 버튼)
    ▼
┌──────────────┐
│ MatchingView │  ← 매칭 대기 애니메이션
└──────────────┘
    │ (매칭 성공)
    ▼
┌───────────────┐
│ VideoCallView │  ← 영상 통화
└───────────────┘
```

### 2.2 핵심 Manager 클래스

| Manager | 역할 |
|---------|------|
| `UserManager` | 사용자 데이터 관리, 하트 시스템, 위임 허브 |
| `AuthManager` | Firebase 인증 (익명, Apple) |
| `MatchingManager` | 매칭 큐 관리, 통화 상태 동기화 |
| `AgoraManager` | Agora RTC 엔진, 영상/음성 제어 |
| `ProfileManager` | 프로필 업데이트 (성별, 약관 동의) |
| `BlockManager` | 차단 유저 관리, 최근 매칭 기록 |
| `ContentModerationManager` | 신고/정지 시스템 |
| `DailyRewardManager` | 일일 출석 보상 |
| `NetworkManager` | 네트워크 품질 모니터링 |
| `StoreKitManager` | 인앱 결제 |
| `HeartObserverManager` | 실시간 하트 수신 감지 |
| `CallTimerManager` | 통화 타이머 관리 |
| `KeychainManager` | 민감 데이터 보안 저장 |

---

## 3. 인증 시스템

### 3.1 지원 인증 방식

| 방식 | 상태 | 설명 |
|------|------|------|
| 익명 인증 | ✅ 활성 | 기본 인증 방식 |
| Apple 로그인 | ✅ 활성 | 계정 삭제 시 재인증용 |
| Google 로그인 | ❌ 미구현 | 코드 존재하나 미완성 |

### 3.2 회원가입 플로우

1. **생년 선택** - 만 18세 이상만 가입 가능
2. **익명 인증** - Firebase Anonymous Auth로 UID 발급
3. **사용자 문서 생성** - Firestore에 기본 데이터 저장
4. **약관 동의** - 서비스 이용약관 + 개인정보 처리방침 + 연령 확인
5. **메인 화면** - 매칭 가능 상태

### 3.3 세션 관리

- **자동 로그인**: `hasLaunchedBefore` 플래그로 재방문 사용자 자동 인증
- **계정 삭제**: Apple 재인증 후 Firestore/RTDB 데이터 삭제 → Auth 계정 삭제

---

## 4. 사용자 데이터 모델

### 4.1 User 구조체

```swift
struct User {
    let uid: String              // Firebase UID
    let email: String?           // 이메일 (선택)
    let displayName: String?     // 표시 이름 (선택)
    var heartCount: Int          // 보유 하트 수 (기본: 3)
    var blockedUsers: [String]   // 차단한 사용자 ID 목록
    var gender: Gender?          // 본인 성별 (male/female)
    var preferredGender: Gender? // 선호 성별 (male/female/nil=any)
    var birthDate: Date?         // 생년월일
    var ageVerified: Bool        // 성인 인증 여부
    var authProvider: String     // 인증 방식 (anonymous/apple)
    var termsAgreedAt: Date?     // 이용약관 동의 일시
    var privacyAgreedAt: Date?   // 개인정보처리방침 동의 일시
    let createdAt: Date          // 계정 생성일

    // 비활성화된 필드 (선호도 시스템)
    var totalCallCount: Int      // 총 통화 횟수
    var uniqueHeartGivers: [String] // 하트 발신자 목록
    var preferenceRate: Double   // 선호도 점수 (항상 50.0)
}
```

### 4.2 Gender Enum

```swift
enum Gender: String, Codable {
    case male = "male"
    case female = "female"
}
```

---

## 5. 데이터베이스 구조

### 5.1 Firestore 컬렉션

#### `users/{userId}`
```json
{
  "uid": "string",
  "email": "string",
  "displayName": "string",
  "heartCount": 3,
  "blockedUsers": ["userId1", "userId2"],
  "gender": "male|female",
  "preferredGender": "male|female|",
  "birthDate": "Timestamp",
  "ageVerified": true,
  "authProvider": "anonymous|apple",
  "termsAgreedAt": "Timestamp",
  "privacyAgreedAt": "Timestamp",
  "createdAt": "Timestamp",
  "lastRewardDate": "Timestamp",
  "totalMatches": 0,
  "totalCallCount": 0,
  "uniqueHeartGivers": [],
  "preferenceRate": 50.0
}
```

#### `reports/{reportId}`
```json
{
  "reportedUserId": "string",
  "reporterUserId": "string",
  "reason": "spam|inappropriate|harassment|other",
  "timestamp": "Timestamp",
  "status": "pending"
}
```

#### `suspensions/{suspensionId}`
```json
{
  "userId": "string",
  "startDate": "Timestamp",
  "endDate": "Timestamp",
  "reason": "string",
  "isActive": true,
  "appliedBy": "system"
}
```

### 5.2 Realtime Database 구조

#### `matching_queue/{userId}`
```json
{
  "userId": "string",
  "status": "waiting|matched",
  "gender": "male|female",
  "preferredGender": "male|female|any",
  "bucket": "waiting_male|waiting_female|waiting_any",
  "preferenceRate": 50,
  "timestamp": 1703500000000,
  "clientVersion": "1.0",
  "matchId": "string (매칭 후)",
  "channelName": "string (매칭 후)",
  "matchedWith": "userId (매칭 후)"
}
```

#### `matches/{matchId}`
```json
{
  "user1": "userId",
  "user2": "userId",
  "channelName": "ch_1703500000_1234",
  "status": "active|ended",
  "createdAt": 1703500000000,
  "timeRemaining": 300,
  "cameraStatus": {
    "userId1": true,
    "userId2": false
  },
  "endedBy": {
    "userId1": true
  },
  "endedAt": 1703500300000
}
```

#### `notifications/{userId}/newHeart/{notificationId}`
```json
{
  "timestamp": 1703500000000,
  "from": "senderUserId"
}
```

#### `presence/{userId}`
```json
{
  "online": true,
  "lastSeen": 1703500000000
}
```

---

## 6. 매칭 시스템

### 6.1 매칭 알고리즘 (Cloud Function)

**현재 방식: 성별 필터 + FIFO (선입선출)**

```
1. 트리거: 유저가 matching_queue에 waiting 상태로 등록
2. 버킷 검색: 유저의 선호 성별에 맞는 버킷 조회
   - 예: 남자가 여자 선호 → waiting_female, waiting_any 버킷 검색
3. 필터링:
   - 자기 자신 제외
   - status !== 'waiting' 제외
   - 5분 이상 오래된 항목 제외
   - 양방향 성별 호환성 체크
   - 차단 유저 제외
4. 정렬: timestamp 오름차순 (먼저 온 사람 우선)
5. 매칭 실행: 분산 락 획득 → 양쪽 status='matched' 업데이트
```

### 6.2 클라이언트 매칭 플로우

```
[MainView] 스와이프/버튼 클릭
    ↓
[MatchingManager] registerInQueue()
    ↓ Firebase RTDB에 등록
[MatchingManager] observeMatchResult()
    ↓ status 변경 감지
[Cloud Function] 매칭 처리
    ↓ matchId, channelName 할당
[MatchingManager] 매칭 결과 수신
    ↓ Keychain에 저장
[MatchingView] "MATCHED!" 애니메이션
    ↓ 0.8초 후
[VideoCallView] 영상 통화 시작
```

### 6.3 매칭 취소

- 사용자: 아래로 스와이프
- 시스템: 2분 타임아웃
- 처리: `MatchingManager.cancelMatching()` → 큐에서 제거

---

## 7. 영상 통화 시스템

### 7.1 Agora 설정

| 설정 | 값 |
|------|-----|
| App ID | Info.plist에서 로드 |
| 채널 프로필 | Communication |
| 클라이언트 역할 | Broadcaster |
| 토큰 사용 | 설정에 따라 (현재 비활성) |

### 7.2 통화 생명주기

```
[VideoCallView 진입]
    ↓
setupCall()
    ├── CameraManager.stopSession() (충돌 방지)
    ├── Keychain에서 channelName 로드
    └── AgoraManager.startCall(channel)
           ├── 로컬 UID 생성/로드
           ├── 토큰 획득 (활성화 시)
           └── joinChannel()
    ↓
[상대방 입장 감지]
rtcEngine(_:didJoinedOfUid:)
    ├── 리모트 비디오 캔버스 설정
    ├── 카메라 상태 동기화 시작
    └── 타이머 시작
    ↓
[통화 진행]
    ├── 미디어 컨트롤 (음소거, 카메라, 스피커)
    ├── 하트 주고받기
    ├── 네트워크 품질 모니터링
    └── 타이머 카운트다운
    ↓
[통화 종료]
endCall() 또는 타이머 만료
    ├── MatchingManager.signalCallEnd()
    ├── AgoraManager.endCall()
    └── MainView로 복귀
```

### 7.3 미디어 컨트롤

| 기능 | 메서드 | 설명 |
|------|--------|------|
| 음소거 | `toggleMute()` | 로컬 오디오 on/off |
| 카메라 | `toggleCamera()` | 로컬 비디오 on/off |
| 스피커 | `toggleSpeaker()` | 이어피스/스피커 전환 |
| 카메라 전환 | `switchCamera()` | 전면/후면 카메라 전환 |

### 7.4 카메라 상태 동기화

```
[로컬] toggleCamera()
    ↓
[MatchingManager] signalCameraStatus(isOn)
    ↓ matches/{matchId}/cameraStatus/{userId} 업데이트
[상대방 앱] observeOpponentCameraStatus()
    ↓
[AgoraManager] applyRemoteCameraMuted(!isOn)
    ↓
[VideoCallView] 카메라 OFF 오버레이 표시/숨김
```

### 7.5 통화 타이머

- **초기 시간**: 5초 (테스트용, 상용에서는 더 길게 설정)
- **시간 연장**: 하트 1개 소비 → 60초 추가
- **백그라운드 처리**: 60초 이상 백그라운드 → 자동 종료
- **동기화**: Firebase RTDB `matches/{matchId}/timeRemaining`

### 7.6 네트워크 품질 대응

| 품질 레벨 | 대응 |
|----------|------|
| Excellent | 720p, 30fps, 1500kbps |
| Good | 480p, 24fps, 800kbps |
| Fair | 360p, 20fps, 500kbps |
| Poor | 240p, 15fps, 300kbps |
| Bad | 오디오 전용 모드 |

---

## 8. 하트 시스템

### 8.1 하트 획득 방법

| 방법 | 획득량 | 조건 |
|------|--------|------|
| 신규 가입 | 3개 | 최초 1회 |
| 일일 출석 | 1개 | 1일 1회 (가입 당일 제외) |
| 하트 수신 | 1개 | 상대방이 하트 전송 시 |
| 인앱 구매 | 구매량 | StoreKit 결제 |

### 8.2 하트 소비

| 용도 | 소비량 |
|------|--------|
| 통화 시간 연장 | 1개 (60초 추가) |

### 8.3 하트 전송 플로우

```
[VideoCallView] 하트 버튼 클릭
    ↓
[HeartObserverManager] deductHeart()
    ├── 로컬 heartCount -= 1
    └── Firestore heartCount 업데이트
    ↓
sendHeartToOpponent(opponentId)
    ↓ notifications/{opponentId}/newHeart에 기록
[상대방 앱] observeNewHeartNotification()
    ├── 하트 애니메이션 표시
    ├── heartCount += 1
    └── 알림 삭제
```

### 8.4 일일 출석 보상

```swift
// DailyRewardManager
func checkAndGrantDailyReward() {
    조건:
    1. 가입 당일이 아님 (createdAt != today)
    2. 오늘 보상 미수령 (lastRewardDate != today)

    처리:
    - Firestore 트랜잭션으로 원자적 업데이트
    - heartCount += 1
    - lastRewardDate = today
    - 알림 표시: "일일 출석 보상으로 하트 1개를 받았습니다!"
}
```

---

## 9. 콘텐츠 관리

### 9.1 신고 시스템

**신고 사유:**
- `spam` - 스팸/광고
- `inappropriate` - 부적절한 콘텐츠
- `harassment` - 욕설/괴롭힘
- `other` - 기타

**처리 플로우:**
```
[VideoCallView] 신고 버튼 → 사유 선택
    ↓
[ContentModerationManager] reportUser()
    ├── Firestore reports/ 컬렉션에 기록
    └── checkAndApplyAutoSanction()
           ↓ 7일 내 3회 신고 시
        createSuspension() → 7일 정지
```

### 9.2 차단 시스템

```swift
// BlockManager
func blockUser(_ userId: String) {
    - Firestore blockedUsers 배열에 추가
    - 매칭 시 해당 유저 제외
    - 양방향 차단 확인 (isBlockedPair)
}
```

### 9.3 계정 정지

**자동 정지 조건:**
- 7일 내 3회 이상 신고
- 정지 기간: 7일

**정지 확인:**
```swift
// UserManager.checkContentSafety()
- 로그인 시 suspensions/ 컬렉션 확인
- 정지 상태면 앱 이용 차단
- 메시지: "[정지 사유]\n해제 예정: [날짜]"
```

---

## 10. 설정 및 기타 기능

### 10.1 설정 화면 (SettingsView)

| 항목 | 기능 |
|------|------|
| 하트 구매 | HeartPurchaseView로 이동 |
| 이용약관 | 외부 링크 (5sec-terms.web.app/terms) |
| 개인정보처리방침 | 외부 링크 (5sec-terms.web.app/privacy) |
| 문의하기 | 이메일 (support@5sec-app.com) |
| 로그아웃 | Firebase 로그아웃 |
| 회원탈퇴 | Apple 재인증 후 계정 삭제 |

### 10.2 카메라 미리보기

- MainView에서 로컬 카메라 미리보기 on/off 가능
- `@AppStorage("isMainPreviewOn")` 으로 상태 저장

### 10.3 성별 선택

| 항목 | 설명 |
|------|------|
| 내 성별 | 필수 선택 (male/female) |
| 선호 성별 | 선택 사항 (male/female/미선택=any) |

---

## 11. Cloud Functions

### 11.1 배포된 함수

| 함수명 | 트리거 | 역할 |
|--------|--------|------|
| `onQueueWrite` | RTDB /matching_queue/{userId} 변경 | 매칭 처리 |
| `cleanupStaleEntries` | 5분마다 (Pub/Sub) | 오래된 큐 항목 정리 |
| `manualCleanup` | HTTP 요청 | 수동 정리 (관리자용) |

### 11.2 리전
```
asia-northeast3 (서울)
```

---

## 12. 보안

### 12.1 Keychain 저장 항목

| 키 | 용도 |
|----|------|
| `currentChannelName` | 현재 Agora 채널명 |
| `currentMatchId` | 현재 매칭 ID |
| `localAgoraUid` | 로컬 Agora UID (고정) |

### 12.2 민감 정보 처리

- 비밀번호: 저장 안함 (Firebase Auth 위임)
- 토큰: Keychain에 저장
- 사용자 데이터: Firestore Security Rules로 보호

---

## 13. 비활성화된 기능

| 기능 | 상태 | 설명 |
|------|------|------|
| 선호도 기반 매칭 | 비활성 | preferenceRate 항상 50.0 반환 |
| 통화 횟수 추적 | 비활성 | incrementCallCount() 무동작 |
| 하트 발신자 기록 | 비활성 | recordHeartReceived() 무동작 |
| Google 로그인 | 미구현 | 코드만 존재 |
| 푸시 알림 | 미구현 | 로컬 알림만 사용 |

---

## 14. 외부 서비스 연동

| 서비스 | 용도 | 설정 위치 |
|--------|------|----------|
| Firebase Auth | 인증 | GoogleService-Info.plist |
| Firebase Firestore | 사용자 데이터 | GoogleService-Info.plist |
| Firebase RTDB | 실시간 매칭/통화 | GoogleService-Info.plist |
| Firebase Functions | 서버 로직 | cloud_functions/ |
| Agora RTC | 영상 통화 | Info.plist (AGORA_APP_ID) |
| StoreKit 2 | 인앱 결제 | App Store Connect |

---

## 15. 프로젝트 구조

```
RandomVideoChat/
├── RandomVideoChatApp.swift      # 앱 진입점
├── ContentView.swift             # 루트 네비게이션
├── User.swift                    # 사용자 모델
│
├── Managers/
│   ├── AuthManager.swift         # 인증 관리
│   ├── ProfileManager.swift      # 프로필 관리
│   ├── BlockManager.swift        # 차단 관리
│   ├── HeartObserverManager.swift # 하트 실시간 감지
│   └── CallTimerManager.swift    # 통화 타이머
│
├── [루트 레벨 Managers]
│   ├── UserManager.swift         # 사용자/하트 관리
│   ├── MatchingManager.swift     # 매칭 시스템
│   ├── AgoraManager.swift        # Agora RTC
│   ├── NetworkManager.swift      # 네트워크 품질
│   ├── DailyRewardManager.swift  # 일일 보상
│   ├── ContentModerationManager.swift # 콘텐츠 관리
│   ├── StoreKitManager.swift     # 인앱 결제
│   ├── CameraManager.swift       # 카메라 세션
│   └── KeychainManager.swift     # 보안 저장소
│
├── Views/
│   ├── SplashView.swift          # 스플래시
│   ├── SignUpView.swift          # 회원가입
│   ├── TermsAgreementView.swift  # 약관 동의
│   ├── MainView.swift            # 메인
│   ├── MatchingView.swift        # 매칭 대기
│   ├── VideoCallView.swift       # 영상 통화
│   ├── SettingsView.swift        # 설정
│   ├── HeartPurchaseView.swift   # 하트 구매
│   └── Components/               # UI 컴포넌트
│
├── ViewModels/
│   ├── SignUpViewModel.swift
│   ├── MainViewModel.swift
│   └── VideoCallViewModel.swift
│
├── Errors/
│   └── AppError.swift            # 에러 정의
│
└── cloud_functions/matching/     # Cloud Functions
    ├── index.js                  # 매칭 로직
    ├── package.json
    └── test-matching*.js         # 테스트 스크립트
```

---

## 16. 버전 정보

| 항목 | 버전/값 |
|------|---------|
| iOS 최소 버전 | 15.0 |
| Swift 버전 | 5 |
| Agora SDK | 최신 |
| Firebase SDK | 최신 |
| Node.js (Functions) | 20 |

---

*이 문서는 2025년 12월 25일 기준 코드 분석을 바탕으로 작성되었습니다.*
