rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 문서 규칙
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // 연령 확인 필드 보호
      allow update: if request.auth != null 
        && request.auth.uid == userId
        && (!('ageVerified' in request.resource.data) || request.resource.data.ageVerified == resource.data.ageVerified)
        && (!('birthDate' in request.resource.data) || request.resource.data.birthDate == resource.data.birthDate);
    }
    
    // 매칭 큐 규칙 (연령 확인된 사용자만 접근)
    match /matchingQueue/{document} {
      allow read, write: if request.auth != null 
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.ageVerified == true;
    }
    
    // 매칭 세션 규칙
    match /matchingSessions/{sessionId} {
      allow read, write: if request.auth != null 
        && (request.auth.uid in resource.data.participants || request.auth.uid in request.resource.data.participants)
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.ageVerified == true;
    }
    
    // 알림 규칙
    match /notifications/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}