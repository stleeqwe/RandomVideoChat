# Firebase 설정 가이드 - Apple Sign In 및 연령 확인

## 🔥 Firebase Console 설정

### 1. Authentication 설정
1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택: `random-video-chat-98e0a`
3. **Authentication > Sign-in method**로 이동

#### Apple 제공업체 활성화:
```
- "Apple" 클릭
- "사용 설정" 토글 ON
- 서비스 ID: com.pukaworks.5sec
- Apple Developer Team ID: [개발자 계정에서 확인]
- 키 ID: [Apple Developer Console에서 생성한 키 ID]
- 비공개 키: [.p8 파일 업로드]
```

### 2. Firestore 보안 규칙 업데이트
Firebase Console > Firestore Database > 규칙:
```javascript
// firestore-security-rules.js 파일 내용을 복사하여 적용
```

### 3. Firestore 인덱스 추가
Firebase Console > Firestore Database > 색인:
```json
// firestore-indexes.json 파일 내용을 참고하여 인덱스 생성
```

## 🍎 Apple Developer Console 설정

### 1. Sign In with Apple 키 생성
1. [Apple Developer Console](https://developer.apple.com/account) 접속
2. **Certificates, Identifiers & Profiles > Keys**
3. "+" 버튼 클릭하여 새 키 생성
4. **Sign In with Apple** 체크박스 선택
5. 키 이름 입력 (예: "5SEC Sign In with Apple")
6. 키 다운로드 (.p8 파일 저장)
7. **키 ID 기록** (Firebase에서 필요)

### 2. App ID 설정
1. **Identifiers > App IDs**
2. `com.pukaworks.5sec` 선택
3. **Sign In with Apple** 기능 활성화
4. 변경사항 저장

### 3. Team ID 확인
1. Apple Developer Console 메인 페이지
2. 우측 상단 계정 정보에서 **Team ID** 확인
3. Firebase Authentication 설정에 입력

## 📱 앱 설정 확인사항

### Bundle Identifier 일치성 확인:
- **Xcode 프로젝트**: `com.pukaworks.5sec`
- **Firebase 프로젝트**: `com.pukaworks.5sec`
- **Apple Developer**: `com.pukaworks.5sec`
- **GoogleService-Info.plist**: `com.pukaworks.5sec`

### 권한 설정:
```xml
<!-- Info.plist에 추가 -->
<key>NSCameraUsageDescription</key>
<string>비디오 채팅을 위해 카메라 권한이 필요합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>음성 통화를 위해 마이크 권한이 필요합니다.</string>
```

## 🔒 보안 강화사항

### 연령 확인 관련:
- 생년월일은 암호화되어 Firestore에 저장
- 18세 미만 사용자는 자동 차단
- 연령 확인 상태는 변경 불가능하게 보안 규칙 설정

### Apple Sign In 보안:
- Firebase Auth 토큰 기반 인증
- Apple에서 제공하는 사용자 ID 사용
- 개인정보는 Apple에서 관리

## ✅ 테스트 체크리스트

### Apple Sign In 테스트:
- [ ] Apple ID로 로그인 성공
- [ ] 연령 확인 화면 표시
- [ ] 18세 이상 확인 후 매칭 가능
- [ ] 18세 미만 시 접근 차단
- [ ] 사용자 정보 Firestore 저장 확인

### Firebase 연동 테스트:
- [ ] Authentication에 Apple 사용자 표시
- [ ] Firestore에 사용자 문서 생성
- [ ] 연령 확인 필드 저장 확인
- [ ] 보안 규칙 정상 작동

## 🚀 배포 전 최종 확인

### Apple App Store Connect:
1. 앱 정보에서 연령 등급 **17+** 설정
2. App Review 정보에 Apple Sign In 사용 명시
3. 개인정보 처리방침 업데이트

### Firebase 프로덕션 설정:
1. Firestore 보안 규칙 최종 검토
2. Authentication 제한 설정 (필요시)
3. 사용량 모니터링 설정

---
**중요**: 모든 설정을 완료한 후 실제 디바이스에서 테스트를 진행하세요. 시뮬레이터에서는 Apple Sign In이 제한적으로 작동할 수 있습니다.