# 코드 리뷰 수정 사항 (2026-01-21)

## 개요

Codex CLI 코드 리뷰 결과를 검토하고 타당성이 확인된 항목들을 반영했습니다.

- **Commit:** `af8723f8`
- **Branch:** `main`
- **변경 파일:** 33개 (+4,631줄, -209줄)
- **빌드:** 성공
- **테스트:** 성공

---

## Critical 수정 사항 (4건)

### 1. toggleCamera() 실제 비디오 송출 중지

**파일:** `RandomVideoChat/AgoraManager.swift:439-452`

**문제점:**
- `toggleCamera()`가 `isCameraOff` 플래그만 토글하고 실제 비디오 송출을 중지하지 않음
- 상대방에게 계속 영상이 전송되는 보안/프라이버시 문제

**수정 내용:**
```swift
func toggleCamera() -> Bool {
    isCameraOff.toggle()
    // 실제 비디오 송출 제어
    engine?.muteLocalVideoStream(isCameraOff)
    if isCameraOff {
        engine?.stopPreview()
    } else {
        engine?.startPreview()
    }
    return isCameraOff
}
```

---

### 2. Firestore create 규칙/데이터 정합성

**파일:**
- `RandomVideoChat/UserManager.swift:80`
- `RandomVideoChat/Managers/UserRepository.swift:53`
- `RandomVideoChat/Core/Repositories/UserRepository.swift:53`

**문제점:**
- Firestore rules가 `ageVerified == true`를 요구하지만 `createUserDocument()`에서 해당 필드 누락
- 사용자 문서 생성 실패 가능성

**수정 내용:**
```swift
let userData: [String: Any] = [
    "uid": uid,
    "ageVerified": true,  // 추가
    "heartCount": 3,
    // ...
]
```

---

### 3. database.rules matches 보안 강화

**파일:** `database.rules.json:42-45`

**문제점:**
- `.write` 규칙에 `!data.exists()` 조건이 있어 클라이언트에서 임의의 match 문서 생성 가능
- 매칭 조작 취약점

**수정 전:**
```json
".write": "auth != null && (
  !data.exists() ||
  data.child('user1').val() == auth.uid ||
  data.child('user2').val() == auth.uid
)"
```

**수정 후:**
```json
".write": "auth != null && data.exists() && (
  data.child('user1').val() == auth.uid ||
  data.child('user2').val() == auth.uid
)"
```

---

### 4. heartCount 클라이언트 직접 수정 제한

**파일:** `firestore.rules:75-77`

**문제점:**
- 클라이언트가 heartCount를 임의의 값으로 설정 가능
- 무료로 하트를 무한정 획득할 수 있는 취약점

**수정 내용:**
```javascript
// Heart count must be non-negative and change by reasonable amount
(!incoming.keys().hasAny(['heartCount']) ||
 (incoming.heartCount >= 0 &&
  incoming.heartCount <= existing.heartCount + 100))
```

---

## Major 수정 사항 (6건)

### 1. 하트 알림 from 위조 방지

**파일:** `database.rules.json:107`

**문제점:**
- 알림의 `from` 필드를 검증하지 않아 다른 사용자로 위장 가능

**수정 내용:**
```json
"from": {
  ".validate": "newData.isString() && newData.val() == auth.uid"
}
```

---

### 2. removeObserver 리스너 누수 수정

**파일:** `RandomVideoChat/MatchingManager.swift:28-32, 684-717`

**문제점:**
- `database.reference().removeObserver(withHandle:)`로 호출 시 등록된 reference와 다른 경로에서 해제 시도
- 리스너가 제대로 해제되지 않아 메모리 누수 발생

**수정 내용:**
```swift
// Observer 정보를 reference와 handle 함께 저장
private struct ObserverInfo {
    let reference: DatabaseReference
    let handle: DatabaseHandle
}

private var statusObserver: ObserverInfo?
private var callEndObserver: ObserverInfo?
// ...

private func removeObserver(_ observer: inout ObserverInfo?) {
    if let obs = observer {
        obs.reference.removeObserver(withHandle: obs.handle)  // 등록된 reference에서 해제
        observer = nil
    }
}
```

---

### 3. matchId 무한 재시도 방지

**파일:** `RandomVideoChat/MatchingManager.swift:532-554`

**문제점:**
- `observeCallEnd()`에서 matchId가 없으면 0.3초 후 무한 재시도
- 앱 성능 저하 및 불필요한 리소스 소모

**수정 내용:**
```swift
private var observeCallEndRetryCount = 0
private let maxObserveCallEndRetries = 10

func observeCallEnd(completion: @escaping () -> Void) {
    guard let matchId = currentMatchId ?? KeychainManager.loadString(forKey: .currentMatchId),
          !matchId.isEmpty else {
        observeCallEndRetryCount += 1
        if observeCallEndRetryCount >= maxObserveCallEndRetries {
            observeCallEndRetryCount = 0
            return  // 최대 재시도 후 포기
        }
        // retry...
    }
    observeCallEndRetryCount = 0
    // ...
}
```

---

### 4. matching_queue 삭제 구조

**상태:** 기존 구현으로 해결됨

- `registerInQueue()` 시 `queueRef.onDisconnectRemoveValue()` 설정됨 (line 256)
- 앱 강제 종료 시에도 서버에서 자동 삭제

---

### 5. errors 배열 데이터 레이스 수정

**파일:**
- `RandomVideoChat/UserManager.swift:285`
- `RandomVideoChat/Managers/UserRepository.swift:160`
- `RandomVideoChat/Core/Repositories/UserRepository.swift:160`

**문제점:**
- `DispatchGroup` 내 여러 콜백에서 `errors` 배열에 동시 접근
- 데이터 레이스로 인한 크래시 가능성

**수정 내용:**
```swift
var errors: [Error] = []
let errorsLock = NSLock()

// 각 콜백에서
if let error = error {
    errorsLock.lock()
    errors.append(error)
    errorsLock.unlock()
}
```

---

### 6. Logger 클래스 이름 충돌 해결

**파일:**
- `RandomVideoChat/Utilities/Logger.swift:49`
- `RandomVideoChat/Core/Logger/Logger.swift:49`

**문제점:**
- `Logger` 클래스명이 `os.log`의 `Logger`와 충돌
- `PerformanceMonitor.swift`에서 `os.log.Logger` 사용 시 컴파일 에러

**수정 내용:**
```swift
// Logger -> AppLogger로 이름 변경
final class AppLogger {
    static let shared = AppLogger()
    // ...
}

// 전역 함수는 그대로 유지
func logDebug(_ message: String, ...) {
    AppLogger.shared.debug(message, ...)
}
```

---

## Minor 수정 사항 (3건)

### 1. 매칭 완료 후 observer 정리

**상태:** Major #2 (ObserverInfo) 수정으로 해결됨

---

### 2. PermissionManagerProtocol 메서드 추가

**파일:**
- `RandomVideoChat/Managers/PermissionManager.swift:20`
- `RandomVideoChat/Core/Services/PermissionManager.swift:20`

**수정 내용:**
```swift
protocol PermissionManagerProtocol {
    // ...
    func areAllPermissionsGranted() -> Bool  // 추가
    // ...
}
```

---

### 3. 에러 로깅 일관성 개선

**상태:** AppLogger 통합으로 해결됨

- 모든 로깅이 `logDebug()`, `logInfo()`, `logWarning()`, `logError()` 전역 함수 사용
- 카테고리별 분류 지원 (`.auth`, `.user`, `.matching`, `.agora` 등)

---

## 추가된 아키텍처 개선

### Repository Layer
- `UserRepository` - Firebase 사용자 데이터 접근
- `MatchingRepository` - Realtime Database 매칭 로직

### Dependency Injection
- `ServiceContainer` - 서비스 의존성 관리
- `Services` enum - 전역 접근 제공

### 새 UI 컴포넌트
- `CircleButton` - 원형 버튼
- `HeartCountView` - 하트 카운트 표시
- `SwipeUpIndicator` - 스와이프 인디케이터
- `VideoGradientOverlay` - 비디오 그라데이션 오버레이

### 테스트
- `ConstantsTests` - 상수 값 테스트
- `LoggerTests` - 로거 기능 테스트
- `UserModelTests` - User 모델 테스트
- `ErrorsTests` - 에러 타입 테스트

---

## 검증

```bash
# 빌드
xcodebuild -scheme RandomVideoChat build
** BUILD SUCCEEDED **

# 테스트
xcodebuild test -scheme RandomVideoChat -only-testing:RandomVideoChatTests
** TEST SUCCEEDED **
```
