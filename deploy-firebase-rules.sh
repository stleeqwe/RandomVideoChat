#!/bin/bash

echo "🔥 Firebase 보안 규칙 및 인덱스 배포 시작..."

# Firebase 로그인 확인
firebase login --no-localhost

# 프로젝트 설정 (실제 프로젝트 ID로 변경 필요)
# firebase use your-project-id

# Firestore 규칙 배포
echo "📝 Firestore 보안 규칙 배포 중..."
firebase deploy --only firestore:rules

# Firestore 인덱스 배포
echo "📊 Firestore 인덱스 배포 중..."
firebase deploy --only firestore:indexes

# Realtime Database 규칙 배포
echo "🔐 Realtime Database 보안 규칙 배포 중..."
firebase deploy --only database

echo "✅ Firebase 보안 규칙 및 인덱스 배포 완료!"

# 배포 결과 확인
echo "🔍 배포 상태 확인:"
firebase firestore:databases:list
echo ""
echo "📋 다음 단계:"
echo "1. Firebase Console에서 규칙이 올바르게 적용되었는지 확인"
echo "2. 신고 기능 테스트"
echo "3. 매칭 시스템 동작 확인"